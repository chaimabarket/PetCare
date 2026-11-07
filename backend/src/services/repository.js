// Couche données du module Services : seul endroit qui connaît les collections Firestore
// (`serviceProviders`, `serviceBookings`, `serviceCategories`) et leurs chemins.
// Aucune règle métier ici : le service décide, le dépôt lit et écrit.

const { getDocument, writeOp, deleteOp, commit, queryCollection, newId } = require('../firestore');

/** Un prestataire est identifié par l'uid de son compte : `serviceProviders/{uid}`. */
const providerPath = (id) => `serviceProviders/${id}`;

function createServicesRepository(firestore = { getDocument, writeOp, deleteOp, commit, queryCollection, newId }) {
  const { getDocument: get, writeOp: op, deleteOp: del, commit: run, queryCollection: query, newId: id } = firestore;

  return {
    // ----------------------------------------------------------- Prestataires

    listProvidersByStatus: (token, status) =>
      query(token, null, 'serviceProviders', { where: { field: 'status', value: status } }),

    getProvider: (token, providerId) => get(token, providerPath(providerId)),

    createProvider: (token, uid, fields) =>
      run(token, [op(providerPath(uid), { ownerId: uid, ...fields, status: 'pending' }, {
        serverTimestamps: ['updatedAt'],
        mustNotExist: true,
      })]),

    updateProvider: (token, uid, fields, status) =>
      run(token, [op(providerPath(uid), { ...fields, status }, { serverTimestamps: ['updatedAt'], mustExist: true })]),

    setProviderStatus: (token, providerId, status) =>
      run(token, [op(providerPath(providerId), { status }, { serverTimestamps: ['updatedAt'], mustExist: true })]),

    // ----------------------------------------------------------- Prestations

    listServices: (token, providerId, { onlyPublished }) =>
      query(token, providerPath(providerId), 'services', onlyPublished ? { where: { field: 'status', value: 'published' } } : {}),

    getService: (token, providerId, serviceId) => get(token, `${providerPath(providerId)}/services/${serviceId}`),

    /** Crée (serviceId null) ou modifie une prestation ; renvoie son identifiant. */
    async saveService(token, providerId, serviceId, fields) {
      const creating = serviceId === null;
      const idToUse = creating ? id() : serviceId;
      await run(token, [op(`${providerPath(providerId)}/services/${idToUse}`, { providerId, ...fields }, {
        serverTimestamps: ['updatedAt'],
        mustNotExist: creating,
        mustExist: !creating,
      })]);
      return idToUse;
    },

    // ----------------------------------------------------------- Disponibilités

    listAvailability: (token, providerId) => query(token, providerPath(providerId), 'availability'),

    getAvailability: (token, providerId, day) => get(token, `${providerPath(providerId)}/availability/${day}`),

    saveAvailability: (token, providerId, day, fields) =>
      run(token, [op(`${providerPath(providerId)}/availability/${day}`, fields, { serverTimestamps: ['updatedAt'] })]),

    // ----------------------------------------------------------- Réservations

    listBookings: (token, field, uid) => query(token, null, 'serviceBookings', { where: { field, value: uid } }),

    getBooking: (token, bookingId) => get(token, `serviceBookings/${bookingId}`),

    async createBooking(token, data) {
      const bookingId = id();
      await run(token, [op(`serviceBookings/${bookingId}`, { ...data, status: 'pending' }, {
        serverTimestamps: ['createdAt'],
        mustNotExist: true,
      })]);
      return bookingId;
    },

    setBookingStatus: (token, bookingId, status) =>
      run(token, [op(`serviceBookings/${bookingId}`, { status }, { serverTimestamps: ['updatedAt'], mustExist: true })]),

    // ----------------------------------------------------------- Catégories

    listCategories: (token) => query(token, null, 'serviceCategories'),

    getCategory: (token, categoryId) => get(token, `serviceCategories/${categoryId}`),

    async createCategory(token, fields, order) {
      const categoryId = id();
      await run(token, [op(`serviceCategories/${categoryId}`, { ...fields, order }, {
        serverTimestamps: ['updatedAt'],
        mustNotExist: true,
      })]);
      return categoryId;
    },

    updateCategory: (token, categoryId, fields, order) =>
      run(token, [op(`serviceCategories/${categoryId}`, { ...fields, order }, { serverTimestamps: ['updatedAt'], mustExist: true })]),

    deleteCategory: (token, categoryId) => run(token, [del(`serviceCategories/${categoryId}`)]),

    // ----------------------------------------------------------- Profil du client

    getUserProfile: (token, uid) => get(token, `users/${uid}`),
  };
}

module.exports = { createServicesRepository };
