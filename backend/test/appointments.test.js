const test = require('node:test');
const assert = require('node:assert');

const R = require('../src/appointments/rules');
const V = require('../src/appointments/validation');
const { when } = require('../src/appointments/routes');
const { createApp } = require('../src/app');

// ---------------------------------------------------------------------------
// Règles : mêmes cas que test/appointment_rules_test.dart côté Flutter.
// ---------------------------------------------------------------------------

const now = new Date('2026-11-12T10:00:00Z');
const minutes = (n) => n * 60000;
const appointment = ({ status, start, duration = 45, providerId = null }) => ({
  id: 'a1', ownerId: 'owner', petName: 'Milo', title: 'Toilettage', status, providerId,
  startsAt: new Date(start).toISOString(),
  endsAt: new Date(new Date(start).getTime() + minutes(duration)).toISOString(),
});
const inDays = (n) => now.getTime() + n * 86400000;

test('une réservation en attente et future peut être confirmée', () => {
  assert.ok(R.canConfirm(appointment({ status: 'planned', start: inDays(1), providerId: 'p' }), now));
});

test('un rendez-vous confirmé ne se confirme pas une seconde fois', () => {
  assert.ok(!R.canConfirm(appointment({ status: 'confirmed', start: inDays(1) }), now));
});

test('report et annulation sont refusés après le début', () => {
  const a = appointment({ status: 'confirmed', start: now.getTime() - minutes(10) });
  assert.ok(!R.canReschedule(a, now));
  assert.ok(!R.canCancel(a, now));
});

test('« Terminé » seulement depuis Confirmé et après la fin', () => {
  const past = now.getTime() - minutes(120);
  assert.ok(R.canComplete(appointment({ status: 'confirmed', start: past }), now));
  assert.ok(!R.canComplete(appointment({ status: 'planned', start: past }), now));
  assert.ok(!R.canComplete(appointment({ status: 'confirmed', start: now.getTime() - minutes(10) }), now));
});

test('annulé et terminé sont définitifs', () => {
  for (const status of ['cancelled', 'completed']) {
    const a = appointment({ status, start: inDays(2) });
    assert.ok(!R.canReschedule(a, now) && !R.canCancel(a, now) && !R.canConfirm(a, now));
  }
});

test('chevauchement : début pendant le rendez-vous, mais pas à la fin exacte', () => {
  const a = appointment({ status: 'confirmed', start: '2026-11-12T15:00:00Z' });
  assert.ok(R.overlaps(a, '2026-11-12T15:30:00Z', '2026-11-12T16:15:00Z'));
  assert.ok(!R.overlaps(a, '2026-11-12T15:45:00Z', '2026-11-12T16:30:00Z'));
});

test('conflit : même animal (sans tenir compte des majuscules), rendez-vous actif seulement', () => {
  const list = [
    appointment({ status: 'cancelled', start: '2026-11-12T15:00:00Z' }),
    { ...appointment({ status: 'confirmed', start: '2026-11-12T15:00:00Z' }), id: 'a2' },
  ];
  const slot = { start: '2026-11-12T15:15:00Z', end: '2026-11-12T15:30:00Z' };
  assert.strictEqual(R.findPetConflict(list, { ...slot, petName: ' milo ' }).id, 'a2');
  assert.strictEqual(R.findPetConflict(list, { ...slot, petName: 'Nala' }), null);
  assert.strictEqual(R.findPetConflict(list, { ...slot, petName: 'Milo', ignoreId: 'a2' }), null);
});

test('validation : rendez-vous personnel et réservation', () => {
  const body = {
    petName: 'Milo', title: 'Promenade', type: 'garde', startsAt: new Date(inDays(1)).toISOString(), durationMinutes: 60,
  };
  const personal = V.appointmentFields(body, now);
  assert.strictEqual(personal.providerId, null);
  assert.strictEqual(personal.endsAt - personal.startsAt, minutes(60));
  assert.strictEqual(personal.reminderMinutes, 1440);

  const booking = V.appointmentFields({ ...body, providerId: 'p1', providerName: 'Toilettage Lina', serviceId: 's1', price: 45 }, now);
  assert.strictEqual(booking.providerId, 'p1');
  assert.strictEqual(booking.price, 45);

  assert.throws(() => V.appointmentFields({ ...body, title: '  ' }, now), /intitulé est obligatoire/);
  assert.throws(() => V.appointmentFields({ ...body, type: 'chirurgie' }, now), /type est invalide/);
  assert.throws(() => V.appointmentFields({ ...body, startsAt: new Date(inDays(-1)).toISOString() }, now), /dans le futur/);
});

test('date des notifications à l\'heure de Tunis', () => {
  assert.strictEqual(when('2026-11-12T09:30:00Z'), '12 nov. à 10:30');
});

// ---------------------------------------------------------------------------
// Routes : le serveur tourne pour de vrai ; Firebase Auth et Firestore sont simulés en mémoire.
// ---------------------------------------------------------------------------

/** Faux Firestore (API REST) : documents, requêtes simples, commit avec préconditions. */
function fakeFirebase() {
  const docs = new Map(); // chemin -> { fields, updateTime }
  let clock = 0;
  const stamp = () => new Date(Date.UTC(2026, 0, 1, 0, 0, clock += 1)).toISOString();
  const json = (status, body) => new Response(JSON.stringify(body), { status, headers: { 'Content-Type': 'application/json' } });
  const pathOf = (name) => name.split('/documents/')[1];
  const asDoc = (path) => ({ name: `projects/p/databases/(default)/documents/${path}`, ...docs.get(path) });

  function commitWrites(writes) {
    for (const w of writes) {
      const path = pathOf(w.update ? w.update.name : w.delete);
      const existing = docs.get(path);
      const pre = w.currentDocument;
      if (pre?.exists === true && !existing) return json(404, { error: { status: 'NOT_FOUND' } });
      if (pre?.exists === false && existing) return json(409, { error: { status: 'ALREADY_EXISTS' } });
      if (pre?.updateTime && existing?.updateTime !== pre.updateTime) {
        return json(400, { error: { status: 'FAILED_PRECONDITION' } });
      }
    }
    for (const w of writes) {
      if (w.delete) { docs.delete(pathOf(w.delete)); continue; }
      const path = pathOf(w.update.name);
      const fields = w.updateMask ? { ...(docs.get(path)?.fields || {}) } : {};
      for (const key of w.updateMask ? w.updateMask.fieldPaths : Object.keys(w.update.fields)) {
        fields[key] = w.update.fields[key];
      }
      for (const t of w.updateTransforms || []) fields[t.fieldPath] = { timestampValue: new Date().toISOString() };
      docs.set(path, { fields, updateTime: stamp() });
    }
    return json(200, {});
  }

  function runQuery(parent, { structuredQuery: q }) {
    const collection = q.from[0].collectionId;
    const filters = !q.where ? [] : q.where.compositeFilter ? q.where.compositeFilter.filters : [q.where];
    const prefix = parent ? `${parent}/` : '';
    const rows = [...docs.keys()]
      .filter((p) => p.startsWith(`${prefix}${collection}/`) && p.split('/').length === prefix.split('/').length + 1)
      .filter((p) => filters.every((f) => JSON.stringify(docs.get(p).fields[f.fieldFilter.field.fieldPath])
        === JSON.stringify(f.fieldFilter.value)))
      .map((p) => ({ document: asDoc(p) }));
    return json(200, rows.length ? rows : [{}]);
  }

  const realFetch = global.fetch;
  global.fetch = async (url, options = {}) => {
    const u = String(url);
    if (u.startsWith('http://127.0.0.1')) return realFetch(url, options);
    if (u.includes('accounts:lookup')) {
      const { idToken } = JSON.parse(options.body);
      return json(200, { users: [{ localId: idToken, email: `${idToken}@test.tn` }] });
    }
    const target = u.split('/documents')[1] || '';
    if (u.endsWith(':commit')) return commitWrites(JSON.parse(options.body).writes);
    if (u.endsWith(':runQuery')) {
      return runQuery(target.replace(/^\//, '').replace(/:runQuery$/, '') || null, JSON.parse(options.body));
    }
    const path = target.replace(/^\//, '');
    return docs.has(path) ? json(200, asDoc(path)) : json(404, { error: { status: 'NOT_FOUND' } });
  };

  return { docs, restore: () => { global.fetch = realFetch; } };
}

test('routes : création, conflit, report, version périmée, annulation, rappels', async (t) => {
  const firebase = fakeFirebase();
  const server = createApp().listen(0);
  t.after(() => { server.close(); firebase.restore(); });
  const base = `http://127.0.0.1:${server.address().port}`;

  const call = async (method, path, body, user = 'yasmine') => {
    const response = await fetch(`${base}${path}`, {
      method,
      headers: { Authorization: `Bearer ${user}`, 'Content-Type': 'application/json' },
      body: body ? JSON.stringify(body) : undefined,
    });
    return { status: response.status, body: response.status === 204 ? null : await response.json() };
  };

  const tomorrow = new Date(Date.now() + 86400000);
  tomorrow.setUTCHours(9, 30, 0, 0);
  const slot = (offsetMinutes) => new Date(tomorrow.getTime() + minutes(offsetMinutes)).toISOString();

  // Création : un rendez-vous personnel démarre « Confirmé », version 1, historique « create ».
  const created = await call('POST', '/api/appointments', {
    petName: 'Milo', title: 'Promenade au parc', type: 'garde', startsAt: slot(0), durationMinutes: 60,
    place: 'exterieur', location: 'Parc du Belvédère',
  });
  assert.strictEqual(created.status, 201);
  assert.strictEqual(created.body.status, 'confirmed');
  assert.strictEqual(created.body.version, 1);
  assert.strictEqual(created.body.changes[0].action, 'create');
  const id = created.body.id;

  // Les dates sont bien enregistrées comme des timestamps Firestore (lues par Flutter en Timestamp).
  assert.ok('timestampValue' in firebase.docs.get(`appointments/${id}`).fields.startsAt);

  // Même animal, créneau qui chevauche : refusé.
  const clash = await call('POST', '/api/appointments', {
    petName: 'milo', title: 'Toilettage', type: 'soin', startsAt: slot(30), durationMinutes: 30,
  });
  assert.strictEqual(clash.status, 409);
  assert.match(clash.body.error, /a déjà « Promenade au parc »/);

  // L'agenda renvoie le rendez-vous.
  const agenda = await call('GET', '/api/appointments');
  assert.deepStrictEqual(agenda.body.map((a) => a.id), [id]);

  // Report : le motif est obligatoire.
  const noReason = await call('POST', `/api/appointments/${id}/reschedule`, { version: 1, startsAt: slot(180) });
  assert.strictEqual(noReason.status, 400);

  // Report : nouvel horaire, même durée, version 2, ancien horaire dans l'historique.
  const moved = await call('POST', `/api/appointments/${id}/reschedule`, {
    version: 1, startsAt: slot(180), reason: 'Pluie prévue le matin',
  });
  assert.strictEqual(moved.status, 200);
  assert.strictEqual(moved.body.version, 2);
  assert.strictEqual(moved.body.status, 'confirmed');
  assert.strictEqual(new Date(moved.body.endsAt) - new Date(moved.body.startsAt), minutes(60));
  const last = moved.body.changes.at(-1);
  assert.strictEqual(last.action, 'reschedule');
  assert.strictEqual(new Date(last.oldStart).toISOString(), slot(0));
  // L'ancienne ligne d'historique reste une date après réécriture.
  assert.ok('timestampValue' in firebase.docs.get(`appointments/${id}`).fields.changes.arrayValue.values[0].mapValue.fields.at);

  // Version périmée (écran pas encore rafraîchi) : refusé plutôt que d'écraser.
  const stale = await call('POST', `/api/appointments/${id}/cancel`, { version: 1 });
  assert.strictEqual(stale.status, 409);
  assert.match(stale.body.error, /modifié par quelqu'un d'autre/);

  // Seul le prestataire confirme ; ici il n'y en a pas.
  assert.strictEqual((await call('POST', `/api/appointments/${id}/confirm`, { version: 2 })).status, 403);

  // Terminer avant la fin : refusé.
  assert.strictEqual((await call('POST', `/api/appointments/${id}/complete`, { version: 2 })).status, 409);

  // Annulation : définitive.
  const cancelled = await call('POST', `/api/appointments/${id}/cancel`, { version: 2, reason: 'Milo est malade' });
  assert.strictEqual(cancelled.body.status, 'cancelled');
  assert.strictEqual(cancelled.body.cancelReason, 'Milo est malade');
  assert.strictEqual((await call('POST', `/api/appointments/${id}/cancel`, { version: 3 })).status, 409);

  // Un rendez-vous annulé ne bloque plus le créneau.
  const again = await call('POST', '/api/appointments', {
    petName: 'Milo', title: 'Toilettage', type: 'soin', startsAt: slot(30), durationMinutes: 30,
  });
  assert.strictEqual(again.status, 201);

  // Réservation : « En attente », le prestataire reçoit une notification et peut confirmer.
  const booking = await call('POST', '/api/appointments', {
    petName: 'Nala', title: 'Toilettage complet', type: 'toilettage', startsAt: slot(600), durationMinutes: 45,
    providerId: 'lina', providerName: 'Salon Lina', serviceId: 'svc1', price: 45,
  });
  assert.strictEqual(booking.body.status, 'planned');
  assert.ok([...firebase.docs.keys()].some((p) => p.startsWith('users/lina/notifications/')));
  const providerAgenda = await call('GET', '/api/appointments', null, 'lina');
  assert.deepStrictEqual(providerAgenda.body.map((a) => a.id), [booking.body.id]);
  const confirmed = await call('POST', `/api/appointments/${booking.body.id}/confirm`, { version: 1 }, 'lina');
  assert.strictEqual(confirmed.body.status, 'confirmed');

  // Rappels de soins : création, « Fait », suppression.
  const reminder = await call('POST', '/api/reminders', {
    petName: 'Milo', title: 'Vermifuge', category: 'medicament', dueAt: slot(-600), detail: '1 comprimé',
  });
  assert.strictEqual(reminder.status, 201);
  assert.strictEqual(reminder.body.done, false);
  const done = await call('PATCH', `/api/reminders/${reminder.body.id}`, { done: true });
  assert.strictEqual(done.body.done, true);
  assert.ok(done.body.doneAt);
  assert.strictEqual((await call('GET', '/api/reminders')).body.length, 1);
  assert.strictEqual((await call('DELETE', `/api/reminders/${reminder.body.id}`)).status, 204);
  assert.strictEqual((await call('GET', '/api/reminders')).body.length, 0);

  // Sans jeton : 401.
  const anonymous = await fetch(`${base}/api/appointments`);
  assert.strictEqual(anonymous.status, 401);
});
