// Couche HTTP du module Santé : lit la requête, appelle le service, écrit la réponse.

const express = require('express');

const { requireAuth } = require('../auth');

const wrap = (handler) => (req, res, next) => Promise.resolve(handler(req, res)).catch(next);
const noContent = (action) => wrap(async (req, res) => {
  await action(req);
  res.status(204).end();
});

/**
 * Carnet de santé et traitements d'un animal : `/api/pets/{petId}/health/...`.
 * Seul le propriétaire de l'animal y a accès (règles Firestore du module Santé).
 */
function healthRouter(service) {
  const router = express.Router({ mergeParams: true });
  router.use(requireAuth);

  // ------------------------------------------------------------------ Carnet

  router.get('/entries', wrap(async (req, res) => res.json(await service.listEntries(req.token, req.params.petId))));

  router.get('/entries/:entryId', wrap(async (req, res) =>
    res.json(await service.getEntry(req.token, req.params.petId, req.params.entryId))));

  router.post('/entries', wrap(async (req, res) =>
    res.status(201).json(await service.addEntry(req.token, req.user, req.params.petId, req.body))));

  router.patch('/entries/:entryId/reminder-done', noContent((req) =>
    service.markReminderDone(req.token, req.user, req.params.petId, req.params.entryId)));

  router.get('/entries/:entryId/files/:index', wrap(async (req, res) =>
    res.json(await service.getEntryFile(req.token, req.params.petId, req.params.entryId, req.params.index))));

  router.delete('/entries/:entryId', noContent((req) =>
    service.deleteEntry(req.token, req.user, req.params.petId, req.params.entryId)));

  // ------------------------------------------------------------------ Traitements

  router.get('/treatments', wrap(async (req, res) => res.json(await service.listTreatments(req.token, req.params.petId))));

  router.get('/treatments/:treatmentId', wrap(async (req, res) =>
    res.json(await service.getTreatment(req.token, req.params.petId, req.params.treatmentId))));

  router.post('/treatments', wrap(async (req, res) =>
    res.status(201).json(await service.addTreatment(req.token, req.user, req.params.petId, req.body))));

  router.post('/treatments/:treatmentId/doses', wrap(async (req, res) =>
    res.status(201).json(await service.addDose(req.token, req.user, req.params.petId, req.params.treatmentId, req.body))));

  router.post('/treatments/:treatmentId/stop', wrap(async (req, res) =>
    res.json(await service.stopTreatment(req.token, req.user, req.params.petId, req.params.treatmentId, req.body))));

  return router;
}

/** `/api/health/summary` : synthèse de tous mes animaux, en un seul appel. */
function healthSummaryRouter(service) {
  const router = express.Router();
  router.use(requireAuth);

  router.get('/summary', wrap(async (req, res) => res.json(await service.summary(req.token, req.user.uid))));

  return router;
}

module.exports = { healthRouter, healthSummaryRouter };
