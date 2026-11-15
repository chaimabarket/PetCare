import 'package:flutter_test/flutter_test.dart';
import 'package:projet_flutter/features/assistant/data/answer_parser.dart';
import 'package:projet_flutter/features/assistant/data/assistant_actions.dart';
import 'package:projet_flutter/features/assistant/data/assistant_pet.dart';
import 'package:projet_flutter/features/assistant/data/service_catalog.dart';
import 'package:projet_flutter/features/services/data/service_models.dart';

// Réservation d'un service par l'assistant et actions écrites en texte par le modèle.

final now = DateTime(2026, 11, 15, 10); // dimanche

const pets = [AssistantPet(id: 'r', name: 'Rocky', species: 'dog')];

const _provider = ServiceProvider(
  id: 'vet1',
  ownerId: 'vet1',
  name: 'Clinique des Oliviers',
  category: 'Vétérinaires',
  city: 'Tunis',
  description: '',
  phone: '',
  email: '',
  status: 'published',
  address: '12 rue de Marseille',
);

const _service = ProviderService(
  id: 's1',
  providerId: 'vet1',
  name: 'Consultation générale',
  category: 'Vétérinaires',
  durationMinutes: 30,
  price: 45,
  status: 'published',
);

// Ouvert seulement le lundi, 09:00-12:00.
final catalog = [
  CatalogService(
    provider: _provider,
    service: _service,
    availability: {
      1: {
        'enabled': true,
        'ranges': [
          {'start': '09:00', 'end': '12:00'},
        ],
      },
      2: {'enabled': false, 'ranges': <Object>[]},
    },
  ),
];

AssistantAction booking(Map<String, Object?> args) =>
    withServiceDetails(AssistantAction.fromCall('reserver_service', args)!, catalog);

void main() {
  group('reserver_service', () {
    test('the model cannot set price or provider; the card shows the catalog service', () {
      final a = booking({
        'animal': 'Rocky',
        'service_id': 's1',
        'date': '2026-11-16',
        'heure': '10:30',
        'prix': 1,
        'prestataire': 'Faux',
      });
      expect(a.args['prix'], 45);
      expect(checkAction(a, pets, now: now).ok, isTrue);
      expect(describeAction(a), [
        ('Prestataire', 'Clinique des Oliviers'),
        ('Prestation', 'Consultation générale'),
        ('Animal', 'Rocky'),
        ('Date', '16/11/2026'),
        ('Heure', '10:30'),
        ('Durée', '30 min'),
        ('Prix', '45 DT'),
        ('Adresse', '12 rue de Marseille, Tunis'),
      ]);
    });

    test('unknown service or missing time: a question, no card', () {
      final unknown = booking({'animal': 'Rocky', 'service_id': 'zz', 'date': '2026-11-16', 'heure': '10:30'});
      expect(checkAction(unknown, pets, now: now).error, contains('Je ne trouve pas cette prestation'));
      final noTime = booking({'animal': 'Rocky', 'service_id': 's1', 'date': '2026-11-16'});
      expect(checkAction(noTime, pets, now: now).missing, ['heure']);
    });

    test('slot: same rules as the booking form', () {
      final service = catalog.single;
      String? problem(String date, String time) =>
          bookingProblem(booking({'animal': 'Rocky', 'service_id': 's1', 'date': date, 'heure': time}), service, now: now);
      expect(problem('2026-11-16', '10:30'), isNull);
      expect(problem('2026-11-16', '10:00'),
          "10:00 n'est pas proposé chez Clinique des Oliviers le 16/11. Créneaux possibles ce jour-là : 09:00, 10:30. "
          'Lequel souhaitez-vous ?');
      expect(problem('2026-11-17', '10:30'),
          'Clinique des Oliviers est fermé le mardi (ouvert : lundi). Quel autre jour vous convient ?');
    });

    test('PRESTATIONS block and service questions', () {
      expect(
        buildServiceContext(catalog),
        'PRESTATIONS (services PetCare réservables ; heures de début possibles : ${kBookingTimes.join(', ')}, '
        'dans les horaires du prestataire) :\n'
        '- id=s1 | Consultation générale | Clinique des Oliviers (Vétérinaires, Tunis) | 30 min | 45 DT | '
        'horaires : lun 09:00-12:00 ; fermé mar, mer, jeu, ven, sam, dim',
      );
      expect(isServiceQuestion('Je veux réserver un toilettage pour Rocky'), isTrue);
      expect(isServiceQuestion('book a vet monday'), isTrue);
      expect(isServiceQuestion('Combien de croquettes pour Rocky ?'), isFalse);
    });

    test('only model fields are described to Gemini', () {
      final declarations = assistantTools.single.toJson()['functionDeclarations']! as List;
      final reservation = declarations.cast<Map>().firstWhere((d) => d['name'] == 'reserver_service');
      final properties = ((reservation['parameters'] as Map)['properties'] as Map).keys;
      expect(properties, ['animal', 'service_id', 'date', 'heure', 'notes']);
    });
  });

  group('parseAnswer: action written as text instead of a function call', () {
    test('the tag is hidden and becomes the same call as the function', () {
      final parsed = parseAnswer(
        'Vérifiez et confirmez la carte ci-dessous :\n\n[[creer_rendez-vous:Rocky|Toilettage|toilettage|2026-11-16|15:00]]',
        {},
      );
      expect(parsed.text, 'Vérifiez et confirmez la carte ci-dessous :');
      expect(parsed.textCalls.single.name, 'creer_rendez_vous');
      expect(parsed.textCalls.single.args,
          {'animal': 'Rocky', 'titre': 'Toilettage', 'type': 'toilettage', 'date': '2026-11-16', 'heure': '15:00'});
    });

    test('key=value form, unknown tag removed, reminders and listings unchanged', () {
      final parsed = parseAnswer(
        'Ok [[ajouter_pesee:poids_kg=12.5|animal=Rex]] [[supprimer:Rex]] [[rappel:Vermifuger Rex|2026-12-01]] [[annonce:a1]]',
        {'a1'},
        allowReminders: true,
        now: now,
      );
      expect(parsed.text, 'Ok');
      expect(parsed.textCalls.single.args, {'poids_kg': '12.5', 'animal': 'Rex'});
      expect(parsed.reminders, hasLength(1));
      expect(parsed.listingIds, ['a1']);
    });

    test('booking tag maps onto model fields only', () {
      final parsed = parseAnswer('[[reserver_service:Rocky|s1|2026-11-16|10:30]]', {});
      expect(parsed.textCalls.single.args, {'animal': 'Rocky', 'service_id': 's1', 'date': '2026-11-16', 'heure': '10:30'});
    });
  });
}
