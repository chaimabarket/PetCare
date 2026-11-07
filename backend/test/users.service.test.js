// Tests du service Utilisateurs avec un faux dépôt en mémoire.

const test = require('node:test');
const assert = require('node:assert');

const { createUsersService } = require('../src/users/service');

function fakeRepository({ profiles = {}, notifications = [] } = {}) {
  const calls = [];
  return {
    calls,
    getProfile: async (_t, uid) => profiles[uid] ?? null,
    createProfile: async (_t, uid, data) => {
      calls.push(['createProfile', uid, data]);
      profiles[uid] = { id: uid, ...data };
    },
    updateProfile: async (_t, uid, fields) => {
      calls.push(['updateProfile', uid, fields]);
      profiles[uid] = { ...profiles[uid], ...fields };
    },
    listNotifications: async (_t, _uid, limit) => {
      calls.push(['listNotifications', limit]);
      return notifications;
    },
    listUnreadNotifications: async () => notifications.filter((n) => !n.read),
    markNotificationsRead: async (_t, _uid, ids) => calls.push(['markNotificationsRead', ids]),
    markNotificationRead: async (_t, _uid, id) => calls.push(['markNotificationRead', id]),
  };
}

const user = { uid: 'u1', email: 'lina@exemple.com' };
const body = { fullName: 'Lina Ben', city: 'Tunis', role: 'proprietaire' };

test("création du profil : l'e-mail vient du compte, pas du corps de la requête", async () => {
  const repo = fakeRepository();
  const profile = await createUsersService(repo).createProfile('t', user, { ...body, email: 'pirate@exemple.com' });

  assert.strictEqual(profile.email, 'lina@exemple.com');
  assert.strictEqual(profile.role, 'proprietaire');
  assert.strictEqual(profile.uid, 'u1');
});

test('création du profil : le rôle admin est refusé, un profil existant aussi', async () => {
  const s = createUsersService(fakeRepository());
  await assert.rejects(s.createProfile('t', user, { ...body, role: 'admin' }), { status: 400 });

  const existing = createUsersService(fakeRepository({ profiles: { u1: { id: 'u1' } } }));
  await assert.rejects(existing.createProfile('t', user, body), { status: 409 });
});

test('lecture du profil : 404 si absent, téléphone à null si non renseigné', async () => {
  await assert.rejects(createUsersService(fakeRepository()).getProfile('t', 'u1'), { status: 404 });

  const s = createUsersService(fakeRepository({ profiles: { u1: { id: 'u1', fullName: 'Lina', email: 'e', city: 'Tunis', role: 'refuge' } } }));
  assert.strictEqual((await s.getProfile('t', 'u1')).phone, null);
});

test('modification : seuls le nom, la ville et le téléphone changent', async () => {
  const repo = fakeRepository({ profiles: { u1: { id: 'u1', fullName: 'Ancien', email: 'e', city: 'Tunis', role: 'refuge' } } });
  const updated = await createUsersService(repo).updateProfile('t', 'u1', { fullName: 'Nouveau nom', city: 'Sfax', role: 'admin', email: 'x@y.z' });

  assert.strictEqual(updated.fullName, 'Nouveau nom');
  assert.strictEqual(updated.role, 'refuge');
  assert.deepStrictEqual(Object.keys(repo.calls[0][2]).sort(), ['city', 'fullName', 'phone']);
});

test('notifications : limite bornée entre 1 et 100, compteur et « tout lu »', async () => {
  const repo = fakeRepository({ notifications: [{ id: 'a', read: false }, { id: 'b', read: true }, { id: 'c', read: false }] });
  const s = createUsersService(repo);

  await s.listNotifications('t', 'u1', undefined);
  await s.listNotifications('t', 'u1', '500');
  await s.listNotifications('t', 'u1', '0');
  assert.deepStrictEqual(repo.calls.map((c) => c[1]), [50, 100, 50]);

  assert.deepStrictEqual(await s.unreadCount('t', 'u1'), { count: 2 });
  assert.deepStrictEqual(await s.markAllRead('t', 'u1'), { updated: 2 });
  assert.deepStrictEqual(repo.calls.at(-1), ['markNotificationsRead', ['a', 'c']]);
});
