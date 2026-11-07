import 'package:flutter_test/flutter_test.dart';
import 'package:projet_flutter/features/appointments/data/reminder.dart';
import 'package:projet_flutter/features/assistant/data/answer_parser.dart';
import 'package:projet_flutter/features/assistant/data/assistant_message.dart';
import 'package:projet_flutter/features/assistant/data/assistant_pet.dart';
import 'package:projet_flutter/features/assistant/data/assistant_prompt.dart';
import 'package:projet_flutter/features/assistant/presentation/widgets/reminder_sheet.dart';
import 'package:projet_flutter/features/health/data/health_entry.dart';
import 'package:projet_flutter/features/health/data/treatment.dart';

final now = DateTime(2026, 10, 30);

AssistantPet pet({String species = 'dog', DateTime? birthDate, String name = 'Rocky'}) => AssistantPet(
      id: 'p1',
      name: name,
      species: species,
      sex: 'male',
      breed: 'Berger allemand',
      birthDate: birthDate ?? DateTime(2023, 6, 1),
      sterilized: true,
      notes: 'Allergique au poulet',
    );

void main() {
  group('rappels proposés', () {
    test('garde un rappel valide et retire le tag', () {
      final a = parseAnswer('Tous les 3 mois. [[rappel:Vermifuger Rocky|2027-01-30]]', {}, allowReminders: true, now: now);
      expect(a.text, 'Tous les 3 mois.');
      expect(a.reminders.single.title, 'Vermifuger Rocky');
      expect(a.reminders.single.dueAt, DateTime(2027, 1, 30));
    });

    test('ignore les rappels sans animal sélectionné', () {
      final a = parseAnswer('Texte [[rappel:Vermifuger|2027-01-30]]', {}, now: now);
      expect(a.reminders, isEmpty);
      expect(a.text, 'Texte');
    });

    test('ignore une date passée ou trop lointaine, garde 2 rappels au plus', () {
      final raw = [
        '[[rappel:Passé|2026-01-01]]',
        '[[rappel:Lointain|2030-01-01]]',
        '[[rappel:Soin un|2026-11-15]]',
        '[[rappel:Soin deux|2026-12-15]]',
        '[[rappel:Soin trois|2027-01-15]]',
      ].join(' ');
      final a = parseAnswer(raw, {}, allowReminders: true, now: now);
      expect(a.reminders.map((r) => r.title), ['Soin un', 'Soin deux']);
    });

    test('se relit depuis l\'historique', () {
      final r = ReminderSuggestion(title: 'Vaccin Rocky', dueAt: DateTime(2027, 3, 1));
      final back = ReminderSuggestion.fromMap(r.toMap())!;
      expect(back.title, 'Vaccin Rocky');
      expect(back.dueAt, DateTime(2027, 3, 1));
    });

    test('devine la catégorie du rappel', () {
      expect(guessReminderCategory('Vermifuger Rocky'), ReminderCategory.treatment);
      expect(guessReminderCategory('Rappel vaccin rage'), ReminderCategory.vet);
      expect(guessReminderCategory('Couper les griffes'), ReminderCategory.hygiene);
      expect(guessReminderCategory('Bilan senior'), ReminderCategory.checkup);
      expect(guessReminderCategory('Promenade'), ReminderCategory.care);
    });
  });

  group('animal sélectionné', () {
    test('contexte avec âge, poids, notes et carnet, sans le propriétaire', () {
      final context = buildPetContext(
        pet(),
        weight: (kg: 31.4, measuredOn: now),
        health: const ['Vaccin rage : 12/03/2026'],
        now: now,
      );
      expect(context, contains('Nom : Rocky'));
      expect(context, contains('Espèce : chien'));
      expect(context, contains('Âge : 3 ans'));
      expect(context, contains('Dernier poids : 31.4 kg'));
      expect(context, contains('Allergique au poulet'));
      expect(context, contains('- Vaccin rage : 12/03/2026'));
    });

    test('âge inconnu : pas de ligne Âge', () {
      final p = AssistantPet(id: 'x', name: 'Coco', species: 'bird');
      expect(buildPetContext(p, now: now), isNot(contains('Âge')));
    });
  });

  group('questions recommandées', () {
    test('5 questions dans chaque contexte', () {
      expect(recommendedQuestions(signedIn: false), hasLength(5));
      expect(recommendedQuestions(signedIn: true), hasLength(5));
      expect(recommendedQuestions(signedIn: true, pet: pet(), now: now), hasLength(5));
    });

    test('visiteur et utilisateur : « Trouver mon compagnon » joint les annonces', () {
      expect(recommendedQuestions(signedIn: false).first.adoption, isTrue);
      expect(recommendedQuestions(signedIn: true).first.adoption, isTrue);
    });

    test('adaptées à l\'espèce, à l\'âge et au nom', () {
      final puppy = recommendedQuestions(signedIn: true, pet: pet(birthDate: DateTime(2026, 6, 1)), now: now);
      expect(puppy.first.question, contains('vaccins pour Rocky'));
      final seniorCat =
          recommendedQuestions(signedIn: true, pet: pet(species: 'cat', name: 'Mimi', birthDate: DateTime(2015, 1, 1)), now: now);
      expect(seniorCat.map((s) => s.question).join(), contains('Mimi, chat senior'));
    });
  });

  group('historique', () {
    test('une réponse se relit avec ses annonces, rappels et avis', () {
      final message = AssistantMessage.assistant(
        'Voici Nala',
        listingIds: const ['abc'],
        reminders: [ReminderSuggestion(title: 'Vaccin', dueAt: DateTime(2027, 1, 1))],
      );
      final back = AssistantMessage.fromMap('m1', {...message.toMap(), 'rating': 'up'});
      expect(back.fromUser, isFalse);
      expect(back.listingIds, ['abc']);
      expect(back.reminders.single.title, 'Vaccin');
      expect(back.rating, AnswerRating.up);
      expect(back.id, 'm1');
    });
  });

  group('buildHealthSummary', () {
    test('allergies, latest vaccine per name, ongoing treatments and last visit', () {
      final lines = buildHealthSummary(
        now: now,
        entries: [
          HealthEntry(id: 'a', type: HealthEntryType.allergy, title: 'Poulet', date: DateTime(2025, 1, 1)),
          HealthEntry(
              id: 'v1', type: HealthEntryType.vaccine, title: 'Rage', vaccineName: 'Rage',
              date: DateTime(2025, 3, 1), nextReminderAt: DateTime(2026, 3, 1)),
          HealthEntry(
              id: 'v2', type: HealthEntryType.vaccine, title: 'Rage', vaccineName: 'Rage',
              date: DateTime(2026, 3, 2), nextReminderAt: DateTime(2027, 3, 2)),
          HealthEntry(
              id: 'v3', type: HealthEntryType.vaccine, title: 'CHPPi', vaccineName: 'CHPPi',
              date: DateTime(2025, 6, 1), nextReminderAt: DateTime(2026, 6, 1)),
          HealthEntry(id: 'x', type: HealthEntryType.visit, title: 'Bilan annuel', date: DateTime(2026, 9, 10)),
        ],
        treatments: [
          Treatment(
              id: 't1', category: 'Antiparasitaire', name: 'Milbemax', posology: '1 comprimé',
              startDate: DateTime(2026, 10, 1), endDate: DateTime(2026, 11, 15)),
          Treatment(
              id: 't2', category: 'Antibiotique', name: 'Fini', posology: '2/j',
              startDate: DateTime(2026, 1, 1), endDate: DateTime(2026, 1, 10)),
        ],
      );
      expect(lines, [
        'Allergie : Poulet',
        'Vaccin Rage : fait le 02/03/2026, prochain rappel le 02/03/2027',
        'Vaccin CHPPi : fait le 01/06/2025, rappel en retard depuis le 01/06/2026',
        "Traitement en cours : Milbemax (1 comprimé) jusqu'au 15/11/2026",
        'Dernière visite : Bilan annuel le 10/09/2026',
      ]);
    });

    test('empty health record gives no lines', () {
      expect(buildHealthSummary(entries: const [], treatments: const [], now: now), isEmpty);
    });
  });
}
