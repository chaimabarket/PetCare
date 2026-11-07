// Couche HTTP du module Rendez-vous : lit la requête, appelle le service, écrit la réponse.

const express = require('express');

const { requireAuth } = require('../auth');

const wrap = (handler) => (req, res, next) => Promise.resolve(handler(req, res)).catch(next);

function appointmentsRouter(service) {
  const router = express.Router();
  router.use(requireAuth);

  router.get('/', wrap(async (req, res) => res.json(await service.listAgenda(req.token, req.user.uid))));

  router.get('/:id', wrap(async (req, res) => res.json(await service.getAppointment(req.token, req.params.id))));

  router.post('/', wrap(async (req, res) => res.status(201).json(await service.createAppointment(req.token, req.user, req.body))));

  router.post('/:id/confirm', wrap(async (req, res) => res.json(await service.confirm(req.token, req.user, req.params.id, req.body))));

  router.post('/:id/reschedule', wrap(async (req, res) =>
    res.json(await service.reschedule(req.token, req.user, req.params.id, req.body))));

  router.post('/:id/cancel', wrap(async (req, res) => res.json(await service.cancel(req.token, req.user, req.params.id, req.body))));

  router.post('/:id/complete', wrap(async (req, res) => res.json(await service.complete(req.token, req.user, req.params.id, req.body))));

  router.put('/:id/reminder', wrap(async (req, res) =>
    res.json(await service.setReminder(req.token, req.user, req.params.id, req.body))));

  router.put('/:id/reminder-done', wrap(async (req, res) =>
    res.json(await service.setReminderDone(req.token, req.user, req.params.id, req.body))));

  return router;
}

function remindersRouter(service) {
  const router = express.Router();
  router.use(requireAuth);

  router.get('/', wrap(async (req, res) => res.json(await service.listReminders(req.token, req.user.uid))));

  router.post('/', wrap(async (req, res) => res.status(201).json(await service.createReminder(req.token, req.user.uid, req.body))));

  router.patch('/:id', wrap(async (req, res) => res.json(await service.setDone(req.token, req.params.id, req.body))));

  router.delete('/:id', wrap(async (req, res) => {
    await service.deleteReminder(req.token, req.params.id);
    res.status(204).end();
  }));

  return router;
}

module.exports = { appointmentsRouter, remindersRouter };
