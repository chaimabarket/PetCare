const express = require('express');

const { requireAuth, optionalAuth } = require('../auth');
const {
  ApiError, getDocument, writeOp, deleteOp, commit, writeDocument, queryCollection, newId,
} = require('../firestore');
const E = require('./enums');
const { computeCompatibility } = require('./compatibility');
const { parseFilters, matches } = require('./filters');
const { listingFields, applicationAnswers, photos: validPhotos, MAX_PHOTOS } = require('./validation');

const wrap = (handler) => (req, res, next) => Promise.resolve(handler(req, res)).catch(next);

const newestFirst = (a, b) => new Date(b.createdAt || 0) - new Date(a.createdAt || 0);
const applicationId = (listingId, uid) => `${listingId}_${uid}`;

/** Notification de la catégorie Adoption ; c'est un complément, son échec ne bloque jamais l'action. */
async function notify(token, uid, title, body) {
  try {
    await writeDocument(token, `users/${uid}/notifications/${newId()}`, { title, body, category: 'adoption', read: false }, {
      serverTimestamps: ['createdAt'],
      mustNotExist: true,
    });
  } catch {
    // Ignoré volontairement.
  }
}

async function profileOf(token, uid) {
  const profile = await getDocument(token, `users/${uid}`);
  if (!profile) throw new ApiError(404, 'Profil introuvable.');
  return profile;
}

async function listingOrFail(token, id) {
  const listing = await getDocument(token, `adoptions/${id}`);
  if (!listing) throw new ApiError(404, 'Annonce introuvable.');
  return listing;
}

function ownListingOrFail(listing, uid) {
  if (listing.publisherId !== uid) throw new ApiError(403, "Vous n'êtes pas l'auteur de cette annonce.");
}

function openApplications(token, listing) {
  return queryCollection(token, null, 'adoptionApplications', {
    filters: [
      { field: 'publisherId', value: listing.publisherId },
      { field: 'listingId', value: listing.id },
    ],
  }).then((apps) => apps.filter((a) => E.OPEN_APPLICATION_STATUSES.includes(a.status)));
}

// ------------------------------------------------------------------ Annonces

function listingsRouter() {
  const router = express.Router();

  /** Fil d'adoption : annonces disponibles et réservées, filtrées et les plus récentes d'abord. */
  router.get('/', optionalAuth, wrap(async (req, res) => {
    const all = await queryCollection(req.token, null, 'adoptions', {
      filters: [{ field: 'status', op: 'IN', value: [E.LISTING_STATUS.available, E.LISTING_STATUS.reserved] }],
    });
    const filters = parseFilters(req.query);
    res.json(all.filter((l) => matches(l, filters)).sort(newestFirst));
  }));

  router.get('/mine', requireAuth, wrap(async (req, res) => {
    const mine = await queryCollection(req.token, null, 'adoptions', {
      where: { field: 'publisherId', value: req.user.uid },
    });
    res.json(mine.sort(newestFirst));
  }));

  // ------------------------------------------------------------------ Favoris

  router.get('/favorites', requireAuth, wrap(async (req, res) => {
    const docs = await queryCollection(req.token, `users/${req.user.uid}`, 'adoptionFavorites');
    res.json({ ids: docs.map((d) => d.id) });
  }));

  router.put('/:id/favorite', requireAuth, wrap(async (req, res) => {
    await writeDocument(req.token, `users/${req.user.uid}/adoptionFavorites/${req.params.id}`, {}, {
      serverTimestamps: ['createdAt'],
    });
    res.status(204).end();
  }));

  router.delete('/:id/favorite', requireAuth, wrap(async (req, res) => {
    await commit(req.token, [deleteOp(`users/${req.user.uid}/adoptionFavorites/${req.params.id}`)]);
    res.status(204).end();
  }));

  // ------------------------------------------------------------------ Lecture

  router.get('/:id', optionalAuth, wrap(async (req, res) => {
    res.json(await listingOrFail(req.token, req.params.id));
  }));

  /** Photos en base64, dans l'ordre de l'annonce. */
  router.get('/:id/photos', optionalAuth, wrap(async (req, res) => {
    const docs = await queryCollection(req.token, `adoptions/${req.params.id}`, 'photos');
    const sorted = docs.sort((a, b) => Number(a.id) - Number(b.id));
    res.json({ photos: sorted.map((d) => d.data) });
  }));

  // ------------------------------------------------------------------ Écriture

  /** Écritures d'une annonce : le document, puis ses photos (de 0 à 4). */
  function saveListingWrites({ id, fields, list, status, publisher, creating }) {
    const data = {
      ...fields,
      publisherId: publisher.id,
      publisherName: publisher.fullName,
      publisherIsShelter: publisher.role === 'refuge',
      status,
    };
    if (list !== undefined) {
      data.photoCount = list.length;
      data.cover = list.length === 0 ? null : list[0];
    }
    if (creating) data.acceptedApplicationId = null;

    const writes = [
      writeOp(`adoptions/${id}`, data, {
        serverTimestamps: creating ? ['updatedAt', 'createdAt'] : ['updatedAt'],
        mustNotExist: creating,
        mustExist: !creating,
      }),
    ];
    if (list !== undefined) {
      for (let i = 0; i < MAX_PHOTOS; i += 1) {
        if (i < list.length) writes.push(writeOp(`adoptions/${id}/photos/${i}`, { data: list[i] }, { replace: true }));
        else if (!creating) writes.push(deleteOp(`adoptions/${id}/photos/${i}`));
      }
    }
    return writes;
  }

  function requirePublisherRole(publisher) {
    if (publisher.role === 'prestataire') {
      throw new ApiError(403, 'Seuls les propriétaires et les refuges peuvent publier une annonce.');
    }
  }

  /** Crée une annonce. `publish: false` l'enregistre comme brouillon. */
  router.post('/', requireAuth, wrap(async (req, res) => {
    const publisher = await profileOf(req.token, req.user.uid);
    requirePublisherRole(publisher);

    const fields = listingFields(req.body);
    const list = validPhotos(req.body.photos);
    if (req.body.publish === true && list.length === 0) {
      throw new ApiError(400, 'Ajoutez au moins une photo pour publier.');
    }
    const id = newId();
    const status = req.body.publish === true ? E.LISTING_STATUS.available : E.LISTING_STATUS.draft;
    await commit(req.token, saveListingWrites({ id, fields, list, status, publisher, creating: true }));
    res.status(201).json(await getDocument(req.token, `adoptions/${id}`));
  }));

  /** Modifie une annonce. Une annonce réservée ou adoptée garde son statut. */
  router.put('/:id', requireAuth, wrap(async (req, res) => {
    const current = await listingOrFail(req.token, req.params.id);
    ownListingOrFail(current, req.user.uid);
    const publisher = await profileOf(req.token, req.user.uid);
    requirePublisherRole(publisher);

    const fields = listingFields(req.body);
    const list = req.body.photos === undefined ? undefined : validPhotos(req.body.photos);
    if (req.body.publish === true && list !== undefined && list.length === 0) {
      throw new ApiError(400, 'Ajoutez au moins une photo pour publier.');
    }
    const keepsStatus = [E.LISTING_STATUS.reserved, E.LISTING_STATUS.adopted].includes(current.status);
    const status = keepsStatus
      ? current.status
      : (req.body.publish === true ? E.LISTING_STATUS.available : E.LISTING_STATUS.draft);

    await commit(req.token, saveListingWrites({ id: current.id, fields, list, status, publisher, creating: false }));
    res.json(await getDocument(req.token, `adoptions/${current.id}`));
  }));

  /** Archive une annonce (jamais supprimée) et refuse les candidatures encore ouvertes. */
  router.post('/:id/archive', requireAuth, wrap(async (req, res) => {
    const listing = await listingOrFail(req.token, req.params.id);
    ownListingOrFail(listing, req.user.uid);
    if (listing.status === E.LISTING_STATUS.reserved) {
      throw new ApiError(409,
        "Annulez d'abord l'acceptation en cours : une annonce réservée ne peut pas être archivée.");
    }

    const open = await openApplications(req.token, listing);
    const writes = [
      writeOp(`adoptions/${listing.id}`, { status: E.LISTING_STATUS.archived }, {
        serverTimestamps: ['updatedAt'],
        mustExist: true,
      }),
      ...open.map((app) => writeOp(`adoptionApplications/${app.id}`, {
        status: E.APPLICATION_STATUS.refused,
        refusalReason: `L'annonce de ${listing.name} a été retirée.`,
      }, { serverTimestamps: ['updatedAt'], mustExist: true })),
    ];
    await commit(req.token, writes);
    await Promise.all(open.map((app) =>
      notify(req.token, app.applicantId, 'Annonce retirée', `L'annonce de ${listing.name} n'est plus en ligne.`)));
    res.status(204).end();
  }));

  // -------------------------------------------------------------- Candidatures

  /** Ma candidature pour cette annonce, ou `null`. */
  router.get('/:id/applications/me', requireAuth, wrap(async (req, res) => {
    res.json(await getDocument(req.token, `adoptionApplications/${applicationId(req.params.id, req.user.uid)}`));
  }));

  /** Envoie une candidature ; le score de compatibilité est calculé ici. */
  router.post('/:id/applications', requireAuth, wrap(async (req, res) => {
    const listing = await listingOrFail(req.token, req.params.id);
    if (listing.publisherId === req.user.uid) {
      throw new ApiError(400, 'Vous ne pouvez pas candidater à votre propre annonce.');
    }
    if (![E.LISTING_STATUS.available, E.LISTING_STATUS.reserved].includes(listing.status)) {
      throw new ApiError(409, `${listing.name} n'est plus proposé(e) à l'adoption.`);
    }
    const applicant = await profileOf(req.token, req.user.uid);
    const answers = applicationAnswers(req.body);
    const result = computeCompatibility(listing, answers);
    const id = applicationId(listing.id, req.user.uid);

    try {
      await commit(req.token, [writeOp(`adoptionApplications/${id}`, {
        listingId: listing.id,
        listingName: listing.name,
        listingSpecies: listing.species,
        publisherId: listing.publisherId,
        publisherName: listing.publisherName,
        applicantId: req.user.uid,
        applicantName: applicant.fullName,
        answers,
        score: result.score,
        points: result.points,
        status: E.APPLICATION_STATUS.pending,
      }, { serverTimestamps: ['createdAt', 'updatedAt'], mustNotExist: true })]);
    } catch (error) {
      if (error.status === 409) throw new ApiError(409, 'Vous avez déjà envoyé une candidature pour cet animal.');
      throw error;
    }

    await notify(req.token, listing.publisherId, 'Nouvelle candidature',
      `${applicant.fullName} souhaite adopter ${listing.name}.`);
    res.status(201).json(await getDocument(req.token, `adoptionApplications/${id}`));
  }));

  return router;
}

function applicationsRouter() {
  const router = express.Router();
  router.use(requireAuth);

  router.get('/mine', wrap(async (req, res) => {
    const apps = await queryCollection(req.token, null, 'adoptionApplications', {
      where: { field: 'applicantId', value: req.user.uid },
    });
    res.json(apps.sort(newestFirst));
  }));

  /** Candidatures reçues par l'annonceur (`?listingId=` pour une seule annonce), meilleur score d'abord. */
  router.get('/received', wrap(async (req, res) => {
    const filters = [{ field: 'publisherId', value: req.user.uid }];
    if (req.query.listingId) filters.push({ field: 'listingId', value: String(req.query.listingId) });
    const apps = await queryCollection(req.token, null, 'adoptionApplications', { filters });
    res.json(apps.sort((a, b) => b.score - a.score));
  }));

  router.get('/:id', wrap(async (req, res) => {
    const app = await getDocument(req.token, `adoptionApplications/${req.params.id}`);
    if (!app) throw new ApiError(404, 'Candidature introuvable.');
    res.json(app);
  }));

  return router;
}

module.exports = { listingsRouter, applicationsRouter };
