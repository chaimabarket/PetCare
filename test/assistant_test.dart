import 'package:flutter_test/flutter_test.dart';
import 'package:projet_flutter/features/adoption/data/adoption_enums.dart';
import 'package:projet_flutter/features/adoption/data/adoption_listing.dart';
import 'package:projet_flutter/features/assistant/data/answer_parser.dart';
import 'package:projet_flutter/features/assistant/data/assistant_prompt.dart';
import 'package:projet_flutter/features/assistant/data/listing_context.dart';

AdoptionListing listing({
  String id = 'abc123',
  String name = 'Nala',
  String city = 'Tunis',
  ListingStatus status = ListingStatus.available,
}) {
  return AdoptionListing(
    id: id,
    publisherId: 'p1',
    publisherName: 'Refuge Les Amis',
    publisherIsShelter: true,
    name: name,
    species: Species.cat,
    breed: 'Européen',
    sex: Sex.female,
    birthDate: DateTime.now().subtract(const Duration(days: 800)),
    size: PetSize.small,
    city: city,
    title: 'Douce Nala',
    story: '',
    needs: '',
    conditions: '',
    badges: const [PersonalityBadge.calm, PersonalityBadge.goodWithKids],
    goodWithKids: true,
    goodWithCats: true,
    goodWithDogs: false,
    needsGarden: false,
    energy: EnergyLevel.low,
    okAloneHours: 6,
    status: status,
    photoCount: 0,
  );
}

void main() {
  group('parseAnswer', () {
    test('retire un tag connu et garde son identifiant', () {
      final a = parseAnswer('Nala est calme. [[annonce:abc123]]', {'abc123'});
      expect(a.text, 'Nala est calme.');
      expect(a.listingIds, ['abc123']);
    });

    test('ignore un animal inventé', () {
      final a = parseAnswer('Voici Rex [[annonce:fake99]]', {'abc123'});
      expect(a.text, 'Voici Rex');
      expect(a.listingIds, isEmpty);
    });

    test('garde 3 animaux maximum, sans doublon', () {
      final raw = [for (final id in ['a', 'b', 'a', 'c', 'd']) '[[annonce:$id]]'].join(' ');
      final a = parseAnswer(raw, {'a', 'b', 'c', 'd'});
      expect(a.listingIds, ['a', 'b', 'c']);
    });

    test('masque un tag en cours d\'écriture', () {
      final a = parseAnswer('Je vous propose Nala [[annon', {'abc123'}, streaming: true);
      expect(a.text, 'Je vous propose Nala');
    });
  });

  group('buildListingContext', () {
    test('une ligne par animal disponible, sans données de l\'annonceur', () {
      final context = buildListingContext([
        listing(),
        listing(id: 'r1', name: 'Rocky', status: ListingStatus.reserved),
      ]);
      expect(context, contains('id=abc123 | Nala'));
      expect(context, contains('ok enfants: oui'));
      expect(context, isNot(contains('Rocky')));
      expect(context, isNot(contains('Refuge Les Amis')));
      expect(context.split('\n'), hasLength(2));
    });

    test('nettoie les retours à la ligne', () {
      final context = buildListingContext([listing(city: 'La\nMarsa | Nord')]);
      expect(context.split('\n'), hasLength(2));
      expect(context, contains('La Marsa Nord'));
    });

    test('indique quand aucun animal n\'est disponible', () {
      expect(buildListingContext([]), contains('aucune'));
    });
  });

  group('isAdoptionQuestion', () {
    test('détecte une question d\'adoption', () {
      expect(isAdoptionQuestion("J'habite en appartement, quel chien me conviendrait ?"), isTrue);
      expect(isAdoptionQuestion('Je veux adopter un chat'), isTrue);
    });

    test('ignore une question de soins', () {
      expect(isAdoptionQuestion('Mon chat vomit depuis hier'), isFalse);
    });
  });
}
