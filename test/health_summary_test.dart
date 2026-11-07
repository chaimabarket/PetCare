import 'package:flutter_test/flutter_test.dart';
import 'package:projet_flutter/core/navigation/main_tabs.dart';
import 'package:projet_flutter/features/health/data/health_entry.dart';
import 'package:projet_flutter/features/health/data/health_pet.dart';
import 'package:projet_flutter/features/health/data/health_summary.dart';
import 'package:projet_flutter/features/health/data/treatment.dart';
import 'package:projet_flutter/l10n/app_localizations_fr.dart';

/// Midi, le 4 novembre 2026 (heure locale du téléphone).
final _now = DateTime(2026, 11, 4, 12);

String _iso(DateTime d) => d.toUtc().toIso8601String();

Map<String, dynamic> _pet({
  String id = 'p1',
  String name = 'Milo',
  String status = 'active',
  List<Map<String, dynamic>> vaccines = const [],
  List<Map<String, dynamic>> treatments = const [],
  Map<String, dynamic>? lastVisit,
  List<String> allergies = const [],
}) =>
    {
      'id': id,
      'name': name,
      'species': 'dog',
      'breed': 'Golden Retriever',
      'status': status,
      'pendingVaccines': vaccines,
      'lastVisit': lastVisit,
      'allergies': [for (final a in allergies) {'id': a, 'title': a}],
      'activeTreatments': treatments,
    };

Map<String, dynamic> _vaccine(DateTime due, {String name = 'Rabisin'}) => {
      'id': 'v-$name',
      'title': 'Rage',
      'vaccineName': name,
      'date': _iso(due.subtract(const Duration(days: 365))),
      'nextReminderAt': _iso(due),
    };

Map<String, dynamic> _treatment({
  String id = 't1',
  List<String> times = const ['08:00', '20:00'],
  List<DateTime> doses = const [],
  int startOffset = -2,
  int endOffset = 5,
}) =>
    {
      'id': id,
      'name': 'Synulox',
      'category': 'Antibiotique',
      'posology': '1 comprimé matin et soir',
      'form': 'comprime',
      'startDate': _iso(DateTime(2026, 11, 4 + startOffset)),
      'endDate': _iso(DateTime(2026, 11, 4 + endOffset)),
      'doseTimes': times,
      'doses': [for (final d in doses) _iso(d)],
      'stoppedAt': null,
    };

PetHealthSummary _summary(Map<String, dynamic> json) => PetHealthSummary.fromJson(json);

void main() {
  group('Onglets', () {
    test('5 onglets, Santé en 3e position', () {
      final tabs = mainTabs(AppLocalizationsFr());
      expect(tabs.map((t) => t.label), ['Accueil', 'Mes animaux', 'Santé', 'Communauté', 'Services']);
      expect([MainTab.home, MainTab.pets, MainTab.health, MainTab.community, MainTab.services], [0, 1, 2, 3, 4]);
    });
  });

  group('Statut du prochain vaccin', () {
    test('en retard, bientôt (30 jours ou moins), à jour, aucun', () {
      VaccineStatus status(DateTime due) => _summary(_pet(vaccines: [_vaccine(due)])).vaccineStatus(_now);
      expect(status(DateTime(2026, 11, 3)), VaccineStatus.overdue);
      expect(status(DateTime(2026, 11, 4)), VaccineStatus.soon, reason: "aujourd'hui n'est pas encore en retard");
      expect(status(DateTime(2026, 12, 4)), VaccineStatus.soon, reason: 'J+30');
      expect(status(DateTime(2026, 12, 5)), VaccineStatus.upToDate, reason: 'J+31');
      expect(_summary(_pet()).vaccineStatus(_now), VaccineStatus.none);
    });

    test('le plus proche des rappels compte', () {
      final pet = _summary(_pet(vaccines: [
        _vaccine(DateTime(2027, 5, 1), name: 'CHPPiL'),
        _vaccine(DateTime(2026, 10, 1), name: 'Rabisin'),
      ]));
      expect(pet.nextVaccine!.title, 'Rabisin');
      expect(pet.vaccineStatus(_now), VaccineStatus.overdue);
    });
  });

  group('Prises du jour', () {
    test('une prise notée à ± 3 h couvre le créneau', () {
      final pet = _summary(_pet(treatments: [
        _treatment(doses: [DateTime(2026, 11, 4, 9, 15), DateTime(2026, 11, 3, 20)]),
      ]));
      final doses = pet.todayDoses(_now);
      expect(doses.map((d) => d.time.hour), [8, 20]);
      expect(doses.map((d) => d.done), [true, false]);
    });

    test('traitement pas encore commencé ou terminé : aucune prise', () {
      expect(_summary(_pet(treatments: [_treatment(startOffset: 1, endOffset: 5)])).todayDoses(_now), isEmpty);
      expect(_summary(_pet(treatments: [_treatment(startOffset: -9, endOffset: -1)])).todayDoses(_now), isEmpty);
      expect(_summary(_pet(treatments: [_treatment(startOffset: -9, endOffset: 0)])).todayDoses(_now), hasLength(2),
          reason: 'le dernier jour compte encore');
    });

    test('tableau du jour : tous les animaux actifs, par heure', () {
      final summary = HealthSummary.fromJson({
        'pets': [
          _pet(id: 'p1', name: 'Milo', treatments: [_treatment(times: ['20:00'])]),
          _pet(id: 'p2', name: 'Nala', treatments: [_treatment(id: 't2', times: ['07:30'])]),
          _pet(id: 'p3', name: 'Rex', status: 'archived', treatments: [_treatment(id: 't3', times: ['06:00'])]),
        ],
      });
      expect(summary.todayDoses(_now).map((d) => '${d.petName} ${d.time.hour}'), ['Nala 7', 'Milo 20']);
    });
  });

  group('Tri des cartes', () {
    test("les animaux qui demandent une action d'abord, puis par nom ; archivés à part", () {
      final summary = HealthSummary.fromJson({
        'pets': [
          _pet(id: 'a', name: 'Aya'),
          _pet(id: 'b', name: 'Bob', vaccines: [_vaccine(DateTime(2026, 11, 20))]),
          _pet(id: 'c', name: 'Cali', treatments: [_treatment()]),
          _pet(id: 'd', name: 'Dino', vaccines: [_vaccine(DateTime(2026, 10, 20))]),
          _pet(id: 'e', name: 'Eko', status: 'archived', vaccines: [_vaccine(DateTime(2026, 1, 1))]),
        ],
      });
      expect(summary.activeSorted(_now).map((p) => p.name), ['Dino', 'Cali', 'Bob', 'Aya']);
      expect(summary.archived.map((p) => p.name), ['Eko']);
      expect(summary.vaccinesDue(_now).map((e) => e.$1.name), ['Dino', 'Bob'], reason: 'archivés exclus');
    });
  });

  group('Synthèse construite depuis Firestore (serveur éteint)', () {
    test('même résultat que la réponse de l’API', () {
      final entries = [
        HealthEntry(
          id: 'v1',
          type: HealthEntryType.vaccine,
          title: 'Rage',
          vaccineName: 'Rabisin',
          date: DateTime(2025, 11, 1),
          nextReminderAt: DateTime(2026, 11, 1),
        ),
        HealthEntry(
          id: 'v2',
          type: HealthEntryType.vaccine,
          title: 'Toux',
          date: DateTime(2025, 1, 1),
          nextReminderAt: DateTime(2026, 1, 1),
          reminderDone: true,
        ),
        HealthEntry(id: 'e1', type: HealthEntryType.exam, title: 'Prise de sang', date: DateTime(2026, 10, 20)),
        HealthEntry(id: 'a1', type: HealthEntryType.allergy, title: 'Poulet', date: DateTime(2026, 1, 3)),
      ];
      final treatments = [
        Treatment.fromJson(_treatment()),
        Treatment.fromJson({..._treatment(id: 't2'), 'stoppedAt': _iso(DateTime(2026, 11, 3))}),
      ];
      final pet = PetHealthSummary.fromRecords(
        id: 'p1',
        pet: {'name': 'Milo', 'species': 'dog', 'status': 'archived'},
        entries: entries,
        treatments: treatments,
        now: _now,
      );
      expect(pet.archived, isTrue);
      expect(pet.pendingVaccines.map((v) => v.title), ['Rabisin']);
      expect(pet.lastVisitTitle, 'Prise de sang');
      expect(pet.allergies, ['Poulet']);
      expect(pet.activeTreatments.map((t) => t.id), ['t1']);
    });
  });

  group("Réponses de l'API REST", () {
    test('un soin et un traitement se lisent comme ceux de Firestore', () {
      final entry = HealthEntry.fromJson({
        'id': 'e1',
        'type': 'visite',
        'title': 'Bilan',
        'date': '2026-11-02T09:30:00.000Z',
        'nextReminderAt': '2027-05-02T00:00:00.000Z',
        'attachments': [
          {'name': 'Ordonnance.pdf', 'mimeType': 'application/pdf', 'size': 1400},
        ],
      });
      expect(entry.type, HealthEntryType.visit);
      expect(entry.date.toUtc(), DateTime.utc(2026, 11, 2, 9, 30));
      expect(entry.nextReminderAt, isNotNull, reason: 'le prochain contrôle d’une visite est gardé');
      expect(entry.attachments.single.isImage, isFalse);

      final t = Treatment.fromJson(_treatment(doses: [DateTime(2026, 11, 4, 20), DateTime(2026, 11, 4, 8)]));
      expect(t.form, TreatmentForm.tablet);
      expect(t.doses.first.isBefore(t.doses.last), isTrue);
    });

    test("la fiche d'un animal archivé est reconnue", () {
      expect(HealthPet.fromJson({'id': 'p1', 'name': 'Milo', 'status': 'archived'}).archived, isTrue);
      expect(HealthPet.fromJson({'id': 'p1', 'name': 'Milo', 'status': 'active'}).archived, isFalse);
    });
  });
}
