import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:projet_flutter/features/adoption/data/adoption_application.dart';
import 'package:projet_flutter/features/adoption/data/adoption_enums.dart';
import 'package:projet_flutter/features/adoption/data/adoption_filters.dart';
import 'package:projet_flutter/features/adoption/data/adoption_listing.dart';
import 'package:projet_flutter/features/adoption/data/compatibility.dart';

/// Annonce de test construite comme si elle venait de Firestore.
AdoptionListing listing({
  String name = 'Nala',
  Species species = Species.cat,
  bool goodWithKids = true,
  bool goodWithCats = true,
  bool goodWithDogs = false,
  bool needsGarden = false,
  EnergyLevel energy = EnergyLevel.low,
  int okAloneHours = 6,
  String city = 'Tunis',
  List<PersonalityBadge> badges = const [PersonalityBadge.calm],
  DateTime? birthDate,
  DateTime? createdAt,
  ListingStatus status = ListingStatus.available,
}) {
  return AdoptionListing(
    id: 'l1',
    publisherId: 'p1',
    publisherName: 'Refuge Les Amis',
    publisherIsShelter: true,
    name: name,
    species: species,
    breed: 'Européen',
    sex: Sex.female,
    birthDate: birthDate ?? DateTime.now().subtract(const Duration(days: 800)),
    size: PetSize.medium,
    city: city,
    title: 'Douce $name',
    story: '',
    needs: '',
    conditions: '',
    badges: badges,
    goodWithKids: goodWithKids,
    goodWithCats: goodWithCats,
    goodWithDogs: goodWithDogs,
    needsGarden: needsGarden,
    energy: energy,
    okAloneHours: okAloneHours,
    status: status,
    photoCount: 0,
    createdAt: createdAt ?? DateTime.now(),
  );
}

void main() {
  group('computeCompatibility', () {
    test('foyer idéal : 100 %', () {
      final result = computeCompatibility(listing(), ApplicationAnswers(lifestyle: Lifestyle.calm, hoursAlone: 4));
      expect(result.score, 100);
      expect(result.points.every((p) => p.ok), isTrue);
    });

    test('chaque incompatibilité retire ses points', () {
      final result = computeCompatibility(
        listing(goodWithKids: false, needsGarden: true, energy: EnergyLevel.high, okAloneHours: 2),
        ApplicationAnswers(kids: 1, hasGarden: false, lifestyle: Lifestyle.calm, hoursAlone: 8),
      );
      final expected = 100 -
          CompatibilityWeights.noGarden -
          CompatibilityWeights.kids -
          CompatibilityWeights.energyMismatch -
          CompatibilityWeights.tooLongAlone;
      expect(result.score, expected);
      expect(result.points.where((p) => !p.ok).length, 4);
    });

    test('locataire sans accord du propriétaire', () {
      final result = computeCompatibility(listing(), ApplicationAnswers(tenure: Tenure.tenant, landlordAgrees: false));
      expect(result.score, 100 - CompatibilityWeights.noLandlordAgreement);
    });

    test('le score ne descend jamais sous 0', () {
      final result = computeCompatibility(
        listing(goodWithKids: false, goodWithCats: false, needsGarden: true, energy: EnergyLevel.high, okAloneHours: 0),
        ApplicationAnswers(
          kids: 2,
          cats: 1,
          dogs: 1,
          tenure: Tenure.tenant,
          allergies: true,
          experience: Experience.first,
          lifestyle: Lifestyle.calm,
          hoursAlone: 10,
        ),
      );
      expect(result.score, 0);
      expect(CompatibilityLevel.of(result.score), CompatibilityLevel.low);
    });

    test('les points survivent à un aller-retour Firestore', () {
      final point = computeCompatibility(listing(needsGarden: true), ApplicationAnswers()).points.first;
      final copy = CompatibilityPoint.fromMap(point.toMap());
      expect(copy.ok, point.ok);
      expect(copy.detail, point.detail);
    });
  });

  group('AdoptionListing', () {
    test('âge et tranche', () {
      final young = listing(birthDate: DateTime.now().subtract(const Duration(days: 250)));
      expect(young.ageGroup, AgeGroup.baby);
      expect(young.ageLabel, endsWith('mois'));
      expect(listing(birthDate: DateTime.now().subtract(const Duration(days: 3700))).ageGroup, AgeGroup.senior);
    });

    test('tag « Adopte-moi » après 30 jours ou soins spécifiques', () {
      expect(listing().isUrgent, isFalse);
      expect(listing(createdAt: DateTime.now().subtract(const Duration(days: 31))).isUrgent, isTrue);
      expect(listing(badges: const [PersonalityBadge.specialCare]).isUrgent, isTrue);
      expect(
        listing(badges: const [PersonalityBadge.specialCare], status: ListingStatus.reserved).isUrgent,
        isFalse,
      );
    });

    test('ListingDraft enregistre les badges et la date de naissance', () {
      final draft = ListingDraft(name: ' Nala ', badges: {PersonalityBadge.playful});
      final data = draft.toFirestore();
      expect(data['name'], 'Nala');
      expect(data['badges'], ['joueur']);
      expect(data['birthDate'], isA<Timestamp>());
      expect(data['cover'], isNull);
    });
  });

  group('AdoptionFilters', () {
    final all = [
      listing(name: 'Nala', city: 'Tunis'),
      listing(name: 'Rex', species: Species.dog, city: 'Sousse', badges: const [PersonalityBadge.playful]),
    ];

    test('espèce, ville et badges', () {
      expect(const AdoptionFilters(species: {Species.dog}).apply(all).single.name, 'Rex');
      expect(const AdoptionFilters(city: 'tunis').apply(all).single.name, 'Nala');
      expect(const AdoptionFilters(badges: {PersonalityBadge.playful}).apply(all).single.name, 'Rex');
    });

    test('recherche sans tenir compte des accents ni de la casse', () {
      expect(const AdoptionFilters(query: 'europeen').apply(all).length, 2);
      expect(const AdoptionFilters(query: 'SOUS').apply(all).single.name, 'Rex');
    });

    test('réinitialiser garde la recherche et les espèces', () {
      const f = AdoptionFilters(query: 'x', species: {Species.cat}, urgentOnly: true, badges: {PersonalityBadge.shy});
      final cleared = f.cleared();
      expect(cleared.query, 'x');
      expect(cleared.species, {Species.cat});
      expect(cleared.activeCount, 0);
    });
  });

  test('ApplicationAnswers : aller-retour Firestore', () {
    final answers = ApplicationAnswers(kids: 2, kidsAges: {'6 - 12 ans'}, cats: 1, motivation: ' Bonjour ');
    final copy = ApplicationAnswers.fromMap(answers.toMap());
    expect(copy.kids, 2);
    expect(copy.kidsAges, {'6 - 12 ans'});
    expect(copy.motivation, 'Bonjour');
    expect(copy.petsSummary, '1 chat');
  });
}
