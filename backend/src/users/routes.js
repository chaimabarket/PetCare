// Couche HTTP du module Utilisateurs (`/api/users/me`) : requête → service → réponse.

const express = require('express');

const { requireAuth } = require('../auth');

const wrap = (handler) => (req, res, next) => Promise.resolve(handler(req, res)).catch(next);

function usersRouter(service) {
  const router = express.Router();
  router.use(requireAuth);

  router.post('/', wrap(async (req, res) => res.status(201).json(await service.createProfile(req.token, req.user, req.body))));

  router.get('/', wrap(async (req, res) => res.json(await service.getProfile(req.token, req.user.uid))));

  router.put('/', wrap(async (req, res) => res.json(await service.updateProfile(req.token, req.user.uid, req.body))));

  router.get('/notifications', wrap(async (req, res) =>
    res.json(await service.listNotifications(req.token, req.user.uid, req.query.limit))));

  router.get('/notifications/unread-count', wrap(async (req, res) =>
    res.json(await service.unreadCount(req.token, req.user.uid))));

  router.post('/notifications/read-all', wrap(async (req, res) =>
    res.json(await service.markAllRead(req.token, req.user.uid))));

  router.patch('/notifications/:id/read', wrap(async (req, res) => {
    await service.markRead(req.token, req.user.uid, req.params.id);
    res.status(204).end();
  }));

  return router;
}

module.exports = { usersRouter };
