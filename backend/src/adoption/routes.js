// Couche HTTP du module Adoption : lit la requête, appelle le service, écrit la réponse.

const express = require('express');

const { requireAuth, optionalAuth } = require('../auth');

const wrap = (handler) => (req, res, next) => Promise.resolve(handler(req, res)).catch(next);

function listingsRouter(service) {
  const router = express.Router();

  router.get('/', optionalAuth, wrap(async (req, res) => res.json(await service.listPublicListings(req.token, req.query))));

  router.get('/mine', requireAuth, wrap(async (req, res) => res.json(await service.listMyListings(req.token, req.user.uid))));

  // ------------------------------------------------------------------ Favoris

  router.get('/favorites', requireAuth, wrap(async (req, res) =>
    res.json({ ids: await service.listFavoriteIds(req.token, req.user.uid) })));

  router.put('/:id/favorite', requireAuth, wrap(async (req, res) => {
    await service.addFavorite(req.token, req.user.uid, req.params.id);
    res.status(204).end();
  }));

  router.delete('/:id/favorite', requireAuth, wrap(async (req, res) => {
    await service.removeFavorite(req.token, req.user.uid, req.params.id);
    res.status(204).end();
  }));

  // ------------------------------------------------------------------ Annonces

  router.get('/:id', optionalAuth, wrap(async (req, res) => res.json(await service.getListing(req.token, req.params.id))));

  router.get('/:id/photos', optionalAuth, wrap(async (req, res) =>
    res.json({ photos: await service.listPhotos(req.token, req.params.id) })));

  router.post('/', requireAuth, wrap(async (req, res) =>
    res.status(201).json(await service.createListing(req.token, req.user, req.body))));

  router.put('/:id', requireAuth, wrap(async (req, res) =>
    res.json(await service.updateListing(req.token, req.user, req.params.id, req.body))));

  router.post('/:id/archive', requireAuth, wrap(async (req, res) => {
    await service.archiveListing(req.token, req.user, req.params.id);
    res.status(204).end();
  }));

  // -------------------------------------------------------------- Candidatures

  router.get('/:id/applications/me', requireAuth, wrap(async (req, res) =>
    res.json(await service.findMyApplication(req.token, req.user.uid, req.params.id))));

  router.post('/:id/applications', requireAuth, wrap(async (req, res) =>
    res.status(201).json(await service.apply(req.token, req.user, req.params.id, req.body))));

  return router;
}

function applicationsRouter(service) {
  const router = express.Router();
  router.use(requireAuth);

  router.get('/mine', wrap(async (req, res) => res.json(await service.listMyApplications(req.token, req.user.uid))));

  router.get('/received', wrap(async (req, res) =>
    res.json(await service.listReceivedApplications(req.token, req.user.uid, req.query.listingId))));

  router.get('/:id', wrap(async (req, res) => res.json(await service.getApplication(req.token, req.params.id))));

  return router;
}

module.exports = { listingsRouter, applicationsRouter };
