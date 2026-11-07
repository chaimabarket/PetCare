// Tests du service Santé avec un faux dépôt en mémoire : aucune connexion à Firestore.

const test = require('node:test');
const assert = require('node:assert');

const { createHealthService, invalidateSummary } = require('../src/health/service');

function fakeRepository({ pets = {}, treatments = {}, entries = {} } = {}) {
  const calls = [];
  return {
    calls,
    getPet: async (_t, id) => pets[id] ?? null,
    listPetsByOwner: async (_t, uid) => {
      calls.push(['listPetsByOwner', uid]);
      return Object.values(pets).filter((p) => p.ownerId === uid);
    },
    listEntries: async (_t, petId) => entries[petId] ?? [],
    listTreatments: async (_t, petId) => Object.values(treatments).filter((t) => t.petId === petId),
    getTreatment: async (_t, _petId, id) => treatments[id] ?? null,
    createEntry: async (_t, petId, args) => {
      calls.push(['createEntry', petId, args]);
      return 'e1';
    },
    getEntry: async () => ({ id: 'e1' }),
    markReminderDone: async (_t, petId, id) => calls.push(['markReminderDone', petId, id]),
    addDose: async (_t, petId, id, at) => calls.push(['addDose', id, at.toISOString()]),
    stopTreatment: async (_t, petId, id, reason) => calls.push(['stopTreatment', id, reason]),
  };
}

const user = { uid: 'u1' };
const pet = (over = {}) => ({ id: 'p1', ownerId: 'u1', name: 'Milo', species: 'cat', status: 'active', ...over });
const hour = (n) => new Date(Date.now() + n * 3600000).toISOString();
const treatment = (over = {}) => ({
  id: 't1', petId: 'p1', startDate: hour(-48), endDate: hour(48), doseTimes: ['08:00'], doses: [], stoppedAt: null, ...over,
});

test("carnet : l'animal d'un autre est refusé, un animal archivé ne se modifie plus", async () => {
  const s = createHealthService(fakeRepository({ pets: { p1: pet({ ownerId: 'autre' }), p2: pet({ id: 'p2', status: 'archived' }) } }));
  const entry = { type: 'note', title: 'Test', date: hour(-1) };

  await assert.rejects(s.addEntry('t', user, 'p1', entry), { status: 403 });
  await assert.rejects(s.addEntry('t', user, 'p2', entry), { status: 409 });
  await assert.rejects(s.addEntry('t', user, 'inconnu', entry), { status: 404 });
  await assert.rejects(s.markReminderDone('t', user, 'p2', 'e1'), { status: 409 });
});

test('carnet : un soin valide est enregistré avec le propriétaire et sans rappel fait', async () => {
  const repo = fakeRepository({ pets: { p1: pet() } });
  await createHealthService(repo).addEntry('t', user, 'p1', { type: 'note', title: 'Croquettes', date: hour(-1) });

  const [, petId, args] = repo.calls.find((c) => c[0] === 'createEntry');
  assert.strictEqual(petId, 'p1');
  assert.strictEqual(args.data.ownerId, 'u1');
  assert.strictEqual(args.data.reminderDone, false);
});

test('traitement : une prise sur un traitement arrêté ou déjà notée est refusée', async () => {
  const stopped = createHealthService(fakeRepository({ pets: { p1: pet() }, treatments: { t1: treatment({ stoppedAt: hour(-1) }) } }));
  await assert.rejects(stopped.addDose('t', user, 'p1', 't1', {}), { status: 409 });

  const missing = createHealthService(fakeRepository({ pets: { p1: pet() } }));
  await assert.rejects(missing.addDose('t', user, 'p1', 'inconnu', {}), { status: 404 });
});

test('traitement : arrêt refusé si déjà arrêté ou terminé depuis plus d\'un jour', async () => {
  const body = { reason: 'Effets secondaires' };
  const stopped = createHealthService(fakeRepository({ pets: { p1: pet() }, treatments: { t1: treatment({ stoppedAt: hour(-1) }) } }));
  await assert.rejects(stopped.stopTreatment('t', user, 'p1', 't1', body), { status: 409 });

  const finished = createHealthService(fakeRepository({ pets: { p1: pet() }, treatments: { t1: treatment({ endDate: hour(-72) }) } }));
  await assert.rejects(finished.stopTreatment('t', user, 'p1', 't1', body), { status: 409 });
});

test('synthèse : gardée 30 s par utilisateur, vidée par une écriture', async () => {
  invalidateSummary('u1');
  const repo = fakeRepository({ pets: { p1: pet() } });
  const s = createHealthService(repo);

  await s.summary('t', 'u1');
  await s.summary('t', 'u1');
  assert.strictEqual(repo.calls.filter((c) => c[0] === 'listPetsByOwner').length, 1, 'la deuxième lecture vient du cache');

  await s.markReminderDone('t', user, 'p1', 'e1');
  await s.summary('t', 'u1');
  assert.strictEqual(repo.calls.filter((c) => c[0] === 'listPetsByOwner').length, 2, 'une écriture vide le cache');
});
