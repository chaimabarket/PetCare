// Tests du service Services avec un faux dépôt en mémoire : aucune connexion à Firestore.

const test = require('node:test');
const assert = require('node:assert');

const { createServicesService } = require('../src/services/service');

const future = () => new Date(Date.now() + 86400000).toISOString();

/** Faux dépôt : les données sont dans des objets JavaScript. */
function fakeRepository({ providers = {}, services = {}, bookings = {}, categories = [], users = {} } = {}) {
  const calls = [];
  return {
    calls,
    getProvider: async (_t, id) => providers[id] ?? null,
    listProvidersByStatus: async (_t, status) => Object.values(providers).filter((p) => p.status === status),
    getService: async (_t, providerId, serviceId) => services[`${providerId}/${serviceId}`] ?? null,
    getUserProfile: async (_t, uid) => users[uid] ?? null,
    createBooking: async (_t, data) => {
      calls.push(['createBooking', data]);
      bookings.b1 = { id: 'b1', status: 'pending', ...data };
      return 'b1';
    },
    getBooking: async (_t, id) => bookings[id] ?? null,
    setBookingStatus: async (_t, id, status) => {
      calls.push(['setBookingStatus', id, status]);
      bookings[id] = { ...bookings[id], status };
    },
    listCategories: async () => categories,
    createCategory: async (_t, fields, order) => {
      calls.push(['createCategory', fields, order]);
      return 'c1';
    },
    getCategory: async () => ({ id: 'c1' }),
    createProvider: async (_t, uid, fields) => {
      calls.push(['createProvider', uid, fields]);
      providers[uid] = { id: uid, ...fields, status: 'pending' };
    },
    updateProvider: async (_t, uid, fields, status) => {
      calls.push(['updateProvider', uid, status]);
      providers[uid] = { ...providers[uid], ...fields, status };
    },
  };
}

const provider = (over = {}) => ({ id: 'p1', name: 'Clinique', status: 'published', category: 'Vétérinaires', city: 'Tunis', description: '', ...over });
const service = (over = {}) => ({ id: 's1', name: 'Consultation', status: 'published', ...over });
const profileBody = { name: 'Clinique', category: 'Vétérinaires', city: 'Tunis', description: '', phone: '+216 20 123 456', email: 'a@b.tn' };

test('annuaire : filtre par catégorie, ville et recherche, trié par nom', async () => {
  const repo = fakeRepository({
    providers: {
      a: provider({ id: 'a', name: 'Zoo Plus', category: 'Boutiques', city: 'Tunis' }),
      b: provider({ id: 'b', name: 'Clinique Nord', category: 'Vétérinaires', city: 'Sfax' }),
      c: provider({ id: 'c', name: 'Clinique Sud', category: 'Vétérinaires', city: 'Tunis' }),
    },
  });
  const s = createServicesService(repo);

  assert.deepStrictEqual((await s.listPublishedProviders('t', {})).map((p) => p.id), ['b', 'c', 'a']);
  assert.deepStrictEqual((await s.listPublishedProviders('t', { category: 'Vétérinaires' })).map((p) => p.id), ['b', 'c']);
  assert.deepStrictEqual((await s.listPublishedProviders('t', { category: 'Tous', city: 'tunis' })).map((p) => p.id), ['c', 'a']);
  assert.deepStrictEqual((await s.listPublishedProviders('t', { q: 'zoo' })).map((p) => p.id), ['a']);
});

test('un profil neuf attend la validation, un profil refusé corrigé repart en attente', async () => {
  const repo = fakeRepository({ providers: { u1: provider({ id: 'u1', status: 'rejected' }) } });
  const s = createServicesService(repo);

  await s.saveMyProfile('t', 'u1', profileBody);
  assert.deepStrictEqual(repo.calls.at(-1), ['updateProvider', 'u1', 'pending']);

  await s.saveMyProfile('t', 'neuf', profileBody);
  assert.strictEqual(repo.calls.at(-1)[0], 'createProvider');
});

test("un profil publié garde son statut quand on le modifie", async () => {
  const repo = fakeRepository({ providers: { u1: provider({ id: 'u1', status: 'published' }) } });
  await createServicesService(repo).saveMyProfile('t', 'u1', profileBody);
  assert.deepStrictEqual(repo.calls.at(-1), ['updateProvider', 'u1', 'published']);
});

test('réservation : refusée chez soi, chez un profil non publié ou pour une prestation archivée', async () => {
  const base = { providerId: 'p1', serviceId: 's1', animalName: 'Milo', dateTime: future() };
  const user = { uid: 'client' };

  const ownRepo = fakeRepository({ providers: { p1: provider() }, services: { 'p1/s1': service() } });
  await assert.rejects(createServicesService(ownRepo).createBooking('t', { uid: 'p1' }, base), { status: 400 });

  const unpublished = fakeRepository({ providers: { p1: provider({ status: 'pending' }) }, services: { 'p1/s1': service() } });
  await assert.rejects(createServicesService(unpublished).createBooking('t', user, base), { status: 409 });

  const archived = fakeRepository({ providers: { p1: provider() }, services: { 'p1/s1': service({ status: 'archived' }) } });
  await assert.rejects(createServicesService(archived).createBooking('t', user, base), { status: 409 });

  const missing = fakeRepository({ providers: { p1: provider() } });
  await assert.rejects(createServicesService(missing).createBooking('t', user, base), { status: 404 });
});

test('réservation valide : en attente, avec le nom du client et de la prestation', async () => {
  const repo = fakeRepository({
    providers: { p1: provider() },
    services: { 'p1/s1': service() },
    users: { client: { fullName: 'Lina' } },
  });
  const booking = await createServicesService(repo).createBooking('t', { uid: 'client' }, {
    providerId: 'p1', serviceId: 's1', animalName: 'Milo', dateTime: future(),
  });

  assert.strictEqual(booking.status, 'pending');
  assert.strictEqual(booking.clientName, 'Lina');
  assert.strictEqual(booking.serviceName, 'Consultation');
});

test('réponse à une demande : le prestataire confirme, le client annule, une seule réponse', async () => {
  const bookings = { b1: { id: 'b1', providerUid: 'pro', clientUid: 'cli', status: 'pending' } };
  const repo = fakeRepository({ bookings });
  const s = createServicesService(repo);

  await assert.rejects(s.answerBooking('t', { uid: 'cli' }, 'b1', { status: 'confirmed' }), { status: 403 });
  await assert.rejects(s.answerBooking('t', { uid: 'pro' }, 'b1', { status: 'cancelled' }), { status: 403 });
  await assert.rejects(s.answerBooking('t', { uid: 'autre' }, 'b1', { status: 'confirmed' }), { status: 403 });
  await assert.rejects(s.answerBooking('t', { uid: 'pro' }, 'inconnue', { status: 'confirmed' }), { status: 404 });
  await assert.rejects(s.answerBooking('t', { uid: 'pro' }, 'b1', { status: 'zzz' }), { status: 400 });

  const confirmed = await s.answerBooking('t', { uid: 'pro' }, 'b1', { status: 'confirmed' });
  assert.strictEqual(confirmed.status, 'confirmed');
  await assert.rejects(s.answerBooking('t', { uid: 'pro' }, 'b1', { status: 'declined' }), { status: 409 });
});

test("catégories : les six par défaut si la base est vide, une nouvelle passe avant « Autres »", async () => {
  const empty = createServicesService(fakeRepository({ categories: [] }));
  assert.strictEqual((await empty.listCategories('t')).length, 6);

  const stored = [{ id: 'a', name: 'Vétérinaires', order: 1 }, { id: 'b', name: 'Toiletteurs', order: 2 }, { id: 'z', name: 'Autres', order: 99 }];
  const repo = fakeRepository({ categories: stored });
  await createServicesService(repo).addCategory('t', { name: 'Éducateurs', icon: 'education' });
  assert.deepStrictEqual(repo.calls.at(-1), ['createCategory', { name: 'Éducateurs', icon: 'education' }, 3]);
});
