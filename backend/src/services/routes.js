// Couche HTTP du module Services : lit la requête, appelle le service, écrit la réponse.
// Aucune règle métier ni accès aux données ici.

const express = require('express');

const { requireAuth, optionalAuth } = require('../auth');

const wrap = (handler) => (req, res, next) => Promise.resolve(handler(req, res)).catch(next);

function providersRouter(service) {
  const router = express.Router();

  /** Annuaire : prestataires publiés. Filtres facultatifs : `category`, `city`, `q`. */
  router.get('/', optionalAuth, wrap(async (req, res) => res.json(await service.listPublishedProviders(req.token, req.query))));

  /** Profils en attente de validation (administrateur). */
  router.get('/pending', requireAuth, wrap(async (req, res) => res.json(await service.listPendingProviders(req.token))));

  /** Crée ou modifie mon profil prestataire. */
  router.put('/me', requireAuth, wrap(async (req, res) =>
    res.json(await service.saveMyProfile(req.token, req.user.uid, req.body))));

  /** Mes prestations, archivées comprises. */
  router.get('/me/services', requireAuth, wrap(async (req, res) =>
    res.json(await service.listServices(req.token, req.user.uid, { all: true }))));

  router.post('/me/services', requireAuth, wrap(async (req, res) =>
    res.status(201).json(await service.saveService(req.token, req.user.uid, null, req.body))));

  router.put('/me/services/:serviceId', requireAuth, wrap(async (req, res) =>
    res.json(await service.saveService(req.token, req.user.uid, req.params.serviceId, req.body))));

  /** Disponibilité d'un jour de la semaine (1 = lundi … 7 = dimanche). */
  router.put('/me/availability/:weekday', requireAuth, wrap(async (req, res) =>
    res.json(await service.saveAvailability(req.token, req.user.uid, req.params.weekday, req.body))));

  /** L'administrateur valide ou refuse un profil. */
  router.put('/:id/status', requireAuth, wrap(async (req, res) =>
    res.json(await service.setProviderStatus(req.token, req.params.id, req.body))));

  router.get('/:id', optionalAuth, wrap(async (req, res) => res.json(await service.getProvider(req.token, req.params.id))));

  /** Prestations d'un prestataire : les publiées pour tout le monde, toutes pour son propriétaire (`?all=1`). */
  router.get('/:id/services', optionalAuth, wrap(async (req, res) =>
    res.json(await service.listServices(req.token, req.params.id, { all: req.query.all === '1' }))));

  /** Disponibilités : `{ "1": {enabled, ranges}, ... }`. */
  router.get('/:id/availability', optionalAuth, wrap(async (req, res) =>
    res.json(await service.listAvailability(req.token, req.params.id))));

  return router;
}

function bookingsRouter(service) {
  const router = express.Router();
  router.use(requireAuth);

  router.get('/', wrap(async (req, res) => res.json(await service.listBookings(req.token, req.user.uid, req.query.as))));

  router.post('/', wrap(async (req, res) => res.status(201).json(await service.createBooking(req.token, req.user, req.body))));

  router.patch('/:id/status', wrap(async (req, res) =>
    res.json(await service.answerBooking(req.token, req.user, req.params.id, req.body))));

  return router;
}

function categoriesRouter(service) {
  const router = express.Router();

  router.get('/', optionalAuth, wrap(async (req, res) => res.json(await service.listCategories(req.token))));

  router.post('/', requireAuth, wrap(async (req, res) => res.status(201).json(await service.addCategory(req.token, req.body))));

  router.put('/:id', requireAuth, wrap(async (req, res) =>
    res.json(await service.updateCategory(req.token, req.params.id, req.body))));

  router.delete('/:id', requireAuth, wrap(async (req, res) => {
    await service.deleteCategory(req.token, req.params.id);
    res.status(204).end();
  }));

  return router;
}

module.exports = { providersRouter, bookingsRouter, categoriesRouter };
