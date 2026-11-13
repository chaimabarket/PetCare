import 'package:cloud_firestore/cloud_firestore.dart';

import '../../health/data/health_entry.dart';
import '../../health/data/treatment.dart';

/// Animal de l'utilisateur, lu dans `pets/{id}` (module 1), pour personnaliser les réponses.
class AssistantPet {
  const AssistantPet({
    required this.id,
    required this.name,
    required this.species,
    this.sex,
    this.breed,
    this.birthDate,
    this.sterilized,
    this.notes,
  });

  factory AssistantPet.fromFirestore(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    return AssistantPet(
      id: doc.id,
      name: data['name'] as String? ?? '',
      species: data['species'] as String? ?? 'other',
      sex: data['sex'] as String?,
      breed: data['breed'] as String?,
      birthDate: (data['birthDate'] as Timestamp?)?.toDate(),
      sterilized: data['sterilized'] as bool?,
      notes: data['notes'] as String?,
    );
  }

  final String id;
  final String name;

  /// Valeurs du module 1 : dog, cat, rabbit, rodent, bird, other.
  final String species;
  final String? sex;
  final String? breed;
  final DateTime? birthDate;
  final bool? sterilized;
  final String? notes;

  String get speciesLabel => switch (species) {
        'dog' => 'chien',
        'cat' => 'chat',
        'rabbit' => 'lapin',
        'rodent' => 'rongeur',
        'bird' => 'oiseau',
        _ => 'animal',
      };

  String get emoji => switch (species) {
        'dog' => '🐶',
        'cat' => '🐱',
        'rabbit' => '🐰',
        'rodent' => '🐹',
        'bird' => '🦜',
        _ => '🐾',
      };

  /// Âge en mois ; `null` si la date de naissance est inconnue.
  int? ageInMonths([DateTime? now]) {
    final birth = birthDate;
    if (birth == null) return null;
    final today = now ?? DateTime.now();
    final months = (today.year - birth.year) * 12 + today.month - birth.month - (today.day < birth.day ? 1 : 0);
    return months < 0 ? 0 : months;
  }

  /// « 8 mois », « 3 ans », ou `null`.
  String? ageLabel([DateTime? now]) {
    final months = ageInMonths(now);
    if (months == null) return null;
    if (months < 12) return '${months == 0 ? 1 : months} mois';
    final years = months ~/ 12;
    return years == 1 ? '1 an' : '$years ans';
  }

  bool isYoung([DateTime? now]) => (ageInMonths(now) ?? 24) < 12;

  bool isSenior([DateTime? now]) => (ageInMonths(now) ?? 24) >= 96;
}

/// Dernière pesée d'un animal (`pets/{id}/weights`).
typedef PetWeight = ({double kg, DateTime? measuredOn});

/// Animaux de l'utilisateur et leurs données utiles à l'assistant.
class AssistantPetRepository {
  AssistantPetRepository({FirebaseFirestore? firestore}) : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  /// Animaux actifs de l'utilisateur. Liste vide si le module 1 n'a pas encore de données.
  Stream<List<AssistantPet>> watchPets(String uid) => _firestore
      .collection('pets')
      .where('ownerId', isEqualTo: uid)
      .snapshots()
      .map((snap) => [
            for (final doc in snap.docs)
              if (doc.data()['status'] != 'archived' && (doc.data()['name'] as String?)?.isNotEmpty == true)
                AssistantPet.fromFirestore(doc),
          ]..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase())))
      .handleError((Object _) {});

  Future<PetWeight?> fetchLatestWeight(String petId) async {
    try {
      final snap = await _firestore
          .collection('pets')
          .doc(petId)
          .collection('weights')
          .orderBy('measuredOn', descending: true)
          .limit(1)
          .get();
      if (snap.docs.isEmpty) return null;
      final data = snap.docs.first.data();
      final kg = (data['weightKg'] as num?)?.toDouble();
      if (kg == null) return null;
      return (kg: kg, measuredOn: (data['measuredOn'] as Timestamp?)?.toDate());
    } on FirebaseException {
      return null;
    }
  }

  /// Résumé du carnet de santé (module 2), ajouté au contexte de l'assistant.
  Future<List<String>> fetchHealthSummary(String petId) async {
    try {
      final pet = _firestore.collection('pets').doc(petId);
      final results = await Future.wait([pet.collection('healthEntries').get(), pet.collection('treatments').get()]);
      return buildHealthSummary(
        entries: results[0].docs.map(HealthEntry.fromFirestore).toList(),
        treatments: results[1].docs.map(Treatment.fromFirestore).toList(),
      );
    } on FirebaseException {
      return const [];
    }
  }
}

/// Lignes courtes du carnet : allergies, dernier vaccin de chaque type, traitements en cours, dernière visite.
List<String> buildHealthSummary({
  required List<HealthEntry> entries,
  required List<Treatment> treatments,
  DateTime? now,
}) {
  final today = now ?? DateTime.now();
  String day(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  final sorted = [...entries]..sort((a, b) => b.date.compareTo(a.date));

  final allergies = [
    for (final e in sorted)
      if (e.type == HealthEntryType.allergy) 'Allergie : ${e.title}',
  ];

  final seenVaccines = <String>{};
  final vaccines = <String>[];
  for (final e in sorted.where((e) => e.type == HealthEntryType.vaccine)) {
    final name = (e.vaccineName?.trim().isNotEmpty ?? false) ? e.vaccineName!.trim() : e.title;
    if (!seenVaccines.add(name.toLowerCase())) continue;
    final next = e.nextReminderAt;
    final reminder = next == null || e.reminderDone
        ? ''
        : next.isBefore(today)
            ? ', rappel en retard depuis le ${day(next)}'
            : ', prochain rappel le ${day(next)}';
    vaccines.add('Vaccin $name : fait le ${day(e.date)}$reminder');
  }

  final ongoing = [
    for (final t in treatments)
      if (t.statusAt(today) == TreatmentStatus.active)
        'Traitement en cours : ${t.name} (${t.posology}) jusqu\'au ${day(t.endDate)}',
  ];

  final lastVisit = sorted.where((e) => e.type == HealthEntryType.visit).firstOrNull;

  return [
    ...allergies,
    ...vaccines,
    ...ongoing,
    if (lastVisit != null) 'Dernière visite : ${lastVisit.title} le ${day(lastVisit.date)}',
  ].take(10).toList();
}

/// Bloc « ANIMAL SÉLECTIONNÉ » envoyé avec chaque question : jamais de donnée sur le propriétaire.
String buildPetContext(AssistantPet pet, {PetWeight? weight, List<String> health = const [], DateTime? now}) {
  String clean(String v) => v.replaceAll(RegExp(r'\s+'), ' ').trim();
  final lines = [
    'Nom : ${clean(pet.name)}',
    'Espèce : ${pet.speciesLabel}',
    if (pet.breed != null && pet.breed!.trim().isNotEmpty) 'Race : ${clean(pet.breed!)}',
    if (pet.sex != null) 'Sexe : ${pet.sex == 'female' ? 'femelle' : 'mâle'}',
    if (pet.ageLabel(now) != null) 'Âge : ${pet.ageLabel(now)}',
    if (pet.sterilized != null) 'Stérilisé : ${pet.sterilized! ? 'oui' : 'non'}',
    if (weight != null) 'Dernier poids : ${weight.kg.toStringAsFixed(1)} kg',
    if (pet.notes != null && pet.notes!.trim().isNotEmpty) 'Notes du propriétaire : ${clean(pet.notes!)}',
    if (health.isNotEmpty) 'Carnet de santé :\n${health.map((h) => '- ${clean(h)}').join('\n')}',
  ];
  return 'ANIMAL SÉLECTIONNÉ :\n${lines.join('\n')}';
}
