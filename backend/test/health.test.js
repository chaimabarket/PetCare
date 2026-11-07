const test = require('node:test');
const assert = require('node:assert');

const { createApp } = require('../src/app');
const {
  entryFields, treatmentFields, attachments, doseTime, stopReason,
} = require('../src/health/validation');
const { petSummary, invalidateSummary } = require('../src/health/routes');

const UID = 'user-1';
const DAY = 86400000;
const realFetch = globalThis.fetch;

const iso = (offsetDays) => new Date(Date.now() + offsetDays * DAY).toISOString();
const refused = (fn, status = 400) => assert.throws(fn, (e) => e.status === status);
const b64 = (text) => Buffer.from(text).toString('base64');

// ---------------------------------------------------------------- Validation

test('vaccin : nom et prochain rappel obligatoires, rappel après le vaccin', () => {
  const base = { type: 'vaccin', title: 'Rage', date: iso(-1), vaccineName: 'Rabisin', nextReminderAt: iso(364) };
  assert.strictEqual(entryFields(base).vaccineName, 'Rabisin');
  refused(() => entryFields({ ...base, vaccineName: '' }));
  refused(() => entryFields({ ...base, nextReminderAt: undefined }));
  refused(() => entryFields({ ...base, nextReminderAt: iso(-2) }));
});

test('visite : le prochain contrôle est gardé ; les champs du vaccin sont ignorés', () => {
  const visit = entryFields({
    type: 'visite', title: ' Bilan ', date: iso(-1), vaccineName: 'X', cost: '65.5', description: '', nextReminderAt: iso(30),
  });
  assert.strictEqual(visit.title, 'Bilan');
  assert.strictEqual(visit.vaccineName, null);
  assert.ok(visit.nextReminderAt instanceof Date);
  assert.strictEqual(visit.description, null);
  assert.strictEqual(visit.cost, 65.5);
  assert.strictEqual(entryFields({ type: 'allergie', title: 'Poulet', date: iso(0), nextReminderAt: iso(3) }).nextReminderAt, null);
  refused(() => entryFields({ type: 'visite', title: 'Bilan', date: iso(-1), nextReminderAt: iso(-3) }));
});

test('soin : date future et type inconnu refusés', () => {
  refused(() => entryFields({ type: 'visite', title: 'Bilan', date: iso(2) }));
  refused(() => entryFields({ type: 'chirurgie', title: 'Bilan', date: iso(-1) }));
});

test('pièces jointes : 3 au maximum, type autorisé, 900 Ko', () => {
  const pdf = { name: 'Ordonnance.pdf', mimeType: 'application/pdf', data: b64('%PDF-1.4') };
  assert.strictEqual(attachments([pdf])[0].bytes.toString(), '%PDF-1.4');
  refused(() => attachments([pdf, pdf, pdf, pdf]));
  refused(() => attachments([{ ...pdf, mimeType: 'text/html' }]));
  refused(() => attachments([{ ...pdf, data: 'pas du base64 !' }]));
  refused(() => attachments([{ ...pdf, data: Buffer.alloc(901 * 1024).toString('base64') }]));
});

test('traitement : dates, heures de prise et posologie', () => {
  const base = { name: 'Synulox', posology: '1 comprimé matin et soir', startDate: iso(0), endDate: iso(9) };
  const fields = treatmentFields({ ...base, doseTimes: ['20:00', '08:00', '08:00'], form: 'comprime' });
  assert.deepStrictEqual(fields.doseTimes, ['08:00', '20:00']);
  assert.strictEqual(fields.category, 'Autre');
  refused(() => treatmentFields({ ...base, endDate: iso(-1) }));
  refused(() => treatmentFields({ ...base, posology: ' ' }));
  refused(() => treatmentFields({ ...base, doseTimes: ['25:00'] }));
  refused(() => treatmentFields({ ...base, renewalAt: iso(5) }));
  refused(() => stopReason({}));
});

test('prise : pas dans le futur, pendant le traitement', () => {
  const treatment = { startDate: iso(-3), endDate: iso(3) };
  assert.ok(doseTime({}, treatment) instanceof Date);
  const yesterday = iso(-1);
  assert.strictEqual(doseTime({ at: yesterday }, treatment).toISOString(), yesterday);
  refused(() => doseTime({ at: iso(1) }, treatment));
  refused(() => doseTime({ at: iso(-10) }, treatment));
});

test('synthèse : vaccins en attente triés, dernière visite, allergies, traitements en cours seulement', () => {
  const summary = petSummary(
    { id: 'p1', name: 'Milo', species: 'dog', status: 'active', ownerId: UID },
    [
      { id: 'v1', type: 'vaccin', title: 'Rage', vaccineName: 'Rabisin', date: iso(-300), nextReminderAt: iso(65), reminderDone: false },
      { id: 'v2', type: 'vaccin', title: 'CHPPiL', date: iso(-360), nextReminderAt: iso(5), reminderDone: false },
      { id: 'v3', type: 'vaccin', title: 'Toux', date: iso(-400), nextReminderAt: iso(-30), reminderDone: true },
      { id: 'e1', type: 'examen', title: 'Prise de sang', date: iso(-10) },
      { id: 'e2', type: 'visite', title: 'Bilan', date: iso(-40) },
      { id: 'a1', type: 'allergie', title: 'Poulet', date: iso(-100) },
    ],
    [
      { id: 't1', name: 'Synulox', endDate: iso(3), stoppedAt: null, doseTimes: ['08:00'], doses: [], ownerId: UID },
      { id: 't2', name: 'Metrobactin', endDate: iso(3), stoppedAt: iso(-1), doses: [] },
      { id: 't3', name: 'Milbemax', endDate: iso(-20), stoppedAt: null, doses: [] },
    ],
  );
  assert.deepStrictEqual(summary.pendingVaccines.map((v) => v.id), ['v2', 'v1']);
  assert.strictEqual(summary.lastVisit.id, 'e1');
  assert.deepStrictEqual(summary.allergies, [{ id: 'a1', title: 'Poulet' }]);
  assert.deepStrictEqual(summary.activeTreatments.map((t) => t.id), ['t1']);
  assert.strictEqual(summary.activeTreatments[0].ownerId, undefined);
});

// -------------------------------------------- Routes, avec un faux Firestore

/** Stocke les documents en mémoire au format de l'API REST de Firestore et compte les requêtes. */
function fakeFirestore() {
  const docs = new Map();
  const commits = [];
  const counts = { queries: 0 };
  const relative = (name) => name.split('/documents/')[1];
  const asDocument = (path) => ({ document: { name: `x/documents/${path}`, fields: docs.get(path) } });

  const applyWrite = (write) => {
    if (write.delete) return docs.delete(relative(write.delete));
    const path = relative(write.update.name);
    if (write.currentDocument?.exists === false && docs.has(path)) return 'ALREADY_EXISTS';
    if (write.currentDocument?.exists === true && !docs.has(path)) return 'NOT_FOUND';
    const fields = { ...(write.updateMask ? docs.get(path) : {}), ...write.update.fields };
    (write.updateTransforms || []).forEach((t) => {
      if (t.appendMissingElements) {
        const current = fields[t.fieldPath]?.arrayValue?.values || [];
        fields[t.fieldPath] = { arrayValue: { values: [...current, ...t.appendMissingElements.values] } };
      } else {
        fields[t.fieldPath] = { timestampValue: '2026-01-10T10:00:00Z' };
      }
    });
    docs.set(path, fields);
    return null;
  };

  globalThis.fetch = async (url, options = {}) => {
    const target = String(url);
    if (target.startsWith('http://127.0.0.1')) return realFetch(url, options);
    if (target.includes('accounts:lookup')) {
      return Response.json({ users: [{ localId: UID, email: 'a@b.tn' }] });
    }
    if (target.endsWith(':commit')) {
      const { writes } = JSON.parse(options.body);
      commits.push(writes);
      const results = writes.map(applyWrite);
      if (results.includes('ALREADY_EXISTS')) return Response.json({ error: { status: 'ALREADY_EXISTS' } }, { status: 409 });
      if (results.includes('NOT_FOUND')) return Response.json({ error: { status: 'NOT_FOUND' } }, { status: 404 });
      return Response.json({});
    }
    if (target.endsWith(':runQuery')) {
      counts.queries += 1;
      const { structuredQuery: q } = JSON.parse(options.body);
      const parent = target.split('/documents')[1].replace(':runQuery', '').replace(/^\//, '');
      const prefix = parent ? `${parent}/${q.from[0].collectionId}/` : `${q.from[0].collectionId}/`;
      let paths = [...docs.keys()].filter((p) => p.startsWith(prefix) && !p.slice(prefix.length).includes('/'));
      const filter = q.where?.fieldFilter;
      if (filter) {
        const wanted = Object.values(filter.value)[0];
        paths = paths.filter((p) => Object.values(docs.get(p)[filter.field.fieldPath] || {})[0] === wanted);
      }
      const order = q.orderBy?.[0];
      if (order) {
        const key = (p) => String(Object.values(docs.get(p)[order.field.fieldPath])[0]);
        paths.sort((a, b) => key(a).localeCompare(key(b)));
        if (order.direction === 'DESCENDING') paths.reverse();
      }
      return Response.json(paths.map(asDocument));
    }
    const path = decodeURI(target.split('/documents/')[1]);
    if (!docs.has(path)) return Response.json({ error: {} }, { status: 404 });
    return Response.json({ name: `x/documents/${path}`, fields: docs.get(path) });
  };
  return { docs, commits, counts };
}

async function withServer(run) {
  invalidateSummary(UID);
  const store = fakeFirestore();
  const server = createApp().listen(0, '127.0.0.1');
  await new Promise((resolve) => { server.once('listening', resolve); });
  const base = `http://127.0.0.1:${server.address().port}/api`;
  const api = async (method, path, payload, { auth = true } = {}) => {
    const response = await realFetch(`${base}${path}`, {
      method,
      headers: { ...(auth ? { Authorization: 'Bearer jeton' } : {}), 'Content-Type': 'application/json' },
      body: payload === undefined ? undefined : JSON.stringify(payload),
    });
    const text = await response.text();
    return { status: response.status, json: text ? JSON.parse(text) : null };
  };
  try {
    await run(api, store);
  } finally {
    server.closeAllConnections();
    await new Promise((resolve) => { server.close(resolve); });
    globalThis.fetch = realFetch;
  }
}

/** Animal au format Firestore. */
const petDoc = (over = {}) => ({
  name: { stringValue: 'Milo' },
  species: { stringValue: 'dog' },
  ownerId: { stringValue: UID },
  status: { stringValue: 'active' },
  ...over,
});

const treatmentDoc = (over = {}) => ({
  name: { stringValue: 'Synulox' },
  startDate: { timestampValue: iso(-2) },
  endDate: { timestampValue: iso(5) },
  doseTimes: { arrayValue: { values: [{ stringValue: '08:00' }] } },
  doses: { arrayValue: { values: [] } },
  stoppedAt: { nullValue: null },
  ownerId: { stringValue: UID },
  ...over,
});

const vaccine = {
  type: 'vaccin', title: 'Rage', date: iso(0), vaccineName: 'Rabisin', nextReminderAt: iso(365),
};

test('sans jeton : 401', async () => {
  await withServer(async (api) => {
    assert.strictEqual((await api('GET', '/pets/p1/health/entries', undefined, { auth: false })).status, 401);
    assert.strictEqual((await api('GET', '/health/summary', undefined, { auth: false })).status, 401);
  });
});

test("ajout d'un soin : document et pièce jointe en octets dans le même commit", async () => {
  await withServer(async (api, { docs, commits }) => {
    docs.set('pets/p1', petDoc());
    const res = await api('POST', '/pets/p1/health/entries', {
      ...vaccine,
      attachments: [{ name: 'Vignette.jpg', mimeType: 'image/jpeg', data: b64('jpeg') }],
    });
    assert.strictEqual(res.status, 201);
    assert.strictEqual(res.json.vaccineName, 'Rabisin');
    assert.strictEqual(res.json.ownerId, UID);

    const [entry, file] = commits.at(-1);
    assert.match(entry.update.name, /pets\/p1\/healthEntries\/[^/]+$/);
    assert.strictEqual(entry.update.fields.reminderDone.booleanValue, false);
    assert.deepStrictEqual(entry.currentDocument, { exists: false });
    assert.match(file.update.name, /healthEntries\/[^/]+\/files\/0$/);
    assert.strictEqual(file.update.fields.data.bytesValue, b64('jpeg'));

    const list = await api('GET', '/pets/p1/health/entries');
    assert.strictEqual(list.json.length, 1);
    const id = list.json[0].id;
    assert.strictEqual((await api('GET', `/pets/p1/health/entries/${id}/files/0`)).json.data, b64('jpeg'));
  });
});

test('noter une prise : maintenant ou au créneau, une seule fois, refusée si arrêté', async () => {
  await withServer(async (api, { docs, commits }) => {
    docs.set('pets/p1', petDoc());
    docs.set('pets/p1/treatments/t1', treatmentDoc());

    assert.strictEqual((await api('POST', '/pets/p1/health/treatments/t1/doses')).status, 201);
    const [write] = commits.at(-1);
    assert.deepStrictEqual(write.updateMask, { fieldPaths: [] });
    assert.strictEqual(write.updateTransforms[0].fieldPath, 'doses');

    const slot = new Date(Date.now() - 3 * 3600000);
    slot.setSeconds(0, 0);
    const checked = await api('POST', '/pets/p1/health/treatments/t1/doses', { at: slot.toISOString() });
    assert.strictEqual(checked.status, 201);
    assert.strictEqual(checked.json.doses.length, 2);
    assert.strictEqual((await api('POST', '/pets/p1/health/treatments/t1/doses', { at: slot.toISOString() })).status, 409);
    assert.strictEqual((await api('POST', '/pets/p1/health/treatments/t1/doses', { at: iso(1) })).status, 400);

    docs.set('pets/p1/treatments/t1', treatmentDoc({ stoppedAt: { timestampValue: iso(-1) } }));
    assert.strictEqual((await api('POST', '/pets/p1/health/treatments/t1/doses')).status, 409);
  });
});

test("arrêt d'un traitement : heure du serveur et raison ; une seule fois", async () => {
  await withServer(async (api, { docs, commits }) => {
    docs.set('pets/p1', petDoc());
    docs.set('pets/p1/treatments/t1', treatmentDoc());
    const res = await api('POST', '/pets/p1/health/treatments/t1/stop', { reason: 'Intolérance' });
    assert.strictEqual(res.status, 200);
    const [write] = commits.at(-1);
    assert.deepStrictEqual(write.updateMask, { fieldPaths: ['stopReason'] });
    assert.deepStrictEqual(write.updateTransforms, [{ fieldPath: 'stoppedAt', setToServerValue: 'REQUEST_TIME' }]);
    assert.strictEqual((await api('POST', '/pets/p1/health/treatments/t1/stop', { reason: 'Encore' })).status, 409);
  });
});

test('animal archivé : le carnet se lit, mais toute écriture est refusée (409)', async () => {
  await withServer(async (api, { docs, commits }) => {
    docs.set('pets/p1', petDoc({ status: { stringValue: 'archived' } }));
    docs.set('pets/p1/treatments/t1', treatmentDoc());
    docs.set('pets/p1/healthEntries/e1', { type: { stringValue: 'vaccin' }, title: { stringValue: 'Rage' } });

    assert.strictEqual((await api('GET', '/pets/p1/health/entries')).status, 200);
    assert.strictEqual((await api('GET', '/pets/p1/health/treatments')).status, 200);
    const writes = [
      ['POST', '/pets/p1/health/entries', vaccine],
      ['PATCH', '/pets/p1/health/entries/e1/reminder-done'],
      ['DELETE', '/pets/p1/health/entries/e1'],
      ['POST', '/pets/p1/health/treatments', { name: 'X', posology: 'Y', startDate: iso(0), endDate: iso(2) }],
      ['POST', '/pets/p1/health/treatments/t1/doses'],
      ['POST', '/pets/p1/health/treatments/t1/stop', { reason: 'Fin' }],
    ];
    for (const [method, path, payload] of writes) {
      assert.strictEqual((await api(method, path, payload)).status, 409, `${method} ${path}`);
    }
    assert.strictEqual(commits.length, 0);
  });
});

test("l'animal d'un autre compte est refusé (403)", async () => {
  await withServer(async (api, { docs }) => {
    docs.set('pets/p2', petDoc({ ownerId: { stringValue: 'quelqu-un' } }));
    assert.strictEqual((await api('POST', '/pets/p2/health/entries', vaccine)).status, 403);
  });
});

test("synthèse : tous mes animaux en un appel, mise en cache, vidée après une écriture", async () => {
  await withServer(async (api, { docs, counts }) => {
    docs.set('pets/p1', petDoc());
    docs.set('pets/p2', petDoc({ name: { stringValue: 'Nala' }, species: { stringValue: 'cat' }, status: { stringValue: 'archived' } }));
    docs.set('pets/p3', petDoc({ name: { stringValue: 'Rex' }, ownerId: { stringValue: 'quelqu-un' } }));
    docs.set('pets/p1/treatments/t1', treatmentDoc());

    const first = await api('GET', '/health/summary');
    assert.strictEqual(first.status, 200);
    assert.deepStrictEqual(first.json.pets.map((p) => [p.name, p.status]), [['Milo', 'active'], ['Nala', 'archived']]);
    assert.strictEqual(first.json.pets[0].activeTreatments.length, 1);
    assert.strictEqual(counts.queries, 5); // pets + 2 requêtes par animal

    await api('GET', '/health/summary');
    assert.strictEqual(counts.queries, 5, 'deuxième appel servi par le cache');

    await api('POST', '/pets/p1/health/entries', vaccine);
    const after = await api('GET', '/health/summary');
    assert.strictEqual(counts.queries, 10, 'le cache est vidé par une écriture');
    assert.strictEqual(after.json.pets[0].pendingVaccines[0].vaccineName, 'Rabisin');
  });
});
