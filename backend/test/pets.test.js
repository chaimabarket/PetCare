const test = require('node:test');
const assert = require('node:assert');

const { createApp } = require('../src/app');
const { petFields, petPatch, gallery, weightEntry } = require('../src/pets/validation');

const UID = 'user-1';
const realFetch = globalThis.fetch;

const body = (over = {}) => ({
  name: 'Milo', species: 'cat', sex: 'male', birthDate: '2023-03-01T23:00:00.000Z', ...over,
});

const weight = (over = {}) => ({
  date: '2026-01-10', measuredOn: '2026-01-09T23:00:00.000Z', weightKg: 5.5, ...over,
});

const refused = (fn, status = 400) => assert.throws(fn, (e) => e.status === status);

// ---------------------------------------------------------------- Validation

test('fiche : mêmes limites que firestore.rules', () => {
  assert.strictEqual(petFields(body({ name: '  Milo ' })).name, 'Milo');
  assert.strictEqual(petFields(body({ breed: '  ' })).breed, null);
  refused(() => petFields(body({ name: 'M' })));
  refused(() => petFields(body({ name: 'M'.repeat(81) })));
  refused(() => petFields(body({ species: 'chat' })));
  refused(() => petFields(body({ sex: 'femelle' })));
  refused(() => petFields(body({ chipNumber: '123' })));
  refused(() => petFields(body({ notes: 'n'.repeat(501) })));
  refused(() => petFields(body({ birthDate: new Date(Date.now() + 86400000).toISOString() })));
  assert.strictEqual(petFields(body({ chipNumber: '250269812345678' })).chipNumber, '250269812345678');
});

test('modification partielle : seuls les champs envoyés changent', () => {
  assert.deepStrictEqual(petPatch({ favorite: true }), { favorite: true });
  assert.deepStrictEqual(petPatch({ notes: '  ' }), { notes: null });
  refused(() => petPatch({}));
  refused(() => petPatch({ favorite: 'oui' }));
  refused(() => petPatch({ contacts: Array(6).fill({ name: 'A', phone: '1' }) }));
  refused(() => petPatch({ contacts: [{ name: '', phone: '1' }] }));
});

test('galerie : 5 photos et 750 Ko maximum', () => {
  const small = { data: Buffer.from('image').toString('base64') };
  assert.strictEqual(gallery([small, { id: 'a' }])[0].bytes.toString(), 'image');
  assert.deepStrictEqual(gallery([{ id: 'a' }]), [{ id: 'a' }]);
  refused(() => gallery(Array(6).fill(small)));
  refused(() => gallery([{ data: 'pas du base64 !' }]));
  refused(() => gallery([{ data: Buffer.alloc(750001).toString('base64') }]));
  assert.strictEqual(gallery([{ data: Buffer.alloc(750000).toString('base64') }])[0].bytes.length, 750000);
});

test('pesée : poids et date valides', () => {
  assert.strictEqual(weightEntry(weight()).id, '2026-01-10');
  refused(() => weightEntry(weight({ weightKg: 0 })));
  refused(() => weightEntry(weight({ weightKg: 501 })));
  refused(() => weightEntry(weight({ weightKg: '5' })));
  refused(() => weightEntry(weight({ date: '10/01/2026' })));
  refused(() => weightEntry(weight({ measuredOn: '2026-03-01T00:00:00.000Z' })));
  refused(() => weightEntry(weight({ measuredOn: new Date(Date.now() + 86400000).toISOString() })));
});

// -------------------------------------------- Routes, avec un faux Firestore

/** Stocke les documents en mémoire au format de l'API REST de Firestore. */
function fakeFirestore() {
  const docs = new Map();
  const commits = [];
  const relative = (name) => name.split('/documents/')[1];
  const asDocument = (path) => ({ document: { name: `x/documents/${path}`, fields: docs.get(path) } });

  const applyWrite = (write) => {
    if (write.delete) return docs.delete(relative(write.delete));
    const path = relative(write.update.name);
    if (write.currentDocument?.exists === false && docs.has(path)) return 'ALREADY_EXISTS';
    const fields = { ...(write.updateMask ? docs.get(path) : {}), ...write.update.fields };
    (write.updateTransforms || []).forEach((t) => { fields[t.fieldPath] = { timestampValue: '2026-01-10T10:00:00Z' }; });
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
      const failed = writes.map(applyWrite).includes('ALREADY_EXISTS');
      return failed
        ? Response.json({ error: { status: 'ALREADY_EXISTS' } }, { status: 409 })
        : Response.json({});
    }
    if (target.endsWith(':runQuery')) {
      const { structuredQuery: q } = JSON.parse(options.body);
      const parent = target.split('/documents')[1].replace(':runQuery', '').replace(/^\//, '');
      const prefix = parent ? `${parent}/${q.from[0].collectionId}/` : `${q.from[0].collectionId}/`;
      let paths = [...docs.keys()].filter((p) => p.startsWith(prefix) && !p.slice(prefix.length).includes('/'));
      const order = q.orderBy?.[0];
      if (order) {
        const key = (p) => Object.values(docs.get(p)[order.field.fieldPath])[0];
        paths.sort((a, b) => (Number(key(a)) || 0) - (Number(key(b)) || 0));
        if (order.direction === 'DESCENDING') paths.reverse();
      }
      if (q.limit) paths = paths.slice(0, q.limit);
      return Response.json(paths.map(asDocument));
    }
    const path = decodeURI(target.split('/documents/')[1]);
    if (!docs.has(path)) return Response.json({ error: {} }, { status: 404 });
    return Response.json({ name: `x/documents/${path}`, fields: docs.get(path) });
  };
  return { docs, commits };
}

async function withServer(run) {
  const store = fakeFirestore();
  const server = createApp().listen(0, '127.0.0.1');
  await new Promise((resolve) => { server.once('listening', resolve); });
  const base = `http://127.0.0.1:${server.address().port}/api/pets`;
  const api = async (method, path = '', payload) => {
    const response = await realFetch(`${base}${path}`, {
      method,
      headers: { Authorization: 'Bearer jeton', 'Content-Type': 'application/json' },
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

const image = (text) => Buffer.from(text).toString('base64');

test('sans jeton, les routes sont refusées', async () => {
  await withServer(async () => {
    const server = createApp().listen(0, '127.0.0.1');
    await new Promise((resolve) => { server.once('listening', resolve); });
    const response = await realFetch(`http://127.0.0.1:${server.address().port}/api/pets`);
    assert.strictEqual(response.status, 401);
    server.closeAllConnections();
    await new Promise((resolve) => { server.close(resolve); });
  });
});

test('création : fiche, photos en octets et pesée dans une seule écriture', async () => {
  await withServer(async (api, { commits }) => {
    const created = await api('POST', '', body({
      photos: [{ data: image('une') }, { data: image('deux') }],
      weight: weight(),
    }));
    assert.strictEqual(created.status, 201);
    assert.strictEqual(created.json.ownerId, UID);
    assert.strictEqual(created.json.status, 'active');
    assert.strictEqual(commits.length, 1);
    assert.strictEqual(commits[0].length, 4);
    assert.strictEqual(commits[0][1].update.fields.data.bytesValue, image('une'));

    const { json: photos } = await api('GET', `/${created.json.id}/photos`);
    assert.deepStrictEqual(photos.map((p) => p.data), [image('une'), image('deux')]);
    const { json: cover } = await api('GET', `/${created.json.id}/cover`);
    assert.strictEqual(cover.data, image('une'));
  });
});

test('photos : couverture, suppression avec ordre recompacté, limite de 5', async () => {
  await withServer(async (api) => {
    const { json: pet } = await api('POST', '', body({ photos: [{ data: image('a') }, { data: image('b') }, { data: image('c') }] }));
    const list = async () => (await api('GET', `/${pet.id}/photos`)).json;

    const [a, , c] = await list();
    assert.strictEqual((await api('POST', `/${pet.id}/photos/${c.id}/cover`)).status, 204);
    assert.deepStrictEqual((await list()).map((p) => p.data), [image('c'), image('a'), image('b')]);

    assert.strictEqual((await api('DELETE', `/${pet.id}/photos/${a.id}`)).status, 204);
    assert.deepStrictEqual((await list()).map((p) => [p.data, p.sortOrder]), [[image('c'), 0], [image('b'), 1]]);

    await api('POST', `/${pet.id}/photos`, { data: image('d') });
    await api('POST', `/${pet.id}/photos`, { data: image('e') });
    assert.strictEqual((await api('POST', `/${pet.id}/photos`, { data: image('f') })).json.sortOrder, 4);
    assert.strictEqual((await api('POST', `/${pet.id}/photos`, { data: image('g') })).status, 409);
    assert.strictEqual((await api('DELETE', `/${pet.id}/photos/inconnue`)).status, 404);
  });
});

test('modification : la galerie est remplacée dans le nouvel ordre', async () => {
  await withServer(async (api) => {
    const { json: pet } = await api('POST', '', body({ photos: [{ data: image('a') }, { data: image('b') }] }));
    const { json: [a, b] } = await api('GET', `/${pet.id}/photos`);

    const updated = await api('PUT', `/${pet.id}`, body({
      name: 'Nouveau', photos: [{ data: image('n') }, { id: b.id }],
    }));
    assert.strictEqual(updated.json.name, 'Nouveau');
    const { json: photos } = await api('GET', `/${pet.id}/photos`);
    assert.deepStrictEqual(photos.map((p) => p.data), [image('n'), image('b')]);
    assert.ok(!photos.some((p) => p.id === a.id));

    assert.strictEqual((await api('PUT', `/${pet.id}`, body({ photos: [{ id: a.id }] }))).status, 400);
  });
});

test('pesées : une par jour, la plus récente d\'abord', async () => {
  await withServer(async (api) => {
    const { json: pet } = await api('POST', '', body());
    assert.strictEqual((await api('POST', `/${pet.id}/weights`, weight())).status, 201);
    assert.strictEqual((await api('POST', `/${pet.id}/weights`, weight())).status, 409);
    await api('POST', `/${pet.id}/weights`, weight({ date: '2026-01-11', measuredOn: '2026-01-10T23:00:00.000Z' }));

    assert.strictEqual((await api('GET', `/${pet.id}/weights?limit=1`)).json.length, 1);
    assert.strictEqual((await api('DELETE', `/${pet.id}/weights/2026-01-10`)).status, 204);
    assert.strictEqual((await api('GET', `/${pet.id}/weights`)).json.length, 1);
  });
});

test('un animal archivé se lit et se restaure, mais ne se modifie plus', async () => {
  await withServer(async (api) => {
    const { json: pet } = await api('POST', '', body());
    assert.strictEqual((await api('POST', `/${pet.id}/archive`)).status, 204);
    assert.strictEqual((await api('GET', `/${pet.id}`)).json.status, 'archived');
    assert.strictEqual((await api('GET', '?status=active')).json.length, 0);
    assert.strictEqual((await api('GET', '?status=archived')).json.length, 1);

    assert.strictEqual((await api('PATCH', `/${pet.id}`, { favorite: true })).status, 409);
    assert.strictEqual((await api('PUT', `/${pet.id}`, body())).status, 409);
    assert.strictEqual((await api('POST', `/${pet.id}/weights`, weight())).status, 409);
    assert.strictEqual((await api('POST', `/${pet.id}/photos`, { data: image('a') })).status, 409);

    assert.strictEqual((await api('POST', `/${pet.id}/restore`)).status, 204);
    assert.strictEqual((await api('PATCH', `/${pet.id}`, { favorite: true })).json.favorite, true);
  });
});

test("l'animal d'un autre compte est refusé", async () => {
  await withServer(async (api, { docs }) => {
    docs.set('pets/autre', { ownerId: { stringValue: 'user-2' }, status: { stringValue: 'active' } });
    assert.strictEqual((await api('GET', '/autre')).status, 403);
    assert.strictEqual((await api('PATCH', '/autre', { favorite: true })).status, 403);
    assert.strictEqual((await api('GET', '/absent')).status, 404);
  });
});
