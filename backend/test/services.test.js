const test = require('node:test');
const assert = require('node:assert');

const V = require('../src/services/validation');

const provider = (over = {}) => ({
  name: 'Salon Amine', category: 'Toiletteurs', city: 'Tunis', description: 'Toilettage à domicile',
  phone: '+216 20 123 456', email: 'amine@exemple.com', ...over,
});

test('profil prestataire valide, champs facultatifs à null', () => {
  const result = V.providerFields(provider());
  assert.strictEqual(result.name, 'Salon Amine');
  assert.strictEqual(result.photoUrl, null);
  assert.strictEqual(result.address, null);
});

test('profil prestataire : nom, téléphone et e-mail contrôlés', () => {
  assert.throws(() => V.providerFields(provider({ name: 'x' })), { status: 400 });
  assert.throws(() => V.providerFields(provider({ phone: 'abc' })), { status: 400 });
  assert.throws(() => V.providerFields(provider({ email: 'pas-un-mail' })), { status: 400 });
  assert.throws(() => V.providerFields(provider({ city: '' })), { status: 400 });
});

test('prestation : durée entre 5 et 1440 min, prix positif, statut connu', () => {
  const ok = { name: 'Bain', category: 'Toiletteurs', durationMinutes: 45, price: 35.5, description: '' };
  assert.strictEqual(V.serviceFields(ok).status, 'published');
  assert.throws(() => V.serviceFields({ ...ok, durationMinutes: 2 }), { status: 400 });
  assert.throws(() => V.serviceFields({ ...ok, durationMinutes: 2000 }), { status: 400 });
  assert.throws(() => V.serviceFields({ ...ok, price: -1 }), { status: 400 });
  assert.throws(() => V.serviceFields({ ...ok, status: 'supprime' }), { status: 400 });
});

test('disponibilité : plages HH:MM avec début avant la fin', () => {
  const ok = V.availabilityFields({ enabled: true, ranges: [{ start: '09:00', end: '12:00' }, { start: '14:00', end: '17:30' }] });
  assert.strictEqual(ok.ranges.length, 2);
  assert.strictEqual(V.availabilityFields({}).enabled, false);
  assert.throws(() => V.availabilityFields({ ranges: [{ start: '12:00', end: '09:00' }] }), { status: 400 });
  assert.throws(() => V.availabilityFields({ ranges: [{ start: '9h', end: '12:00' }] }), { status: 400 });
});

test('jour de la semaine entre 1 et 7', () => {
  assert.strictEqual(V.weekday('3'), 3);
  assert.throws(() => V.weekday('0'), { status: 400 });
  assert.throws(() => V.weekday('8'), { status: 400 });
});

test('réservation : date à venir et champs obligatoires', () => {
  const future = new Date(Date.now() + 86400000).toISOString();
  const ok = V.bookingFields({ providerId: 'p1', serviceId: 's1', animalName: 'Milo', dateTime: future });
  assert.strictEqual(ok.notes, '');
  assert.throws(() => V.bookingFields({ providerId: 'p1', serviceId: 's1', animalName: 'Milo', dateTime: '2020-01-01T10:00:00Z' }), { status: 400 });
  assert.throws(() => V.bookingFields({ providerId: 'p1', serviceId: 's1', dateTime: future }), { status: 400 });
});

test('statuts acceptés', () => {
  assert.strictEqual(V.oneOf('published', V.PROVIDER_STATUSES, 'Le statut'), 'published');
  assert.throws(() => V.oneOf('actif', V.PROVIDER_STATUSES, 'Le statut'), { status: 400 });
  assert.ok(V.BOOKING_STATUSES.includes('cancelled'));
});

const { categoryFields, DEFAULT_CATEGORIES } = require('../src/services/categories');

test('catégorie : nom de 2 à 40 caractères et icône connue', () => {
  assert.deepStrictEqual(categoryFields({ name: ' Pharmacies ', icon: 'pharmacie' }), { name: 'Pharmacies', icon: 'pharmacie' });
  assert.strictEqual(categoryFields({ name: 'Éducateurs' }).icon, 'autre');
  assert.throws(() => categoryFields({ name: 'x' }), { status: 400 });
  assert.throws(() => categoryFields({ name: 'Ok ok', icon: 'inconnue' }), { status: 400 });
});

test('les catégories par défaut sont les six historiques', () => {
  assert.deepStrictEqual(DEFAULT_CATEGORIES.map((c) => c.name), ['Vétérinaires', 'Toiletteurs', 'Promeneurs', 'Pensions', 'Boutiques', 'Autres']);
});
