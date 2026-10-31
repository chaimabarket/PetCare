// Règles métier du module Profils des animaux : propriétaire, animal archivé (RG-06), galerie de 5 photos
// dont la première est la couverture, une pesée par jour. Ni Express ni Firestore ici.

const { ApiError } = require('../firestore');
const E = require('./enums');
const {
  petFields, petPatch, photoBytes, gallery: parseGallery, weightEntry, weightCorrection, MAX_PHOTOS,
} = require('./validation');

const newestFirst = (a, b) => new Date(b.createdAt || 0) - new Date(a.createdAt || 0);

/** Positions à réécrire pour que chaque photo de [ordered] ait son rang (la première est la couverture). */
const reorderPlan = (ordered) =>
  ordered.flatMap((photo, sortOrder) => (photo.sortOrder === sortOrder ? [] : [{ id: photo.id, sortOrder }]));

function createPetsService(repository) {
  async function petOrFail(token, uid, petId) {
    const pet = await repository.getPet(token, petId);
    if (!pet) throw new ApiError(404, 'Animal introuvable.');
    if (pet.ownerId !== uid) throw new ApiError(403, "Cet animal n'est pas le vôtre.");
    return pet;
  }

  /** Un animal archivé reste consultable, mais il faut le restaurer avant de le modifier. */
  async function activePetOrFail(token, uid, petId) {
    const pet = await petOrFail(token, uid, petId);
    if (pet.status === E.PET_STATUS.archived) throw new ApiError(409, "Restaurez d'abord cet animal pour le modifier.");
    return pet;
  }

  return {
    // ----------------------------------------------------------- Fiches

    /** Mes animaux, les plus récents d'abord ; `status` filtre sur actif ou archivé. */
    async listPets(token, uid, status) {
      if (status !== undefined && !Object.values(E.PET_STATUS).includes(status)) throw new ApiError(400, 'Le statut est invalide.');
      return (await repository.listPetsByOwner(token, uid)).filter((p) => !status || p.status === status).sort(newestFirst);
    },

    async createPet(token, uid, body) {
      const fields = petFields(body);
      const photos = parseGallery(body.photos ?? []);
      if (photos.some((p) => p.id)) throw new ApiError(400, 'Une photo est invalide.');

      const petId = await repository.createPet(token, {
        fields: {
          ...fields,
          ownerId: uid,
          status: E.PET_STATUS.active,
          archivedReason: null,
          favorite: false,
          contacts: [],
        },
        photos: photos.map((p) => p.bytes),
        weight: body.weight ? weightEntry(body.weight) : null,
      });
      return repository.getPet(token, petId);
    },

    getPet: petOrFail,

    /** Modifie la fiche et, si `photos` est envoyé, remplace la galerie par cette liste. */
    async updatePet(token, uid, petId, body) {
      const pet = await activePetOrFail(token, uid, petId);
      const fields = petFields(body);

      let galleryPlan;
      if (body.photos !== undefined) {
        const wanted = parseGallery(body.photos);
        const current = await repository.listGallery(token, pet.id);
        const currentById = new Map(current.map((p) => [p.id, p]));
        const keptIds = new Set(wanted.filter((p) => p.id).map((p) => p.id));
        if ([...keptIds].some((id) => !currentById.has(id))) throw new ApiError(400, 'Une photo est invalide.');

        galleryPlan = {
          remove: current.filter((p) => !keptIds.has(p.id)).map((p) => p.id),
          add: wanted.flatMap((photo, i) => (photo.bytes ? [{ bytes: photo.bytes, sortOrder: i }] : [])),
          reorder: wanted.flatMap((photo, i) =>
            (!photo.bytes && currentById.get(photo.id).sortOrder !== i ? [{ id: photo.id, sortOrder: i }] : [])),
        };
      }

      await repository.updatePet(token, pet.id, {
        fields,
        gallery: galleryPlan,
        weight: body.weight ? weightEntry(body.weight) : null,
      });
      return repository.getPet(token, pet.id);
    },

    /** Modifie seulement `notes`, `favorite` ou `contacts`. */
    async patchPet(token, uid, petId, body) {
      const pet = await activePetOrFail(token, uid, petId);
      await repository.patchPet(token, pet.id, petPatch(body));
      return repository.getPet(token, pet.id);
    },

    /** Archive l'animal : jamais supprimé, son historique est conservé. */
    async archivePet(token, uid, petId) {
      const pet = await petOrFail(token, uid, petId);
      await repository.patchPet(token, pet.id, { status: E.PET_STATUS.archived, archivedReason: 'USER' });
    },

    async restorePet(token, uid, petId) {
      const pet = await petOrFail(token, uid, petId);
      await repository.patchPet(token, pet.id, { status: E.PET_STATUS.active, archivedReason: null });
    },

    // ----------------------------------------------------------- Photos

    async listPhotos(token, petId) {
      return (await repository.listGallery(token, petId)).map(({ id, data, sortOrder }) => ({ id, data, sortOrder }));
    },

    async getCover(token, petId) {
      const cover = await repository.getCover(token, petId);
      return cover ? { id: cover.id, data: cover.data, sortOrder: cover.sortOrder } : null;
    },

    /** Ajoute une photo en fin de galerie : la position est calculée ici, pas par le client. */
    async addPhoto(token, uid, petId, body) {
      const pet = await activePetOrFail(token, uid, petId);
      const bytes = photoBytes(body.data);
      const current = await repository.listGallery(token, pet.id);
      if (current.length >= MAX_PHOTOS) throw new ApiError(409, `Une fiche accepte ${MAX_PHOTOS} photos au maximum.`);
      await repository.addPhoto(token, pet.id, bytes, current.length);
      return { sortOrder: current.length };
    },

    /** Supprime une photo et recompacte l'ordre pour garder la couverture en position 0. */
    async removePhoto(token, uid, petId, photoId) {
      const pet = await activePetOrFail(token, uid, petId);
      const current = await repository.listGallery(token, pet.id);
      if (!current.some((p) => p.id === photoId)) throw new ApiError(404, 'Photo introuvable.');
      await repository.removePhoto(token, pet.id, photoId, reorderPlan(current.filter((p) => p.id !== photoId)));
    },

    /** Place la photo en position 0 (photo principale). */
    async setCover(token, uid, petId, photoId) {
      const pet = await activePetOrFail(token, uid, petId);
      const current = await repository.listGallery(token, pet.id);
      const chosen = current.find((p) => p.id === photoId);
      if (!chosen) throw new ApiError(404, 'Photo introuvable.');
      await repository.reorderPhotos(token, pet.id, reorderPlan([chosen, ...current.filter((p) => p !== chosen)]));
    },

    // ----------------------------------------------------------- Pesées

    /** Pesées, la plus récente d'abord (`limit` pour les dernières). */
    listWeights(token, petId, limitParam) {
      const limit = limitParam ? Math.min(Math.max(parseInt(limitParam, 10) || 1, 1), 1000) : undefined;
      return repository.listWeights(token, petId, limit);
    },

    /** Enregistre une pesée : une seule par jour. */
    async addWeight(token, uid, petId, body) {
      const pet = await activePetOrFail(token, uid, petId);
      const entry = weightEntry(body);
      try {
        await repository.addWeight(token, pet.id, entry);
      } catch (error) {
        if (error.status === 409) throw new ApiError(409, 'Une pesée existe déjà à cette date.');
        throw error;
      }
      return repository.getWeight(token, pet.id, entry.id);
    },

    /** Corrige le poids ou la note d'une pesée existante. */
    async updateWeight(token, uid, petId, weightId, body) {
      const pet = await activePetOrFail(token, uid, petId);
      const data = weightCorrection(body);
      if (!await repository.getWeight(token, pet.id, weightId)) throw new ApiError(404, 'Pesée introuvable.');
      await repository.updateWeight(token, pet.id, weightId, data);
      return repository.getWeight(token, pet.id, weightId);
    },

    async deleteWeight(token, uid, petId, weightId) {
      const pet = await activePetOrFail(token, uid, petId);
      await repository.deleteWeight(token, pet.id, weightId);
    },
  };
}

module.exports = { createPetsService };
