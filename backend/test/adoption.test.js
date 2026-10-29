const test = require('node:test');
const assert = require('node:assert');

const { computeCompatibility, WEIGHTS } = require('../src/adoption/compatibility');
const { parseFilters, matches, ageGroup, ageInMonths } = require('../src/adoption/filters');
const { listingFields, applicationAnswers, photos } = require('../src/adoption/validation');

// Mêmes cas que test/adoption_compatibility_test.dart : le score doit être identique côté Flutter.
const listing = (over = {}) => ({
  name: 'Nala', species: 'chat', city: 'Tunis', breed: 'Européen', publisherName: 'Refuge Les Amis',
  goodWithKids: true, goodWithCats: true, goodWithDogs: false, needsGarden: false,
  energy: 'faible', okAloneHours: 6, badges: ['calme'], status: 'disponible', sex: 'femelle', size: 'moyen',
  birthDate: new Date(Date.now() - 800 * 86400000).toISOString(), createdAt: new Date().toISOString(),
  ...over,
});

const answers = (over = {}) => ({
  hasGarden: false, tenure: 'proprietaire', landlordAgrees: false, kids: 0, cats: 0, dogs: 0,
  allergies: false, hoursAlone: 4, lifestyle: 'calme', experience: 'familier', ...over,
});

test('foyer idéal : 100 %', () => {
  const result = computeCompatibility(listing(), answers());
  assert.strictEqual(result.score, 100);
  assert.ok(result.points.every((p) => p.ok));
});

test('chaque incompatibilité retire ses points', () => {
  const result = computeCompatibility(
    listing({ goodWithKids: false, needsGarden: true, energy: 'eleve', okAloneHours: 2 }),
    answers({ kids: 1, hasGarden: false, lifestyle: 'calme', hoursAlone: 8 }),
  );
  assert.strictEqual(result.score, 100 - WEIGHTS.noGarden - WEIGHTS.kids - WEIGHTS.energyMismatch - WEIGHTS.tooLongAlone);
  assert.strictEqual(result.points.filter((p) => !p.ok).length, 4);
});

test('locataire sans accord, allergies et première fois', () => {
  const result = computeCompatibility(listing(), answers({
    tenure: 'locataire', landlordAgrees: false, allergies: true, experience: 'premiere_fois',
  }));
  assert.strictEqual(result.score, 100 - WEIGHTS.noLandlordAgreement - WEIGHTS.allergies - WEIGHTS.firstTime);
});

test('le score ne descend pas sous 0', () => {
  const result = computeCompatibility(
    listing({ goodWithKids: false, goodWithCats: false, goodWithDogs: false, needsGarden: true, energy: 'eleve', okAloneHours: 1 }),
    answers({ kids: 1, cats: 1, dogs: 1, tenure: 'locataire', allergies: true, hoursAlone: 9, experience: 'premiere_fois' }),
  );
  assert.strictEqual(result.score, 0);
});

test('filtres du fil : espèce, âge, recherche sans accents', () => {
  assert.ok(matches(listing(), parseFilters({ species: 'chat,chien' })));
  assert.ok(!matches(listing(), parseFilters({ species: 'chien' })));
  assert.ok(matches(listing(), parseFilters({ q: 'EUROPEEN' })));
  assert.ok(!matches(listing(), parseFilters({ badges: 'calme,joueur' })));
  assert.strictEqual(ageGroup(ageInMonths(listing().birthDate)), 'young');
});

test("annonce « Adopte-moi » : plus de 30 jours en ligne", () => {
  const old = listing({ createdAt: new Date(Date.now() - 40 * 86400000).toISOString() });
  assert.ok(matches(old, parseFilters({ urgent: '1' })));
  assert.ok(!matches(listing(), parseFilters({ urgent: '1' })));
});

const draft = (over = {}) => ({
  name: 'Nala', species: 'chat', breed: '', sex: 'femelle', birthDate: '2024-01-01', size: 'petit',
  city: 'Tunis', title: 'Douce Nala', story: 'Une histoire', needs: '', conditions: 'Visite', badges: ['calme'],
  energy: 'faible', ...over,
});

test("annonce valide ; refus d'un badge ou d'une espèce inconnus", () => {
  assert.strictEqual(listingFields(draft()).name, 'Nala');
  assert.throws(() => listingFields(draft({ badges: ['inconnu'] })), { status: 400 });
  assert.throws(() => listingFields(draft({ species: 'dragon' })), { status: 400 });
  assert.throws(() => listingFields(draft({ name: ' ' })), { status: 400 });
  assert.throws(() => listingFields(draft({ birthDate: '2999-01-01' })), { status: 400 });
});

test("pas plus de 5 badges ni de 5 photos", () => {
  assert.throws(() => listingFields(draft({ badges: ['calme', 'joueur', 'timide', 'eduque', 'soins', 'interieur'] })), { status: 400 });
  assert.throws(() => photos(['QUJD', 'QUJD', 'QUJD', 'QUJD', 'QUJD', 'QUJD']), { status: 400 });
  assert.throws(() => photos(['pas du base64 !']), { status: 400 });
  assert.deepStrictEqual(photos(['QUJD']), ['QUJD']);
});

test("réponses : le propriétaire n'a pas besoin d'accord, les enfants vident leurs âges", () => {
  const result = applicationAnswers({
    housing: 'maison', tenure: 'proprietaire', landlordAgrees: true, kids: 0, kidsAges: ['0 - 5 ans'],
    lifestyle: 'calme', experience: 'familier', city: 'Tunis',
  });
  assert.strictEqual(result.landlordAgrees, false);
  assert.deepStrictEqual(result.kidsAges, []);
  assert.throws(() => applicationAnswers({ housing: 'chateau' }), { status: 400 });
});
