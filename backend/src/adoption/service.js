// Règles métier du module Adoption : qui peut publier, archiver ou candidater, et dans quel état.
// Le service ne connaît ni Express ni Firestore : il appelle le dépôt et le notifieur.

const { ApiError } = require('../firestore');
const E = require('./enums');
const { computeCompatibility } = require('./compatibility');
const { parseFilters, matches } = require('./filters');
const { listingFields, applicationAnswers, photos: validPhotos } = require('./validation');

const newestFirst = (a, b) => new Date(b.createdAt || 0) - new Date(a.createdAt || 0);

function createAdoptionService(repository, notify) {
  const adoptionNotice = (title, body) => ({ title, body, category: 'adoption' });

  async function profileOf(token, uid) {
    const profile = await repository.getUserProfile(token, uid);
    if (!profile) throw new ApiError(404, 'Profil introuvable.');
    return profile;
  }

  async function listingOrFail(token, id) {
    const listing = await repository.getListing(token, id);
    if (!listing) throw new ApiError(404, 'Annonce introuvable.');
    return listing;
  }

  function ownListingOrFail(listing, uid) {
    if (listing.publisherId !== uid) throw new ApiError(403, "Vous n'êtes pas l'auteur de cette annonce.");
  }

  function requirePublisherRole(publisher) {
    if (publisher.role === 'prestataire') {
      throw new ApiError(403, 'Seuls les propriétaires et les refuges peuvent publier une annonce.');
    }
  }

  /** Données de l'annonce qui viennent de l'annonceur et de son statut. */
  const listingData = (fields, publisher, status) => ({
    ...fields,
    publisherId: publisher.id,
    publisherName: publisher.fullName,
    publisherIsShelter: publisher.role === 'refuge',
    status,
  });

  return {
    // ----------------------------------------------------------- Annonces

    /** Fil d'adoption : annonces disponibles et réservées, filtrées et les plus récentes d'abord. */
    async listPublicListings(token, query = {}) {
      const filters = parseFilters(query);
      return (await repository.listPublicListings(token)).filter((l) => matches(l, filters)).sort(newestFirst);
    },

    async listMyListings(token, uid) {
      return (await repository.listListingsByPublisher(token, uid)).sort(newestFirst);
    },

    getListing: listingOrFail,

    listPhotos: (token, listingId) => repository.listPhotos(token, listingId),

    /** Crée une annonce. `publish: false` l'enregistre comme brouillon. */
    async createListing(token, user, body) {
      const publisher = await profileOf(token, user.uid);
      requirePublisherRole(publisher);

      const fields = listingFields(body);
      const photos = validPhotos(body.photos);
      const publish = body.publish === true;
      if (publish && photos.length === 0) throw new ApiError(400, 'Ajoutez au moins une photo pour publier.');

      const status = publish ? E.LISTING_STATUS.available : E.LISTING_STATUS.draft;
      const id = await repository.saveListing(token, {
        data: listingData(fields, publisher, status),
        photos,
        creating: true,
      });
      return repository.getListing(token, id);
    },

    /** Modifie une annonce. Une annonce réservée ou adoptée garde son statut. */
    async updateListing(token, user, listingId, body) {
      const current = await listingOrFail(token, listingId);
      ownListingOrFail(current, user.uid);
      const publisher = await profileOf(token, user.uid);
      requirePublisherRole(publisher);

      const fields = listingFields(body);
      const photos = body.photos === undefined ? undefined : validPhotos(body.photos);
      const publish = body.publish === true;
      if (publish && photos !== undefined && photos.length === 0) {
        throw new ApiError(400, 'Ajoutez au moins une photo pour publier.');
      }

      const keepsStatus = [E.LISTING_STATUS.reserved, E.LISTING_STATUS.adopted].includes(current.status);
      const status = keepsStatus ? current.status : (publish ? E.LISTING_STATUS.available : E.LISTING_STATUS.draft);

      await repository.saveListing(token, {
        listingId: current.id,
        data: listingData(fields, publisher, status),
        photos,
        creating: false,
      });
      return repository.getListing(token, current.id);
    },

    /** Archive une annonce (jamais supprimée) et refuse les candidatures encore ouvertes. */
    async archiveListing(token, user, listingId) {
      const listing = await listingOrFail(token, listingId);
      ownListingOrFail(listing, user.uid);
      if (listing.status === E.LISTING_STATUS.reserved) {
        throw new ApiError(409, "Annulez d'abord l'acceptation en cours : une annonce réservée ne peut pas être archivée.");
      }

      const open = await repository.listOpenApplications(token, listing);
      const reason = `L'annonce de ${listing.name} a été retirée.`;
      await repository.archiveListing(token, listing.id, open.map((a) => ({ id: a.id, reason })));
      await Promise.all(open.map((a) =>
        notify(token, a.applicantId, adoptionNotice('Annonce retirée', `L'annonce de ${listing.name} n'est plus en ligne.`))));
    },

    // ----------------------------------------------------------- Favoris

    listFavoriteIds: (token, uid) => repository.listFavoriteIds(token, uid),
    addFavorite: (token, uid, listingId) => repository.addFavorite(token, uid, listingId),
    removeFavorite: (token, uid, listingId) => repository.removeFavorite(token, uid, listingId),

    // ----------------------------------------------------------- Candidatures

    /** Ma candidature pour cette annonce, ou `null`. */
    findMyApplication: (token, uid, listingId) => repository.findApplication(token, listingId, uid),

    /** Envoie une candidature ; le score de compatibilité est calculé ici, pas par le téléphone. */
    async apply(token, user, listingId, body) {
      const listing = await listingOrFail(token, listingId);
      if (listing.publisherId === user.uid) throw new ApiError(400, 'Vous ne pouvez pas candidater à votre propre annonce.');
      if (![E.LISTING_STATUS.available, E.LISTING_STATUS.reserved].includes(listing.status)) {
        throw new ApiError(409, `${listing.name} n'est plus proposé(e) à l'adoption.`);
      }
      const applicant = await profileOf(token, user.uid);
      const answers = applicationAnswers(body);
      const result = computeCompatibility(listing, answers);

      try {
        await repository.createApplication(token, listing.id, user.uid, {
          listingId: listing.id,
          listingName: listing.name,
          listingSpecies: listing.species,
          publisherId: listing.publisherId,
          publisherName: listing.publisherName,
          applicantId: user.uid,
          applicantName: applicant.fullName,
          answers,
          score: result.score,
          points: result.points,
        });
      } catch (error) {
        if (error.status === 409) throw new ApiError(409, 'Vous avez déjà envoyé une candidature pour cet animal.');
        throw error;
      }

      await notify(token, listing.publisherId,
        adoptionNotice('Nouvelle candidature', `${applicant.fullName} souhaite adopter ${listing.name}.`));
      return repository.findApplication(token, listing.id, user.uid);
    },

    async listMyApplications(token, uid) {
      return (await repository.listApplicationsByApplicant(token, uid)).sort(newestFirst);
    },

    /** Candidatures reçues par l'annonceur, meilleur score d'abord. */
    async listReceivedApplications(token, uid, listingId) {
      const apps = await repository.listApplicationsByPublisher(token, uid, listingId ? String(listingId) : undefined);
      return apps.sort((a, b) => b.score - a.score);
    },

    async getApplication(token, applicationDocId) {
      const application = await repository.getApplication(token, applicationDocId);
      if (!application) throw new ApiError(404, 'Candidature introuvable.');
      return application;
    },
  };
}

module.exports = { createAdoptionService };
