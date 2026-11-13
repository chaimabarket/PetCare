import 'package:flutter_test/flutter_test.dart';
import 'package:projet_flutter/features/assistant/data/assistant_actions.dart';
import 'package:projet_flutter/features/assistant/data/assistant_message.dart';
import 'package:projet_flutter/features/assistant/data/assistant_pet.dart';

final now = DateTime(2026, 11, 12, 14, 5);

const pets = [
  AssistantPet(id: 'p1', name: 'Nala', species: 'rabbit'),
  AssistantPet(id: 'p2', name: 'Rex', species: 'dog'),
];

AssistantAction call(String name, Map<String, Object?> args) => AssistantAction.fromCall(name, args)!;

void main() {
  group('AssistantAction.fromCall', () {
    test('ignores unknown functions and unknown or empty fields', () {
      expect(AssistantAction.fromCall('supprimer_animal', {'animal': 'Rex'}), isNull);
      final a = call('ajouter_pesee', {'animal': ' Rex ', 'poids_kg': 12.5, 'couleur': 'brun', 'date': ''});
      expect(a.type, AssistantActionType.weight);
      expect(a.args, {'animal': 'Rex', 'poids_kg': 12.5});
    });

    test('round-trips through Firestore data with its status', () {
      final a = call('creer_rappel', {'animal': 'Rex', 'titre': 'Vermifuger Rex', 'date': '2026-12-01'})
          .withStatus(AssistantActionStatus.done);
      final back = AssistantAction.fromMap(a.toMap())!;
      expect(back.type, AssistantActionType.reminder);
      expect(back.status, AssistantActionStatus.done);
      expect(back.args, a.args);
    });
  });

  group('checkAction', () {
    test('appointment without a time asks for it instead of guessing', () {
      final a = call('creer_rendez_vous', {'animal': 'Rex', 'titre': 'Vaccin rage', 'type': 'vaccin', 'date': '2026-11-13'});
      final check = checkAction(a, pets, now: now);
      expect(check.ok, isFalse);
      expect(check.missing, ['heure']);
      expect(check.problemText(a), 'Pour créer ce rendez-vous, il me manque : heure. Pouvez-vous me les donner ?');
    });

    test('lists every missing field at once', () {
      final a = call('creer_rendez_vous', {'animal': 'Rex'});
      expect(checkAction(a, pets, now: now).missing, ['intitulé', 'type', 'date', 'heure']);
    });

    test('a vaccine also needs its name and next booster date', () {
      final a = call('ajouter_soin', {'animal': 'Rex', 'type': 'vaccin', 'titre': 'Rage', 'date': '2026-11-10'});
      expect(checkAction(a, pets, now: now).missing, ['nom du vaccin', 'date du prochain rappel']);
    });

    test('complete appointment in the future is valid and resolves the pet case-insensitively', () {
      final a = call('creer_rendez_vous',
          {'animal': 'rex', 'titre': 'Vaccin rage', 'type': 'vaccin', 'date': '2026-11-13', 'heure': '10:30'});
      final check = checkAction(a, pets, now: now);
      expect(check.ok, isTrue);
      expect(check.pet!.id, 'p2');
      expect(a.startsAt, DateTime(2026, 11, 13, 10, 30));
    });

    test('unknown pet is reported with the list of pets', () {
      final a = call('ajouter_pesee', {'animal': 'Milo', 'poids_kg': 4});
      expect(checkAction(a, pets, now: now).error, contains('Nala, Rex'));
    });

    test('health record refuses a future date and suggests an appointment', () {
      final a = call('ajouter_soin', {'animal': 'Nala', 'type': 'visite', 'titre': 'Contrôle', 'date': '2026-11-20'});
      expect(checkAction(a, pets, now: now).error, contains('rendez-vous'));
    });

    test('allergy for today is valid', () {
      final a = call('ajouter_soin', {'animal': 'Nala', 'type': 'allergie', 'titre': 'Pollen', 'date': '2026-11-12'});
      expect(checkAction(a, pets, now: now).ok, isTrue);
    });

    test('appointment in the past, invalid date or choice are refused', () {
      final past = call('creer_rendez_vous',
          {'animal': 'Rex', 'titre': 'Toilettage', 'type': 'toilettage', 'date': '2026-11-12', 'heure': '09:00'});
      expect(checkAction(past, pets, now: now).error, contains('futur'));

      final badDate = call('creer_rappel', {'animal': 'Rex', 'titre': 'Vermifuger Rex', 'date': '2026-02-31'});
      expect(checkAction(badDate, pets, now: now).error, contains('pas valide'));

      final badType = call('ajouter_soin', {'animal': 'Rex', 'type': 'chirurgie', 'titre': 'x', 'date': '2026-11-01'});
      expect(checkAction(badType, pets, now: now).error, contains('pas valide'));
    });

    test('treatment end before start and weight out of range are refused', () {
      final treatment = call('ajouter_traitement', {
        'animal': 'Rex',
        'nom': 'Milbemax',
        'categorie': 'Vermifuge',
        'posologie': '1 comprimé',
        'debut': '2026-11-10',
        'fin': '2026-11-01',
      });
      expect(checkAction(treatment, pets, now: now).error, contains('après son début'));

      final weight = call('ajouter_pesee', {'animal': 'Rex', 'poids_kg': '0'});
      expect(checkAction(weight, pets, now: now).error, contains('500 kg'));
    });
  });

  group('display and history', () {
    test('card lines are formatted for people', () {
      final a = call('creer_rendez_vous', {
        'animal': 'Rex',
        'titre': 'Vaccin rage',
        'type': 'veterinaire',
        'date': '2026-11-13',
        'heure': '10:30',
        'duree_minutes': 45,
      });
      expect(describeAction(a), [
        ('Animal', 'Rex'),
        ('Intitulé', 'Vaccin rage'),
        ('Type', 'Vétérinaire'),
        ('Date', '13/11/2026'),
        ('Heure', '10:30'),
        ('Durée', '45 min'),
      ]);
    });

    test('history tells the model whether the action was confirmed', () {
      final a = call('ajouter_soin', {'animal': 'Nala', 'type': 'allergie', 'titre': 'Pollen', 'date': '2026-11-12'});
      final message = AssistantMessage.assistant('Vérifiez puis confirmez.', actions: [a]);
      expect(message.historyText, contains("pas encore confirmée"));
      final done = message.copyWith(actions: [a.withStatus(AssistantActionStatus.done)]);
      expect(done.historyText, contains('confirmée et enregistrée'));
      expect(done.toMap()['actions'], [a.withStatus(AssistantActionStatus.done).toMap()]);
    });

    test('pets list for the model', () {
      expect(buildPetsListContext(pets), "ANIMAUX DE L'UTILISATEUR : Nala (lapin), Rex (chien)");
    });

    test('every function marks its required fields for the model', () {
      final declarations = assistantTools.single.toJson()['functionDeclarations']! as List;
      final appointment = declarations.cast<Map>().firstWhere((d) => d['name'] == 'creer_rendez_vous');
      expect((appointment['parameters'] as Map)['required'], ['animal', 'titre', 'type', 'date', 'heure']);
    });
  });
}
