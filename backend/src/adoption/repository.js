// Couche données du module Adoption : collections `adoptions` (et ses `photos`),
// `adoptionApplications` et `users/{uid}/adoptionFavorites`. Aucune règle métier ici.

const { getDocument, writeOp, deleteOp, commit, writeDocument, queryCollection, newId } = require('../firestore');
const E = require('./enums');
const { MAX_PHOTOS } = require('./validation');

/** Une candidature a pour identifiant `{annonce}_{candidat}` : une seule par personne et par annonce. */
const applicationId = (listingId, uid) => `${listingId}_${uid}`;

function createAdoptionRepository(firestore = { getDocument, writeOp, deleteOp, commit, writeDocument, queryCollection, newId }) {
  const { getDocument: get, writeOp: op, deleteOp: del, commit: run, writeDocument: write, queryCollection: query, newId: id } = firestore;

  return {
    applicationId,

    // ----------------------------------------------------------- Annonces

    /** Annonces visibles de tous : disponibles et réservées. */
    listPublicListings: (token) =>
      query(token, null, 'adoptions', {
        filters: [{ field: 'status', op: 'IN', value: [E.LISTING_STATUS.available, E.LISTING_STATUS.reserved] }],
      }),

    listListingsByPublisher: (token, uid) =>
      query(token, null, 'adoptions', { where: { field: 'publisherId', value: uid } }),

    getListing: (token, listingId) => get(token, `adoptions/${listingId}`),

    /** Photos en base64, dans l'ordre de l'annonce. */
    async listPhotos(token, listingId) {
      const docs = await query(token, `adoptions/${listingId}`, 'photos');
      return docs.sort((a, b) => Number(a.id) - Number(b.id)).map((d) => d.data);
    },

    /**
     * Écrit une annonce (création ou modification) et, si [photos] est fourni, ses photos (de 0 à 4).
     * Sans [photos], les photos existantes ne sont pas touchées. Renvoie l'identifiant de l'annonce.
     */
    async saveListing(token, { listingId, data, photos, creating }) {
      const listingDoc = { ...data };
      if (photos !== undefined) {
        listingDoc.photoCount = photos.length;
        listingDoc.cover = photos.length === 0 ? null : photos[0];
      }
      if (creating) listingDoc.acceptedApplicationId = null;

      const idToUse = creating ? id() : listingId;
      const writes = [
        op(`adoptions/${idToUse}`, listingDoc, {
          serverTimestamps: creating ? ['updatedAt', 'createdAt'] : ['updatedAt'],
          mustNotExist: creating,
          mustExist: !creating,
        }),
      ];
      if (photos !== undefined) {
        for (let i = 0; i < MAX_PHOTOS; i += 1) {
          if (i < photos.length) writes.push(op(`adoptions/${idToUse}/photos/${i}`, { data: photos[i] }, { replace: true }));
          else if (!creating) writes.push(del(`adoptions/${idToUse}/photos/${i}`));
        }
      }
      await run(token, writes);
      return idToUse;
    },

    /** Archive l'annonce et refuse en même temps les candidatures listées dans [refusals] (`{id, reason}`). */
    archiveListing: (token, listingId, refusals) =>
      run(token, [
        op(`adoptions/${listingId}`, { status: E.LISTING_STATUS.archived }, { serverTimestamps: ['updatedAt'], mustExist: true }),
        ...refusals.map(({ id: applicationDocId, reason }) =>
          op(`adoptionApplications/${applicationDocId}`, { status: E.APPLICATION_STATUS.refused, refusalReason: reason }, {
            serverTimestamps: ['updatedAt'],
            mustExist: true,
          })),
      ]),

    // ----------------------------------------------------------- Favoris

    async listFavoriteIds(token, uid) {
      return (await query(token, `users/${uid}`, 'adoptionFavorites')).map((d) => d.id);
    },

    addFavorite: (token, uid, listingId) =>
      write(token, `users/${uid}/adoptionFavorites/${listingId}`, {}, { serverTimestamps: ['createdAt'] }),

    removeFavorite: (token, uid, listingId) => run(token, [del(`users/${uid}/adoptionFavorites/${listingId}`)]),

    // ----------------------------------------------------------- Candidatures

    getApplication: (token, applicationDocId) => get(token, `adoptionApplications/${applicationDocId}`),

    findApplication: (token, listingId, uid) => get(token, `adoptionApplications/${applicationId(listingId, uid)}`),

    /** Candidatures encore ouvertes (envoyées, en étude ou acceptées) sur une annonce de l'annonceur. */
    async listOpenApplications(token, listing) {
      const apps = await query(token, null, 'adoptionApplications', {
        filters: [
          { field: 'publisherId', value: listing.publisherId },
          { field: 'listingId', value: listing.id },
        ],
      });
      return apps.filter((a) => E.OPEN_APPLICATION_STATUSES.includes(a.status));
    },

    listApplicationsByApplicant: (token, uid) =>
      query(token, null, 'adoptionApplications', { where: { field: 'applicantId', value: uid } }),

    listApplicationsByPublisher(token, uid, listingId) {
      const filters = [{ field: 'publisherId', value: uid }];
      if (listingId) filters.push({ field: 'listingId', value: listingId });
      return query(token, null, 'adoptionApplications', { filters });
    },

    /** Crée la candidature ; lève une erreur 409 si la personne a déjà candidaté. */
    createApplication: (token, listingId, uid, data) =>
      run(token, [op(`adoptionApplications/${applicationId(listingId, uid)}`, { ...data, status: E.APPLICATION_STATUS.pending }, {
        serverTimestamps: ['createdAt', 'updatedAt'],
        mustNotExist: true,
      })]),

    // ----------------------------------------------------------- Profil

    getUserProfile: (token, uid) => get(token, `users/${uid}`),
  };
}

module.exports = { createAdoptionRepository, applicationId };
