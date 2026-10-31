import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';

import 'health_format.dart';

/// Ce que le carnet affiche de la fiche animal du module 1 (`pets/{id}`).
///
/// Le module Santé ne modifie jamais la fiche : il la lit seulement pour l'en-tête
/// (photo, nom, race, âge, numéro d'identification).
class HealthPet {
  const HealthPet({
    required this.id,
    required this.name,
    this.species,
    this.breed,
    this.birthDate,
    this.chipNumber,
    this.photo,
  });

  factory HealthPet.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc, {Uint8List? photo}) {
    final data = doc.data() ?? const {};
    return HealthPet(
      id: doc.id,
      name: data['name'] as String? ?? 'Mon animal',
      species: data['species'] as String?,
      breed: data['breed'] as String?,
      birthDate: (data['birthDate'] as Timestamp?)?.toDate(),
      chipNumber: data['chipNumber'] as String?,
      photo: photo,
    );
  }

  final String id;
  final String name;
  final String? species;
  final String? breed;
  final DateTime? birthDate;

  /// Numéro d'identification (puce, 15 chiffres), affiché « ICAD ».
  final String? chipNumber;

  /// Première photo de la galerie, ou null.
  final Uint8List? photo;

  String get speciesText => speciesLabel(species);

  /// « Golden Retriever • 4 ans et 10 mois » (ou sans la race / l'âge s'ils sont inconnus).
  String breedAndAge({bool shortAge = false}) => [
        breed?.trim().isNotEmpty == true ? breed!.trim() : speciesText,
        if (birthDate != null) formatPetAge(birthDate!, short: shortAge),
      ].join(' • ');
}
