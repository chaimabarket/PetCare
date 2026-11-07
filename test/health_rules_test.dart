import 'package:flutter_test/flutter_test.dart';
import 'package:projet_flutter/features/health/data/health_format.dart';
import 'package:projet_flutter/features/health/data/health_sheets_starter.dart';
import 'package:projet_flutter/features/health/data/treatment.dart';

Treatment _treatment({
  required DateTime start,
  required DateTime end,
  List<String> doseTimes = const ['08:00', '20:00'],
  List<DateTime> doses = const [],
  DateTime? stoppedAt,
}) =>
    Treatment(
      id: 't1',
      category: 'Antibiotique',
      name: 'Synulox 250 mg',
      posology: '1 comprimé matin et soir',
      startDate: start,
      endDate: end,
      doseTimes: doseTimes,
      doses: doses,
      stoppedAt: stoppedAt,
    );

void main() {
  group('Dates en français', () {
    test('format des maquettes', () {
      expect(formatHealthDate(DateTime(2024, 9, 1)), '01 sept. 2024');
      expect(formatSlashDate(DateTime(2025, 11, 12)), '12 / 11 / 2025');
      expect(formatHealthRange(DateTime(2024, 11, 8), DateTime(2024, 11, 18)), 'Du 08 nov. au 18 nov. 2024');
      expect(formatHealthRange(DateTime(2024, 12, 28), DateTime(2025, 1, 3)), 'Du 28 déc. 2024 au 03 janv. 2025');
      expect(formatApproxMonth(DateTime(2025, 3, 2)), 'début mars 2025');
      expect(formatEuro(65), '65,00 €');
    });

    test("échéances relatives", () {
      final now = DateTime(2024, 10, 28);
      expect(formatTimeUntil(DateTime(2024, 11, 12), now: now), 'Dans 15 jours');
      expect(formatTimeUntil(DateTime(2025, 11, 12), now: DateTime(2024, 11, 12)), 'Dans 1 an');
      expect(formatTimeUntil(DateTime(2024, 10, 26), now: now), 'En retard de 2 jours');
      expect(formatTimeUntil(now, now: now), "Aujourd'hui");
    });

    test("âge de l'animal", () {
      final now = DateTime(2025, 3, 20);
      expect(formatPetAge(DateTime(2020, 5, 12), now: now), '4 ans et 10 mois');
      expect(formatPetAge(DateTime(2020, 5, 12), now: now, short: true), '4 ans');
      expect(formatPetAge(DateTime(2024, 11, 1), now: now), '4 mois');
    });

    test('prochaine prise', () {
      final now = DateTime(2024, 11, 13, 10);
      expect(formatDoseMoment(DateTime(2024, 11, 13, 14), now: now), "Aujourd'hui 14h00");
      expect(formatDoseMoment(DateTime(2024, 11, 13, 20), now: now), 'Ce soir 20h00');
      expect(formatDoseMoment(DateTime(2024, 11, 14, 8), now: now), 'Demain 08h00');
    });
  });

  group('Traitements', () {
    test('statut : en cours, terminé après la date de fin, arrêté', () {
      final t = _treatment(start: DateTime(2024, 11, 8), end: DateTime(2024, 11, 17));
      expect(t.statusAt(DateTime(2024, 11, 17, 23)), TreatmentStatus.active);
      expect(t.statusAt(DateTime(2024, 11, 18)), TreatmentStatus.completed);
      final stopped = _treatment(start: DateTime(2024, 1, 15), end: DateTime(2024, 1, 24), stoppedAt: DateTime(2024, 1, 19));
      expect(stopped.statusAt(DateTime(2024, 1, 20)), TreatmentStatus.stopped);
      expect(stopped.daysDoneBeforeStop, 5);
      expect(stopped.totalDays, 10);
    });

    test('jour en cours et progression', () {
      final t = _treatment(start: DateTime(2024, 11, 8), end: DateTime(2024, 11, 17));
      expect(t.totalDays, 10);
      expect(t.currentDay(DateTime(2024, 11, 13, 9)), 6);
    });

    test("la prochaine prise ignore un créneau déjà noté", () {
      final now = DateTime(2024, 11, 13, 7, 50);
      final t = _treatment(start: DateTime(2024, 11, 8), end: DateTime(2024, 11, 17));
      expect(t.nextDose(now), DateTime(2024, 11, 13, 8));

      final logged = _treatment(
        start: DateTime(2024, 11, 8),
        end: DateTime(2024, 11, 17),
        doses: [DateTime(2024, 11, 13, 7, 45)],
      );
      expect(logged.nextDose(now), DateTime(2024, 11, 13, 20));
    });

    test('pas de prochaine prise après la fin ou sans heures de prise', () {
      final t = _treatment(start: DateTime(2024, 11, 8), end: DateTime(2024, 11, 17));
      // Une prise oubliée reste proposée pendant 1 h, puis il n'y a plus de créneau.
      expect(t.nextDose(DateTime(2024, 11, 17, 20, 45)), DateTime(2024, 11, 17, 20));
      final now = DateTime(2024, 11, 17, 21, 30);
      expect(t.nextDose(now), isNull);
      expect(_treatment(start: DateTime(2024, 11, 8), end: DateTime(2024, 11, 20), doseTimes: const []).nextDose(now), isNull);
    });
  });

  test('les fiches de départ sont complètes et citent une source', () {
    expect(starterHealthSheets.where((s) => s.featured), hasLength(1));
    for (final sheet in starterHealthSheets) {
      expect(sheet.sections, isNotEmpty, reason: sheet.id);
      expect(sheet.source, isNotEmpty, reason: sheet.id);
      expect(sheet.imageAsset, startsWith('assets/images/health/'), reason: sheet.id);
    }
    expect(starterHealthSheets.map((s) => s.id).toSet(), hasLength(starterHealthSheets.length));
  });
}
