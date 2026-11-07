// Tests du service Adoption avec un faux dépôt et un faux notifieur : aucune connexion à Firestore.

const test = require('node:test');
const assert = require('node:assert');

const { ApiError } = require('../src/firestore');
const { createAdoptionService } = require('../src/adoption/service');

const PHOTO = 'QUJD'; // « ABC » en base64

function fakeRepository({ listings = {}, profiles = {}, openApplications = [], existingApplication = false, applications = [] } = {}) {
  const calls = [];
  return {
    calls,
    getUserProfile: async (_t, uid) => profiles[uid] ?? null,
    getListing: async (_t, id) => listings[id] ?? null,
    saveListing: async (_t, args) => {
      calls.push(['saveListing', args]);
      return args.listingId ?? 'nouvelle';
    },
    listOpenApplications: async () => openApplications,
    archiveListing: async (_t, id, refusals) => calls.push(['archiveListing', id, refusals]),
    createApplication: async (_t, listingId, uid, data) => {
      calls.push(['createApplication', listingId, uid, data]);
      if (existingApplication) throw new ApiError(409, 'existe');
    },
    findApplication: async () => ({ id: 'l1_cli', status: 'envoyee' }),
    listApplicationsByPublisher: async () => applications,
  };
}

const listing = (over = {}) => ({
  id: 'l1', name: 'Nala', publisherId: 'pub', publisherName: 'Refuge', species: 'chat', status: 'disponible',
  goodWithKids: true, goodWithCats: true, goodWithDogs: false, needsGarden: false, energy: 'faible', okAloneHours: 6,
  ...over,
});
const draft = (over = {}) => ({
  name: 'Nala', species: 'chat', breed: '', sex: 'femelle', birthDate: '2024-01-01', size: 'petit', city: 'Tunis',
  title: 'Douce Nala', story: 'Histoire', needs: '', conditions: 'Visite', badges: [], energy: 'faible', photos: [PHOTO], ...over,
});
const answers = { housing: 'maison', tenure: 'proprietaire', lifestyle: 'calme', experience: 'familier', hoursAlone: 4 };
const profiles = {
  pub: { id: 'pub', fullName: 'Refuge Les Amis', role: 'refuge' },
  cli: { id: 'cli', fullName: 'Lina', role: 'proprietaire' },
  pro: { id: 'pro', fullName: 'Salon', role: 'prestataire' },
};

function build(repoOptions) {
  const repo = fakeRepository({ profiles, ...repoOptions });
  const notices = [];
  const service = createAdoptionService(repo, async (_t, uid, notice) => notices.push([uid, notice]));
  return { repo, service, notices };
}

test('publier : un prestataire est refusé, une annonce publiée exige une photo', async () => {
  const { service } = build();
  await assert.rejects(service.createListing('t', { uid: 'pro' }, draft()), { status: 403 });
  await assert.rejects(service.createListing('t', { uid: 'pub' }, draft({ photos: [], publish: true })), { status: 400 });
});

test('publier : statut disponible ou brouillon, annonceur et refuge renseignés', async () => {
  const { repo, service } = build({ listings: { nouvelle: listing({ id: 'nouvelle' }) } });

  await service.createListing('t', { uid: 'pub' }, draft({ publish: true }));
  const published = repo.calls.at(-1)[1];
  assert.strictEqual(published.data.status, 'disponible');
  assert.strictEqual(published.data.publisherIsShelter, true);
  assert.strictEqual(published.creating, true);

  await service.createListing('t', { uid: 'pub' }, draft());
  assert.strictEqual(repo.calls.at(-1)[1].data.status, 'brouillon');
});

test("modifier : seul l'auteur le peut ; une annonce réservée garde son statut", async () => {
  const { repo, service } = build({ listings: { l1: listing({ status: 'reservee' }) } });

  await assert.rejects(service.updateListing('t', { uid: 'cli' }, 'l1', draft()), { status: 403 });
  await assert.rejects(service.updateListing('t', { uid: 'pub' }, 'inconnue', draft()), { status: 404 });

  await service.updateListing('t', { uid: 'pub' }, 'l1', draft({ publish: true }));
  const saved = repo.calls.at(-1)[1];
  assert.strictEqual(saved.data.status, 'reservee');
  assert.strictEqual(saved.creating, false);
});

test("modifier sans le champ photos : les photos existantes ne sont pas touchées", async () => {
  const { repo, service } = build({ listings: { l1: listing() } });
  const { photos, ...withoutPhotos } = draft();
  await service.updateListing('t', { uid: 'pub' }, 'l1', withoutPhotos);
  assert.strictEqual(repo.calls.at(-1)[1].photos, undefined);
});

test('archiver : impossible si réservée ; sinon refuse et prévient les candidats ouverts', async () => {
  const reserved = build({ listings: { l1: listing({ status: 'reservee' }) } });
  await assert.rejects(reserved.service.archiveListing('t', { uid: 'pub' }, 'l1'), { status: 409 });

  const { repo, service, notices } = build({
    listings: { l1: listing() },
    openApplications: [{ id: 'l1_a', applicantId: 'a' }, { id: 'l1_b', applicantId: 'b' }],
  });
  await assert.rejects(service.archiveListing('t', { uid: 'cli' }, 'l1'), { status: 403 });

  await service.archiveListing('t', { uid: 'pub' }, 'l1');
  const [, , refusals] = repo.calls.at(-1);
  assert.deepStrictEqual(refusals.map((r) => r.id), ['l1_a', 'l1_b']);
  assert.deepStrictEqual(notices.map((n) => n[0]), ['a', 'b']);
});

test('candidater : refus sur sa propre annonce, une annonce indisponible ou un doublon', async () => {
  const own = build({ listings: { l1: listing() } });
  await assert.rejects(own.service.apply('t', { uid: 'pub' }, 'l1', answers), { status: 400 });

  const adopted = build({ listings: { l1: listing({ status: 'adoptee' }) } });
  await assert.rejects(adopted.service.apply('t', { uid: 'cli' }, 'l1', answers), { status: 409 });

  const duplicate = build({ listings: { l1: listing() }, existingApplication: true });
  await assert.rejects(duplicate.service.apply('t', { uid: 'cli' }, 'l1', answers), { status: 409, message: /déjà envoyé/ });

  await assert.rejects(build({ listings: { l1: listing() } }).service.apply('t', { uid: 'cli' }, 'l1', { housing: 'x' }), { status: 400 });
});

test("candidater : le score est calculé par le serveur et l'annonceur est prévenu", async () => {
  const { repo, service, notices } = build({ listings: { l1: listing({ needsGarden: true }) } });
  await service.apply('t', { uid: 'cli' }, 'l1', { ...answers, hasGarden: false });

  const [, listingId, uid, data] = repo.calls.at(-1);
  assert.strictEqual(listingId, 'l1');
  assert.strictEqual(uid, 'cli');
  assert.strictEqual(data.score, 80); // 100 moins 20 : l'animal a besoin d'un extérieur
  assert.strictEqual(data.applicantName, 'Lina');
  assert.strictEqual(notices[0][0], 'pub');
  assert.strictEqual(notices[0][1].category, 'adoption');
});

test('candidatures reçues : le meilleur score en premier', async () => {
  const { service } = build({ applications: [{ id: 'a', score: 40 }, { id: 'b', score: 90 }, { id: 'c', score: 65 }] });
  assert.deepStrictEqual((await service.listReceivedApplications('t', 'pub')).map((a) => a.id), ['b', 'c', 'a']);
});
