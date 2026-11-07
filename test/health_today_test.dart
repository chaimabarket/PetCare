import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:projet_flutter/features/health/data/health_summary.dart';
import 'package:projet_flutter/features/health/data/treatment.dart';
import 'package:projet_flutter/features/health/presentation/widgets/health_today_card.dart';
import 'package:projet_flutter/l10n/app_localizations.dart';

/// Midi, le 4 novembre 2026.
final _now = DateTime(2026, 11, 4, 12);

Treatment _treatment(List<String> times, {List<DateTime> doses = const []}) => Treatment(
      id: 't1',
      category: 'Antibiotique',
      name: 'Synulox',
      posology: '1 comprimé',
      startDate: DateTime(2026, 11, 1),
      endDate: DateTime(2026, 11, 10),
      doseTimes: times,
      doses: doses,
    );

DoseSlot _slot(int hour, {bool done = false}) => DoseSlot(
      petId: 'p1',
      petName: 'Milo',
      treatment: _treatment(const []),
      time: DateTime(2026, 11, 4, hour),
      done: done,
    );

HealthSummary _summary() => HealthSummary(pets: [
      PetHealthSummary(
        id: 'p1',
        name: 'Milo',
        species: 'dog',
        pendingVaccines: [PendingVaccine(entryId: 'v1', title: 'Rabisin', dueAt: DateTime(2026, 10, 20))],
        activeTreatments: [
          _treatment(const ['08:00', '13:00', '20:00'], doses: [DateTime(2026, 11, 4, 8, 10)]),
        ],
      ),
      PetHealthSummary(
        id: 'p2',
        name: 'Nala',
        species: 'cat',
        pendingVaccines: [PendingVaccine(entryId: 'v2', title: 'Typhus', dueAt: DateTime(2026, 11, 20))],
      ),
      PetHealthSummary(
        id: 'p3',
        name: 'Rex',
        archived: true,
        pendingVaccines: [PendingVaccine(entryId: 'v3', title: 'Rage', dueAt: DateTime(2026, 1, 1))],
      ),
    ]);

void main() {
  group('Créneau du tableau du jour', () {
    test('se coche : passé ou dans moins de 3 h ; pas déjà fait', () {
      expect(_slot(8).canCheck(_now), isTrue, reason: 'oublié ce matin');
      expect(_slot(14).canCheck(_now), isTrue, reason: 'dans 2 h');
      expect(_slot(20).canCheck(_now), isFalse, reason: 'dans 8 h : à venir');
      expect(_slot(8, done: true).canCheck(_now), isFalse);
    });

    test("heure enregistrée : celle du créneau s'il est passé, sinon maintenant", () {
      expect(_slot(8).logTime(_now), DateTime(2026, 11, 4, 8));
      expect(_slot(14).logTime(_now), _now);
    });
  });

  testWidgets('affiche les prises (faite, à cocher, à venir) et les vaccins à surveiller', (tester) async {
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('fr'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: SingleChildScrollView(
          child: HealthTodayCard(summary: _summary(), now: _now, onOpenRecord: (_) {}),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Prises du jour'), findsOneWidget);
    expect(find.text('08:00'), findsOneWidget);
    expect(find.text('13:00'), findsOneWidget);
    expect(find.text('20:00'), findsOneWidget);
    expect(find.text('Faite'), findsOneWidget);
    expect(find.text('À venir'), findsOneWidget);

    final boxes = tester.widgetList<Checkbox>(find.byType(Checkbox)).toList();
    expect(boxes.map((b) => b.value), [true, false, false]);
    expect(boxes.map((b) => b.onChanged != null), [false, true, false], reason: 'seule la prise de 13 h se coche');

    expect(find.text('Milo · Rabisin'), findsOneWidget);
    expect(find.textContaining('En retard depuis le'), findsOneWidget);
    expect(find.text('Nala · Typhus'), findsOneWidget);
    expect(find.textContaining('Prévu le'), findsOneWidget);
    expect(find.textContaining('Rex'), findsNothing, reason: 'animal archivé exclu');
  });

  testWidgets('rien à faire : messages vides', (tester) async {
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('fr'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: HealthTodayCard(
          summary: const HealthSummary(pets: [PetHealthSummary(id: 'p1', name: 'Milo')]),
          now: _now,
          onOpenRecord: (_) {},
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text("Aucune prise prévue aujourd'hui."), findsOneWidget);
    expect(find.text('Aucun vaccin en retard ni prévu dans les 30 prochains jours.'), findsOneWidget);
  });
}
