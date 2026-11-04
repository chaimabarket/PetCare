import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:projet_flutter/features/pets/data/pet_media.dart';
import 'package:projet_flutter/features/pets/data/weight_alert.dart';

/// Mêmes cas que backend/test/weight_alert.test.js : l'analyse doit être identique côté serveur.
void main() {
  final fixture =
      jsonDecode(File('backend/test/fixtures/weight_alert_cases.json').readAsStringSync()) as Map<String, dynamic>;
  final now = DateTime.parse(fixture['now'] as String);

  for (final c in (fixture['cases'] as List<dynamic>).cast<Map<String, dynamic>>()) {
    test('alerte de poids : ${c['name']}', () {
      final entries = [
        for (final e in (c['entries'] as List<dynamic>).cast<Map<String, dynamic>>())
          WeightEntry(
            id: e['id'] as String,
            measuredOn: DateTime.parse(e['measuredOn'] as String),
            weightKg: (e['weightKg'] as num).toDouble(),
          ),
      ];
      final alert = analyzeWeights(
        entries: entries,
        species: c['species'] as String,
        birthDate: c['birthDate'] == null ? null : DateTime.parse(c['birthDate'] as String),
        archived: c['status'] == 'archived',
        now: now,
      );

      final expected = c['expected'] as Map<String, dynamic>?;
      if (expected == null) {
        expect(alert, isNull);
        return;
      }
      expect(alert, isNotNull);
      expect(
        {
          'rule': alert!.rule,
          'kind': alert.kind.name,
          'level': alert.level.name,
          'percent': alert.percent,
          'days': alert.days,
          'referenceId': alert.reference.id,
        },
        {...expected, 'percent': (expected['percent'] as num).toDouble()},
      );

      final message = c['message'] as Map<String, dynamic>?;
      if (message != null) {
        final text = weightAlertMessage(alert, c['petName'] as String);
        expect({'title': text.title, 'body': text.body}, message);
      }
    });
  }

  test("l'identifiant de notification suit la règle et la pesée de référence", () {
    final alert = analyzeWeights(
      entries: [
        WeightEntry(id: '2026-10-28', measuredOn: DateTime.utc(2026, 10, 28), weightKg: 10),
        WeightEntry(id: '2026-11-04', measuredOn: DateTime.utc(2026, 11, 4), weightKg: 9.4),
      ],
      species: 'dog',
      now: now,
    );
    expect(weightAlertNotificationId('p1', alert!), 'poids-p1-rapid-loss-2026-10-28');
  });
}
