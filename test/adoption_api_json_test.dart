import 'package:flutter_test/flutter_test.dart';
import 'package:projet_flutter/features/adoption/data/adoption_application.dart';
import 'package:projet_flutter/features/adoption/data/adoption_enums.dart';
import 'package:projet_flutter/features/adoption/data/adoption_listing.dart';

void main() {
  test("une annonce renvoyée par l'API REST se lit comme une annonce Firestore", () {
    final listing = AdoptionListing.fromJson({
      'id': 'a1',
      'publisherId': 'u1',
      'publisherName': 'Refuge',
      'name': 'Nala',
      'species': 'chat',
      'sex': 'femelle',
      'size': 'petit',
      'energy': 'faible',
      'status': 'disponible',
      'birthDate': '2024-01-01T00:00:00Z',
      'createdAt': '2026-10-21T15:26:44.974Z',
      'badges': ['calme', 'inconnu'],
      'cover': null,
      'photoCount': 0,
    });

    expect(listing.id, 'a1');
    expect(listing.species, Species.cat);
    expect(listing.status, ListingStatus.available);
    expect(listing.badges, [PersonalityBadge.calm]);
    expect(listing.birthDate.year, 2024);
    expect(listing.createdAt, isNotNull);
  });

  test("une candidature renvoyée par l'API REST garde ses réponses, son score et ses points", () {
    final app = AdoptionApplication.fromJson({
      'id': 'a1_u2',
      'listingId': 'a1',
      'applicantId': 'u2',
      'status': 'en_etude',
      'score': 75,
      'createdAt': '2026-10-21T15:26:44.974Z',
      'answers': {'housing': 'maison', 'kids': 2, 'kidsAges': ['0 - 5 ans'], 'lifestyle': 'dynamique'},
      'points': [
        {'ok': false, 'label': 'Enfants', 'detail': 'Pas compatible'},
      ],
    });

    expect(app.status, ApplicationStatus.reviewing);
    expect(app.score, 75);
    expect(app.answers.kids, 2);
    expect(app.answers.lifestyle, Lifestyle.dynamic);
    expect(app.points.single.ok, isFalse);
  });
}
