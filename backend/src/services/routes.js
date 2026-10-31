const express = require('express');

const { requireAuth, optionalAuth } = require('../auth');
const { ApiError, getDocument, writeOp, commit, queryCollection, newId } = require('../firestore');
const V = require('./validation');

const wrap = (handler) => (req, res, next) => Promise.resolve(handler(req, res)).catch(next);

const byName = (a, b) => String(a.name || '').localeCompare(String(b.name || ''), 'fr');

/** Un prestataire est identifié par l'uid de son compte : `serviceProviders/{uid}`. */
const providerPath = (id) => `serviceProviders/${id}`;

async function providerOrFail(token, id) {
  const provider = await getDocument(token, providerPath(id));
  if (!provider) throw new ApiError(404, 'Prestataire introuvable.');
  return provider;
}

function providersRouter() {
  const router = express.Router();

  /** Annuaire : prestataires publiés. Filtres facultatifs : `category`, `city`, `q`. */
  router.get('/', optionalAuth, wrap(async (req, res) => {
    const all = await queryCollection(req.token, null, 'serviceProviders', {
      where: { field: 'status', value: 'published' },
    });
    const q = String(req.query.q || '').trim().toLowerCase();
    const category = req.query.category && req.query.category !== 'Tous' ? String(req.query.category) : null;
    const city = req.query.city ? String(req.query.city).toLowerCase() : null;

    res.json(all
      .filter((p) => !category || p.category === category)
      .filter((p) => !city || String(p.city).toLowerCase() === city)
      .filter((p) => !q || [p.name, p.category, p.city, p.description].some((f) => String(f || '').toLowerCase().includes(q)))
      .sort(byName));
  }));

  /** Profils en attente de validation (administrateur). */
  router.get('/pending', requireAuth, wrap(async (req, res) => {
    const pending = await queryCollection(req.token, null, 'serviceProviders', {
      where: { field: 'status', value: 'pending' },
    });
    res.json(pending.sort(byName));
  }));

  /** Crée ou modifie mon profil prestataire. Un nouveau profil attend la validation de l'administrateur. */
  router.put('/me', requireAuth, wrap(async (req, res) => {
    const uid = req.user.uid;
    const fields = V.providerFields(req.body);
    const existing = await getDocument(req.token, providerPath(uid));

    if (!existing) {
      await commit(req.token, [writeOp(providerPath(uid), { ownerId: uid, ...fields, status: 'pending' }, {
        serverTimestamps: ['updatedAt'],
        mustNotExist: true,
      })]);
    } else {
      // Un profil refusé qui est corrigé repart en validation ; sinon le statut ne change pas.
      const status = existing.status === 'rejected' ? 'pending' : existing.status;
      await commit(req.token, [writeOp(providerPath(uid), { ...fields, status }, {
        serverTimestamps: ['updatedAt'],
        mustExist: true,
      })]);
    }
    res.json(await getDocument(req.token, providerPath(uid)));
  }));

  /** Mes prestations, archivées comprises. */
  router.get('/me/services', requireAuth, wrap(async (req, res) => {
    res.json((await queryCollection(req.token, providerPath(req.user.uid), 'services')).sort(byName));
  }));

  async function saveService(req, res, serviceId) {
    const uid = req.user.uid;
    if (!(await getDocument(req.token, providerPath(uid)))) {
      throw new ApiError(409, "Créez d'abord votre profil prestataire.");
    }
    const creating = serviceId === null;
    const id = creating ? newId() : serviceId;
    const path = `${providerPath(uid)}/services/${id}`;
    await commit(req.token, [writeOp(path, { providerId: uid, ...V.serviceFields(req.body) }, {
      serverTimestamps: ['updatedAt'],
      mustNotExist: creating,
      mustExist: !creating,
    })]);
    res.status(creating ? 201 : 200).json(await getDocument(req.token, path));
  }

  router.post('/me/services', requireAuth, wrap((req, res) => saveService(req, res, null)));
  router.put('/me/services/:serviceId', requireAuth, wrap((req, res) => saveService(req, res, req.params.serviceId)));

  /** Disponibilité d'un jour de la semaine (1 = lundi … 7 = dimanche). */
  router.put('/me/availability/:weekday', requireAuth, wrap(async (req, res) => {
    const day = V.weekday(req.params.weekday);
    const path = `${providerPath(req.user.uid)}/availability/${day}`;
    await commit(req.token, [writeOp(path, V.availabilityFields(req.body), { serverTimestamps: ['updatedAt'] })]);
    res.json(await getDocument(req.token, path));
  }));

  /** L'administrateur valide ou refuse un profil. */
  router.put('/:id/status', requireAuth, wrap(async (req, res) => {
    const status = V.oneOf(req.body?.status, V.PROVIDER_STATUSES, 'Le statut');
    await providerOrFail(req.token, req.params.id);
    await commit(req.token, [writeOp(providerPath(req.params.id), { status }, {
      serverTimestamps: ['updatedAt'],
      mustExist: true,
    })]);
    res.json(await getDocument(req.token, providerPath(req.params.id)));
  }));

  router.get('/:id', optionalAuth, wrap(async (req, res) => {
    res.json(await providerOrFail(req.token, req.params.id));
  }));

  /** Prestations d'un prestataire : les publiées pour tout le monde, toutes pour son propriétaire (`?all=1`). */
  router.get('/:id/services', optionalAuth, wrap(async (req, res) => {
    const options = req.query.all === '1' ? {} : { where: { field: 'status', value: 'published' } };
    res.json((await queryCollection(req.token, providerPath(req.params.id), 'services', options)).sort(byName));
  }));

  /** Disponibilités : `{ "1": {enabled, ranges}, ... }`. */
  router.get('/:id/availability', optionalAuth, wrap(async (req, res) => {
    const days = await queryCollection(req.token, providerPath(req.params.id), 'availability');
    res.json(Object.fromEntries(days.map(({ id, ...data }) => [id, data])));
  }));

  return router;
}

function bookingsRouter() {
  const router = express.Router();
  router.use(requireAuth);

  const byDate = (a, b) => new Date(a.dateTime) - new Date(b.dateTime);

  /** Mes réservations : `?as=client` (par défaut) ou `?as=provider` pour celles que j'ai reçues. */
  router.get('/', wrap(async (req, res) => {
    const field = req.query.as === 'provider' ? 'providerUid' : 'clientUid';
    const bookings = await queryCollection(req.token, null, 'serviceBookings', {
      where: { field, value: req.user.uid },
    });
    res.json(bookings.sort(byDate));
  }));

  /** Demande de réservation : le prestataire la confirme ou la refuse ensuite. */
  router.post('/', wrap(async (req, res) => {
    const input = V.bookingFields(req.body);
    if (input.providerId === req.user.uid) throw new ApiError(400, 'Vous ne pouvez pas réserver votre propre prestation.');

    const provider = await providerOrFail(req.token, input.providerId);
    const service = await getDocument(req.token, `${providerPath(input.providerId)}/services/${input.serviceId}`);
    if (!service) throw new ApiError(404, 'Prestation introuvable.');
    if (provider.status !== 'published' || service.status !== 'published') {
      throw new ApiError(409, "Cette prestation n'est plus disponible.");
    }
    const client = await getDocument(req.token, `users/${req.user.uid}`);

    const id = newId();
    await commit(req.token, [writeOp(`serviceBookings/${id}`, {
      providerUid: input.providerId,
      providerName: provider.name,
      clientUid: req.user.uid,
      clientName: client?.fullName || 'Utilisateur',
      serviceId: service.id,
      serviceName: service.name,
      animalName: input.animalName,
      dateTime: input.dateTime,
      notes: input.notes,
      status: 'pending',
    }, { serverTimestamps: ['createdAt'], mustNotExist: true })]);
    res.status(201).json(await getDocument(req.token, `serviceBookings/${id}`));
  }));

  /** Le prestataire confirme ou refuse (`confirmed`, `declined`), le client annule (`cancelled`). */
  router.patch('/:id/status', wrap(async (req, res) => {
    const status = V.oneOf(req.body?.status, V.BOOKING_STATUSES, 'Le statut');
    const path = `serviceBookings/${req.params.id}`;
    const booking = await getDocument(req.token, path);
    if (!booking) throw new ApiError(404, 'Réservation introuvable.');

    const asProvider = booking.providerUid === req.user.uid;
    const asClient = booking.clientUid === req.user.uid;
    if (!asProvider && !asClient) throw new ApiError(403, "Vous n'avez pas accès à cette réservation.");
    if (status === 'cancelled' ? !asClient : !asProvider) {
      throw new ApiError(403, status === 'cancelled'
        ? 'Seul le client peut annuler sa demande.'
        : 'Seul le prestataire peut confirmer ou refuser une demande.');
    }
    if (booking.status !== 'pending') throw new ApiError(409, "Cette demande a déjà reçu une réponse.");

    await commit(req.token, [writeOp(path, { status }, { serverTimestamps: ['updatedAt'], mustExist: true })]);
    res.json(await getDocument(req.token, path));
  }));

  return router;
}

module.exports = { providersRouter, bookingsRouter };
