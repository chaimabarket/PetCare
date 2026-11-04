const test = require('node:test');
const assert = require('node:assert');

const { analyzeWeights, alertMessage, alertNotificationId } = require('../src/pets/weight_alert');
const { now, cases } = require('./fixtures/weight_alert_cases.json');

// Mêmes cas que test/weight_alert_test.dart : l'analyse doit être identique côté Flutter.
for (const c of cases) {
  test(`alerte de poids : ${c.name}`, () => {
    const alert = analyzeWeights({
      entries: c.entries, species: c.species, birthDate: c.birthDate, status: c.status, now: new Date(now),
    });
    if (c.expected === null) {
      assert.strictEqual(alert, null);
      return;
    }
    assert.deepStrictEqual(
      { rule: alert.rule, kind: alert.kind, level: alert.level, percent: alert.percent, days: alert.days, referenceId: alert.reference.id },
      c.expected,
    );
    if (c.message) assert.deepStrictEqual(alertMessage(alert, c.petName), c.message);
  });
}

test("l'identifiant de notification change avec la règle et la pesée de référence", () => {
  const entries = (kg) => [
    { id: '2026-10-28', measuredOn: '2026-10-28T00:00:00.000Z', weightKg: 10 },
    { id: '2026-11-04', measuredOn: '2026-11-04T00:00:00.000Z', weightKg: kg },
  ];
  const watch = analyzeWeights({ entries: entries(9.4), species: 'dog', now: new Date(now) });
  const worse = analyzeWeights({ entries: entries(8.9), species: 'dog', now: new Date(now) });
  assert.strictEqual(alertNotificationId('p1', watch), 'poids-p1-rapid-loss-2026-10-28');
  assert.strictEqual(alertNotificationId('p1', worse), 'poids-p1-loss-10-2026-10-28');
});
