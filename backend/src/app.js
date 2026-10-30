const express = require('express');

const { requireAuth } = require('./auth');
const { ApiError, getDocument, writeDocument, updateMany, queryCollection } = require('./firestore');
const { profileFields, role } = require('./validation');
const { listingsRouter, applicationsRouter } = require('./adoption/routes');
const { appointmentsRouter, remindersRouter } = require('./appointments/routes');

function publicProfile(doc) {
  const { id, fullName, email, city, phone, role: userRole, createdAt } = doc;
  return { uid: id, fullName, email, city, phone: phone ?? null, role: userRole, createdAt: createdAt ?? null };
}

const wrap = (handler) => (req, res, next) => Promise.resolve(handler(req, res)).catch(next);

function createApp() {
  const app = express();
  app.use(express.json({ limit: '4mb' }));
  // L'application lancée dans Chrome (flutter run -d chrome) est servie depuis une autre adresse
  // (localhost:5000…) : le navigateur exige ces en-têtes pour la laisser appeler l'API.
  // Le jeton circule dans l'en-tête Authorization, pas dans un cookie : autoriser toutes les origines est sans risque.
  app.use((req, res, next) => {
    res.set('Access-Control-Allow-Origin', '*');
    res.set('Access-Control-Allow-Headers', 'Authorization, Content-Type');
    res.set('Access-Control-Allow-Methods', 'GET, POST, PUT, PATCH, DELETE, OPTIONS');
    if (req.method === 'OPTIONS') return res.status(204).end();
    next();
  });
  app.use((req, res, next) => {
    res.on('finish', () => console.log(`${req.method} ${req.originalUrl} -> ${res.statusCode}`));
    next();
  });

  app.get('/api/health', (_req, res) => res.json({ status: 'ok' }));

  const me = express.Router();
  me.use(requireAuth);

  // ------------------------------------------------------------------ Profil

  /** Crée le profil juste après l'inscription Firebase Auth. */
  me.post('/', wrap(async (req, res) => {
    const { uid, email } = req.user;
    const path = `users/${uid}`;
    if (await getDocument(req.token, path)) throw new ApiError(409, 'Ce profil existe déjà.');

    const data = { ...profileFields(req.body), email, role: role(req.body.role) };
    await writeDocument(req.token, path, data, { serverTimestamps: ['createdAt'] });
    res.status(201).json(publicProfile(await getDocument(req.token, path)));
  }));

  me.get('/', wrap(async (req, res) => {
    const doc = await getDocument(req.token, `users/${req.user.uid}`);
    if (!doc) throw new ApiError(404, 'Profil introuvable.');
    res.json(publicProfile(doc));
  }));

  /** Modifie le nom, la ville et le téléphone ; le rôle et l'e-mail restent fixes. */
  me.put('/', wrap(async (req, res) => {
    const path = `users/${req.user.uid}`;
    await writeDocument(req.token, path, profileFields(req.body), {
      serverTimestamps: ['updatedAt'],
      mustExist: true,
    });
    res.json(publicProfile(await getDocument(req.token, path)));
  }));

  // ----------------------------------------------------------- Notifications

  me.get('/notifications', wrap(async (req, res) => {
    const limit = Math.min(Math.max(parseInt(req.query.limit, 10) || 50, 1), 100);
    res.json(
      await queryCollection(req.token, `users/${req.user.uid}`, 'notifications', {
        orderBy: 'createdAt',
        limit,
      }),
    );
  }));

  const unread = (req) =>
    queryCollection(req.token, `users/${req.user.uid}`, 'notifications', {
      where: { field: 'read', value: false },
    });

  me.get('/notifications/unread-count', wrap(async (req, res) => {
    res.json({ count: (await unread(req)).length });
  }));

  me.post('/notifications/read-all', wrap(async (req, res) => {
    const items = await unread(req);
    await updateMany(
      req.token,
      items.map((n) => ({ path: `users/${req.user.uid}/notifications/${n.id}`, data: { read: true } })),
    );
    res.json({ updated: items.length });
  }));

  me.patch('/notifications/:id/read', wrap(async (req, res) => {
    await writeDocument(req.token, `users/${req.user.uid}/notifications/${req.params.id}`, { read: true }, {
      mustExist: true,
    });
    res.status(204).end();
  }));

  app.use('/api/users/me', me);
  app.use('/api/adoptions', listingsRouter());
  app.use('/api/applications', applicationsRouter());
  app.use('/api/appointments', appointmentsRouter());
  app.use('/api/reminders', remindersRouter());
  app.use('/api', (_req, _res, next) => next(new ApiError(404, 'Route inconnue.')));

  // eslint-disable-next-line no-unused-vars
  app.use((error, _req, res, _next) => {
    if (error instanceof ApiError) return res.status(error.status).json({ error: error.message });
    if (error instanceof SyntaxError) return res.status(400).json({ error: 'Corps JSON invalide.' });
    console.error(error);
    res.status(500).json({ error: 'Erreur interne du serveur.' });
  });

  return app;
}

module.exports = { createApp };
