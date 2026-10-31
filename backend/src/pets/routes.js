// Couche HTTP du module Profils des animaux : lit la requête, appelle le service, écrit la réponse.

const express = require('express');

const { requireAuth } = require('../auth');

const wrap = (handler) => (req, res, next) => Promise.resolve(handler(req, res)).catch(next);
const noContent = (action) => wrap(async (req, res) => {
  await action(req);
  res.status(204).end();
});

function petsRouter(service) {
  const router = express.Router();
  router.use(requireAuth);

  // ------------------------------------------------------------------ Fiches

  router.get('/', wrap(async (req, res) => res.json(await service.listPets(req.token, req.user.uid, req.query.status))));

  router.post('/', wrap(async (req, res) => res.status(201).json(await service.createPet(req.token, req.user.uid, req.body))));

  router.get('/:id', wrap(async (req, res) => res.json(await service.getPet(req.token, req.user.uid, req.params.id))));

  router.put('/:id', wrap(async (req, res) =>
    res.json(await service.updatePet(req.token, req.user.uid, req.params.id, req.body))));

  router.patch('/:id', wrap(async (req, res) =>
    res.json(await service.patchPet(req.token, req.user.uid, req.params.id, req.body))));

  router.post('/:id/archive', noContent((req) => service.archivePet(req.token, req.user.uid, req.params.id)));

  router.post('/:id/restore', noContent((req) => service.restorePet(req.token, req.user.uid, req.params.id)));

  // ------------------------------------------------------------------ Photos

  router.get('/:id/photos', wrap(async (req, res) => res.json(await service.listPhotos(req.token, req.params.id))));

  router.get('/:id/cover', wrap(async (req, res) => res.json(await service.getCover(req.token, req.params.id))));

  router.post('/:id/photos', wrap(async (req, res) =>
    res.status(201).json(await service.addPhoto(req.token, req.user.uid, req.params.id, req.body))));

  router.delete('/:id/photos/:photoId', noContent((req) =>
    service.removePhoto(req.token, req.user.uid, req.params.id, req.params.photoId)));

  router.post('/:id/photos/:photoId/cover', noContent((req) =>
    service.setCover(req.token, req.user.uid, req.params.id, req.params.photoId)));

  // ------------------------------------------------------------------ Pesées

  router.get('/:id/weights', wrap(async (req, res) =>
    res.json(await service.listWeights(req.token, req.params.id, req.query.limit))));

  router.post('/:id/weights', wrap(async (req, res) =>
    res.status(201).json(await service.addWeight(req.token, req.user.uid, req.params.id, req.body))));

  router.put('/:id/weights/:entryId', wrap(async (req, res) =>
    res.json(await service.updateWeight(req.token, req.user.uid, req.params.id, req.params.entryId, req.body))));

  router.delete('/:id/weights/:entryId', noContent((req) =>
    service.deleteWeight(req.token, req.user.uid, req.params.id, req.params.entryId)));

  return router;
}

module.exports = { petsRouter };
