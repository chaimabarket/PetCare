// Règles métier du module Services : ce qui est autorisé, dans quel ordre, avec quelles erreurs.
// Le service ne connaît ni Express (requête, réponse) ni Firestore : il appelle le dépôt.

const { ApiError } = require('../firestore');
const V = require('./validation');
const { categoryFields, DEFAULT_CATEGORIES } = require('./categories');

const byName = (a, b) => String(a.name || '').localeCompare(String(b.name || ''), 'fr');
const byDate = (a, b) => new Date(a.dateTime) - new Date(b.dateTime);
const byOrder = (a, b) => (a.order - b.order) || String(a.name).localeCompare(String(b.name), 'fr');

function createServicesService(repository) {
  async function providerOrFail(token, id) {
    const provider = await repository.getProvider(token, id);
    if (!provider) throw new ApiError(404, 'Prestataire introuvable.');
    return provider;
  }

  return {
    // ----------------------------------------------------------- Prestataires

    /** Annuaire : prestataires publiés, filtrés par `category`, `city` et `q`. */
    async listPublishedProviders(token, query = {}) {
      const all = await repository.listProvidersByStatus(token, 'published');
      const q = String(query.q || '').trim().toLowerCase();
      const category = query.category && query.category !== 'Tous' ? String(query.category) : null;
      const city = query.city ? String(query.city).toLowerCase() : null;

      return all
        .filter((p) => !category || p.category === category)
        .filter((p) => !city || String(p.city).toLowerCase() === city)
        .filter((p) => !q || [p.name, p.category, p.city, p.description].some((f) => String(f || '').toLowerCase().includes(q)))
        .sort(byName);
    },

    async listPendingProviders(token) {
      return (await repository.listProvidersByStatus(token, 'pending')).sort(byName);
    },

    getProvider: providerOrFail,

    /** Crée ou modifie mon profil. Un profil neuf attend la validation ; un profil refusé corrigé y repart. */
    async saveMyProfile(token, uid, body) {
      const fields = V.providerFields(body);
      const existing = await repository.getProvider(token, uid);
      if (!existing) await repository.createProvider(token, uid, fields);
      else await repository.updateProvider(token, uid, fields, existing.status === 'rejected' ? 'pending' : existing.status);
      return repository.getProvider(token, uid);
    },

    /** L'administrateur valide ou refuse un profil (les règles Firestore vérifient son rôle). */
    async setProviderStatus(token, providerId, body) {
      const status = V.oneOf(body?.status, V.PROVIDER_STATUSES, 'Le statut');
      await providerOrFail(token, providerId);
      await repository.setProviderStatus(token, providerId, status);
      return repository.getProvider(token, providerId);
    },

    // ----------------------------------------------------------- Prestations

    async listServices(token, providerId, { all = false } = {}) {
      return (await repository.listServices(token, providerId, { onlyPublished: !all })).sort(byName);
    },

    async saveService(token, uid, serviceId, body) {
      if (!(await repository.getProvider(token, uid))) throw new ApiError(409, "Créez d'abord votre profil prestataire.");
      const fields = V.serviceFields(body);
      const id = await repository.saveService(token, uid, serviceId, fields);
      return repository.getService(token, uid, id);
    },

    // ----------------------------------------------------------- Disponibilités

    async listAvailability(token, providerId) {
      const days = await repository.listAvailability(token, providerId);
      return Object.fromEntries(days.map(({ id, ...data }) => [id, data]));
    },

    async saveAvailability(token, uid, weekday, body) {
      const day = V.weekday(weekday);
      await repository.saveAvailability(token, uid, day, V.availabilityFields(body));
      return repository.getAvailability(token, uid, day);
    },

    // ----------------------------------------------------------- Réservations

    /** Mes réservations : `client` (par défaut) ou `provider` pour celles que j'ai reçues. */
    async listBookings(token, uid, as) {
      const field = as === 'provider' ? 'providerUid' : 'clientUid';
      return (await repository.listBookings(token, field, uid)).sort(byDate);
    },

    /** Demande de réservation : le prestataire la confirme ou la refuse ensuite. */
    async createBooking(token, user, body) {
      const input = V.bookingFields(body);
      if (input.providerId === user.uid) throw new ApiError(400, 'Vous ne pouvez pas réserver votre propre prestation.');

      const provider = await providerOrFail(token, input.providerId);
      const service = await repository.getService(token, input.providerId, input.serviceId);
      if (!service) throw new ApiError(404, 'Prestation introuvable.');
      if (provider.status !== 'published' || service.status !== 'published') {
        throw new ApiError(409, "Cette prestation n'est plus disponible.");
      }
      const client = await repository.getUserProfile(token, user.uid);

      const id = await repository.createBooking(token, {
        providerUid: input.providerId,
        providerName: provider.name,
        clientUid: user.uid,
        clientName: client?.fullName || 'Utilisateur',
        serviceId: service.id,
        serviceName: service.name,
        animalName: input.animalName,
        dateTime: input.dateTime,
        notes: input.notes,
      });
      return repository.getBooking(token, id);
    },

    /** Le prestataire confirme ou refuse (`confirmed`, `declined`), le client annule (`cancelled`). */
    async answerBooking(token, user, bookingId, body) {
      const status = V.oneOf(body?.status, V.BOOKING_STATUSES, 'Le statut');
      const booking = await repository.getBooking(token, bookingId);
      if (!booking) throw new ApiError(404, 'Réservation introuvable.');

      const asProvider = booking.providerUid === user.uid;
      const asClient = booking.clientUid === user.uid;
      if (!asProvider && !asClient) throw new ApiError(403, "Vous n'avez pas accès à cette réservation.");
      if (status === 'cancelled' ? !asClient : !asProvider) {
        throw new ApiError(403, status === 'cancelled'
          ? 'Seul le client peut annuler sa demande.'
          : 'Seul le prestataire peut confirmer ou refuser une demande.');
      }
      if (booking.status !== 'pending') throw new ApiError(409, 'Cette demande a déjà reçu une réponse.');

      await repository.setBookingStatus(token, bookingId, status);
      return repository.getBooking(token, bookingId);
    },

    // ----------------------------------------------------------- Catégories

    /** Catégories dans l'ordre d'affichage ; les six historiques tant que l'administrateur n'en a pas enregistré. */
    async listCategories(token) {
      const stored = await repository.listCategories(token);
      return stored.length === 0 ? DEFAULT_CATEGORIES : stored.sort(byOrder);
    },

    /** Une nouvelle catégorie s'affiche en dernier, avant « Autres » (ordre 99). */
    async addCategory(token, body) {
      const fields = categoryFields(body);
      const regular = (await repository.listCategories(token)).filter((c) => c.order < 99);
      const order = regular.length === 0 ? 1 : Math.max(...regular.map((c) => c.order)) + 1;
      const id = await repository.createCategory(token, fields, order);
      return repository.getCategory(token, id);
    },

    async updateCategory(token, categoryId, body) {
      const fields = categoryFields(body);
      const current = await repository.getCategory(token, categoryId);
      if (!current) throw new ApiError(404, 'Catégorie introuvable.');
      const order = Number.isInteger(body.order) ? body.order : current.order;
      await repository.updateCategory(token, categoryId, fields, order);
      return repository.getCategory(token, categoryId);
    },

    deleteCategory: (token, categoryId) => repository.deleteCategory(token, categoryId),
  };
}

module.exports = { createServicesService };
