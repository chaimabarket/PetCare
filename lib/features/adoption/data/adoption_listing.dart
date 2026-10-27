import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';

import 'adoption_enums.dart';

/// Annonce d'adoption, stockée dans `adoptions/{id}`.
///
/// La photo de couverture est copiée dans le document pour afficher le fil sans requête
/// supplémentaire ; toutes les photos sont dans `adoptions/{id}/photos/{index}`.
class AdoptionListing {
  const AdoptionListing({
    required this.id,
    required this.publisherId,
    required this.publisherName,
    required this.publisherIsShelter,
    required this.name,
    required this.species,
    required this.breed,
    required this.sex,
    required this.birthDate,
    required this.size,
    required this.city,
    required this.title,
    required this.story,
    required this.needs,
    required this.conditions,
    required this.badges,
    required this.goodWithKids,
    required this.goodWithCats,
    required this.goodWithDogs,
    required this.needsGarden,
    required this.energy,
    required this.okAloneHours,
    required this.status,
    required this.photoCount,
    this.cover,
    this.acceptedApplicationId,
    this.adopterId,
    this.adopterName,
    this.createdAt,
    this.adoptedAt,
  });

  factory AdoptionListing.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const {};
    final cover = data['cover'] as String?;
    return AdoptionListing(
      id: doc.id,
      publisherId: data['publisherId'] as String? ?? '',
      publisherName: data['publisherName'] as String? ?? '',
      publisherIsShelter: data['publisherIsShelter'] as bool? ?? false,
      name: data['name'] as String? ?? '',
      species: Species.fromFirestore(data['species'] as String?),
      breed: data['breed'] as String? ?? '',
      sex: Sex.fromFirestore(data['sex'] as String?),
      birthDate: (data['birthDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      size: PetSize.fromFirestore(data['size'] as String?),
      city: data['city'] as String? ?? '',
      title: data['title'] as String? ?? '',
      story: data['story'] as String? ?? '',
      needs: data['needs'] as String? ?? '',
      conditions: data['conditions'] as String? ?? '',
      badges: [
        for (final b in (data['badges'] as List<dynamic>? ?? const [])) ?PersonalityBadge.tryParse(b as String?),
      ],
      goodWithKids: data['goodWithKids'] as bool? ?? false,
      goodWithCats: data['goodWithCats'] as bool? ?? false,
      goodWithDogs: data['goodWithDogs'] as bool? ?? false,
      needsGarden: data['needsGarden'] as bool? ?? false,
      energy: EnergyLevel.fromFirestore(data['energy'] as String?),
      okAloneHours: (data['okAloneHours'] as num?)?.toInt() ?? 4,
      status: ListingStatus.fromFirestore(data['status'] as String?),
      photoCount: (data['photoCount'] as num?)?.toInt() ?? 0,
      cover: cover == null ? null : base64Decode(cover),
      acceptedApplicationId: data['acceptedApplicationId'] as String?,
      adopterId: data['adopterId'] as String?,
      adopterName: data['adopterName'] as String?,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      adoptedAt: (data['adoptedAt'] as Timestamp?)?.toDate(),
    );
  }

  final String id;
  final String publisherId;
  final String publisherName;
  final bool publisherIsShelter;
  final String name;
  final Species species;
  final String breed;
  final Sex sex;
  final DateTime birthDate;
  final PetSize size;
  final String city;
  final String title;
  final String story;
  final String needs;
  final String conditions;
  final List<PersonalityBadge> badges;

  // Compatibilité du foyer : sert au score des candidatures.
  final bool goodWithKids;
  final bool goodWithCats;
  final bool goodWithDogs;
  final bool needsGarden;
  final EnergyLevel energy;
  final int okAloneHours;

  final ListingStatus status;
  final int photoCount;
  final Uint8List? cover;
  final String? acceptedApplicationId;
  final String? adopterId;
  final String? adopterName;
  final DateTime? createdAt;
  final DateTime? adoptedAt;

  int get ageInMonths {
    final now = DateTime.now();
    final months = (now.year - birthDate.year) * 12 + now.month - birthDate.month - (now.day < birthDate.day ? 1 : 0);
    return months < 0 ? 0 : months;
  }

  AgeGroup get ageGroup => AgeGroup.ofMonths(ageInMonths);

  /// « 8 mois », « 1 an », « 3 ans ».
  String get ageLabel {
    final months = ageInMonths;
    if (months < 12) return '${months == 0 ? 1 : months} mois';
    final years = months ~/ 12;
    return years == 1 ? '1 an' : '$years ans';
  }

  /// Tag « Adopte-moi » : en ligne depuis plus de 30 jours ou besoin de soins spécifiques.
  bool get isUrgent {
    if (status != ListingStatus.available) return false;
    if (badges.contains(PersonalityBadge.specialCare)) return true;
    final created = createdAt;
    return created != null && DateTime.now().difference(created).inDays > 30;
  }

  int get daysOnline => createdAt == null ? 0 : DateTime.now().difference(createdAt!).inDays;
}

/// Données saisies dans le formulaire « Publier une annonce ».
class ListingDraft {
  ListingDraft({
    this.name = '',
    this.species = Species.cat,
    this.breed = '',
    this.sex = Sex.female,
    DateTime? birthDate,
    this.size = PetSize.medium,
    this.city = '',
    this.title = '',
    this.story = '',
    this.needs = '',
    this.conditions = '',
    Set<PersonalityBadge>? badges,
    this.goodWithKids = false,
    this.goodWithCats = false,
    this.goodWithDogs = false,
    this.needsGarden = false,
    this.energy = EnergyLevel.medium,
    this.okAloneHours = 4,
    List<Uint8List>? photos,
  })  : birthDate = birthDate ?? DateTime.now().subtract(const Duration(days: 365)),
        badges = badges ?? {},
        photos = photos ?? [];

  factory ListingDraft.fromListing(AdoptionListing l, List<Uint8List> photos) => ListingDraft(
        name: l.name,
        species: l.species,
        breed: l.breed,
        sex: l.sex,
        birthDate: l.birthDate,
        size: l.size,
        city: l.city,
        title: l.title,
        story: l.story,
        needs: l.needs,
        conditions: l.conditions,
        badges: l.badges.toSet(),
        goodWithKids: l.goodWithKids,
        goodWithCats: l.goodWithCats,
        goodWithDogs: l.goodWithDogs,
        needsGarden: l.needsGarden,
        energy: l.energy,
        okAloneHours: l.okAloneHours,
        photos: photos,
      );

  String name;
  Species species;
  String breed;
  Sex sex;
  DateTime birthDate;
  PetSize size;
  String city;
  String title;
  String story;
  String needs;
  String conditions;
  Set<PersonalityBadge> badges;
  bool goodWithKids;
  bool goodWithCats;
  bool goodWithDogs;
  bool needsGarden;
  EnergyLevel energy;
  int okAloneHours;

  /// Photos compressées (JPEG), la première sert de couverture.
  List<Uint8List> photos;

  Map<String, dynamic> toFirestore() => {
        'name': name.trim(),
        'species': species.firestoreValue,
        'breed': breed.trim(),
        'sex': sex.firestoreValue,
        'birthDate': Timestamp.fromDate(birthDate),
        'size': size.firestoreValue,
        'city': city.trim(),
        'title': title.trim(),
        'story': story.trim(),
        'needs': needs.trim(),
        'conditions': conditions.trim(),
        'badges': [for (final b in badges) b.firestoreValue],
        'goodWithKids': goodWithKids,
        'goodWithCats': goodWithCats,
        'goodWithDogs': goodWithDogs,
        'needsGarden': needsGarden,
        'energy': energy.firestoreValue,
        'okAloneHours': okAloneHours,
        'photoCount': photos.length,
        'cover': photos.isEmpty ? null : base64Encode(photos.first),
      };
}
