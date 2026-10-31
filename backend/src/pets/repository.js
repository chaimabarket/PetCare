// Couche données du module Profils des animaux : `pets/{id}` et ses sous-collections `photos` et `weights`.
// Aucune règle métier ici : le service décide (propriétaire, animal archivé, ordre des photos), le dépôt écrit.

const { getDocument, writeDocument, writeOp, deleteOp, commit, queryCollection, newId } = require('../firestore');

const petPath = (id) => `pets/${id}`;
const photoPath = (petId, id) => `pets/${petId}/photos/${id}`;
const weightPath = (petId, id) => `pets/${petId}/weights/${id}`;

function createPetsRepository(firestore = { getDocument, writeDocument, writeOp, deleteOp, commit, queryCollection, newId }) {
  const { getDocument: get, writeDocument: write, writeOp: op, deleteOp: del, commit: run, queryCollection: query, newId: id } = firestore;

  const newPhotoOp = (petId, bytes, sortOrder) =>
    op(photoPath(petId, id()), { data: bytes, sortOrder }, { serverTimestamps: ['createdAt'], replace: true, mustNotExist: true });

  const reorderOps = (petId, reorder) =>
    reorder.map(({ id: photoId, sortOrder }) => op(photoPath(petId, photoId), { sortOrder }, { mustExist: true }));

  const weightOp = (petId, { id: weightId, data }) =>
    op(weightPath(petId, weightId), data, { serverTimestamps: ['createdAt'], replace: true });

  return {
    // ----------------------------------------------------------- Fiches

    listPetsByOwner: (token, uid) => query(token, null, 'pets', { where: { field: 'ownerId', value: uid } }),

    getPet: (token, petId) => get(token, petPath(petId)),

    /** Crée la fiche, ses photos et sa première pesée en une seule écriture atomique. */
    async createPet(token, { fields, photos, weight }) {
      const petId = id();
      const writes = [
        op(petPath(petId), fields, { serverTimestamps: ['createdAt', 'updatedAt'], mustNotExist: true }),
        ...photos.map((bytes, i) => newPhotoOp(petId, bytes, i)),
      ];
      if (weight) writes.push(weightOp(petId, weight));
      await run(token, writes);
      return petId;
    },

    /**
     * Modifie la fiche. [gallery] (facultatif) : `{ remove: [ids], add: [{bytes, sortOrder}], reorder: [{id, sortOrder}] }`.
     * [weight] : pesée du jour enregistrée avec la fiche.
     */
    updatePet: (token, petId, { fields, gallery, weight }) => {
      const writes = [op(petPath(petId), fields, { serverTimestamps: ['updatedAt'], mustExist: true })];
      if (gallery) {
        gallery.remove.forEach((photoId) => writes.push(del(photoPath(petId, photoId))));
        gallery.add.forEach(({ bytes, sortOrder }) => writes.push(newPhotoOp(petId, bytes, sortOrder)));
        writes.push(...reorderOps(petId, gallery.reorder));
      }
      if (weight) writes.push(weightOp(petId, weight));
      return run(token, writes);
    },

    /** Modifie quelques champs de la fiche (notes, favori, contacts, statut…). */
    patchPet: (token, petId, fields) => write(token, petPath(petId), fields, { serverTimestamps: ['updatedAt'], mustExist: true }),

    // ----------------------------------------------------------- Photos

    /** Galerie dans l'ordre, la photo principale d'abord. */
    async listGallery(token, petId) {
      return (await query(token, petPath(petId), 'photos')).sort((a, b) => a.sortOrder - b.sortOrder);
    },

    async getCover(token, petId) {
      const [cover] = await query(token, petPath(petId), 'photos', { orderBy: 'sortOrder', direction: 'ASCENDING', limit: 1 });
      return cover ?? null;
    },

    addPhoto: (token, petId, bytes, sortOrder) => run(token, [newPhotoOp(petId, bytes, sortOrder)]),

    removePhoto: (token, petId, photoId, reorder) =>
      run(token, [del(photoPath(petId, photoId)), ...reorderOps(petId, reorder)]),

    reorderPhotos: (token, petId, reorder) => run(token, reorderOps(petId, reorder)),

    // ----------------------------------------------------------- Pesées

    listWeights: (token, petId, limit) => query(token, petPath(petId), 'weights', { orderBy: 'measuredOn', limit }),

    getWeight: (token, petId, weightId) => get(token, weightPath(petId, weightId)),

    /** Ajoute la pesée ; lève une erreur 409 si ce jour en a déjà une. */
    addWeight: (token, petId, { id: weightId, data }) =>
      write(token, weightPath(petId, weightId), data, { serverTimestamps: ['createdAt'], replace: true, mustNotExist: true }),

    updateWeight: (token, petId, weightId, data) => write(token, weightPath(petId, weightId), data, { mustExist: true }),

    deleteWeight: (token, petId, weightId) => run(token, [del(weightPath(petId, weightId))]),
  };
}

module.exports = { createPetsRepository };
