const test = require('node:test');
const assert = require('node:assert');

const { profileFields, role } = require('../src/validation');

test('profileFields nettoie les valeurs et accepte un téléphone vide', () => {
  const result = profileFields({ fullName: '  Lina Ben  ', city: ' Tunis ', phone: '' });
  assert.deepStrictEqual(result, { fullName: 'Lina Ben', city: 'Tunis', phone: null });
});

test('profileFields refuse un nom vide ou trop court', () => {
  assert.throws(() => profileFields({ fullName: 'x', city: 'Tunis' }), { status: 400 });
  assert.throws(() => profileFields({}), { status: 400 });
});

test('profileFields refuse un téléphone invalide', () => {
  assert.throws(() => profileFields({ fullName: 'Lina', city: '', phone: 'abc' }), { status: 400 });
});

test('role refuse admin et les valeurs inconnues', () => {
  assert.strictEqual(role('refuge'), 'refuge');
  assert.throws(() => role('admin'), { status: 400 });
  assert.throws(() => role(undefined), { status: 400 });
});
