const express = require('express');

const { ApiError } = require('./firestore');
const { usersRouter } = require('./users/routes');
const { createUsersRepository } = require('./users/repository');
const { createUsersService } = require('./users/service');
const { createNotifier } = require('./notifier');
const { listingsRouter, applicationsRouter } = require('./adoption/routes');
const { createAdoptionRepository } = require('./adoption/repository');
const { createAdoptionService } = require('./adoption/service');
const { appointmentsRouter, remindersRouter } = require('./appointments/routes');
const { createAppointmentsRepository } = require('./appointments/repository');
const { createAppointmentsService, createRemindersService } = require('./appointments/service');
const { petsRouter } = require('./pets/routes');
const { healthRouter, healthSummaryRouter } = require('./health/routes');
const { createPetsRepository } = require('./pets/repository');
const { createPetsService } = require('./pets/service');
const { providersRouter, bookingsRouter, categoriesRouter } = require('./services/routes');
const { createServicesRepository } = require('./services/repository');
const { createServicesService } = require('./services/service');

function createApp() {
  const app = express();
  const notify = createNotifier();
  // Une fiche d'animal peut envoyer 5 photos de 750 Ko, soit 5 Mo en base64.
  app.use(express.json({ limit: '6mb' }));
  app.use((req, res, next) => {
    res.on('finish', () => console.log(`${req.method} ${req.originalUrl} -> ${res.statusCode}`));
    next();
  });

  app.get('/api/health', (_req, res) => res.json({ status: 'ok' }));

  app.use('/api/users/me', usersRouter(createUsersService(createUsersRepository())));
  const adoptionService = createAdoptionService(createAdoptionRepository(), notify);
  app.use('/api/adoptions', listingsRouter(adoptionService));
  app.use('/api/applications', applicationsRouter(adoptionService));
  const appointmentsRepository = createAppointmentsRepository();
  app.use('/api/appointments', appointmentsRouter(createAppointmentsService(appointmentsRepository, notify)));
  app.use('/api/reminders', remindersRouter(createRemindersService(appointmentsRepository)));
  app.use('/api/pets/:petId/health', healthRouter());
  app.use('/api/pets', petsRouter(createPetsService(createPetsRepository(), notify)));
  app.use('/api/health', healthSummaryRouter());
  const servicesService = createServicesService(createServicesRepository());
  app.use('/api/services/categories', categoriesRouter(servicesService));
  app.use('/api/services/providers', providersRouter(servicesService));
  app.use('/api/services/bookings', bookingsRouter(servicesService));
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
