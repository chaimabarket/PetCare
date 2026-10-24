import 'package:cloud_firestore/cloud_firestore.dart';

/// Espèces proposées dans le formulaire (maquette « Ajouter un animal »). Libellés : voir `speciesLabel`.
enum PetSpecies {
  dog('dog', '🐕'),
  cat('cat', '🐈'),
  rabbit('rabbit', '🐇'),
  rodent('rodent', '🐹'),
  bird('bird', '🦜'),
  other('other', '🐾');

  const PetSpecies(this.code, this.emoji);

  final String code;
  final String emoji;

  static PetSpecies fromCode(String? code) =>
      values.firstWhere((s) => s.code == code, orElse: () => PetSpecies.other);
}

enum PetSex {
  male('male', '♂'),
  female('female', '♀');

  const PetSex(this.code, this.symbol);

  final String code;
  final String symbol;

  static PetSex fromCode(String? code) => code == 'female' ? PetSex.female : PetSex.male;
}

enum PetStatus {
  active('active'),
  archived('archived');

  const PetStatus(this.code);

  final String code;

  static PetStatus fromCode(String? code) => code == 'archived' ? PetStatus.archived : PetStatus.active;
}

/// Contact de confiance affiché sur la fiche (vétérinaire traitant ou urgence).
class PetContact {
  const PetContact({required this.name, required this.phone, this.detail = '', this.emergency = false});

  factory PetContact.fromMap(Map<String, dynamic> map) => PetContact(
        name: map['name'] as String? ?? '',
        detail: map['detail'] as String? ?? '',
        phone: map['phone'] as String? ?? '',
        emergency: map['emergency'] as bool? ?? false,
      );

  final String name;
  final String detail;
  final String phone;
  final bool emergency;

  Map<String, dynamic> toMap() => {'name': name, 'detail': detail, 'phone': phone, 'emergency': emergency};
}

/// Profil privé d'un animal, stocké dans `pets/{petId}`.
///
/// Le poids est dans la sous-collection `weights` et les photos dans `photos` (règle RG-08 : pas de
/// poids ni de donnée médicale dupliquée dans la fiche).
class Pet {
  const Pet({
    required this.id,
    required this.ownerId,
    required this.name,
    required this.species,
    required this.sex,
    this.breed,
    this.birthDate,
    this.birthDateEstimated = false,
    this.chipNumber,
    this.sterilized = false,
    this.notes,
    this.status = PetStatus.active,
    this.favorite = false,
    this.contacts = const [],
    this.createdAt,
  });

  factory Pet.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const {};
    return Pet(
      id: doc.id,
      ownerId: data['ownerId'] as String? ?? '',
      name: data['name'] as String? ?? '',
      species: PetSpecies.fromCode(data['species'] as String?),
      sex: PetSex.fromCode(data['sex'] as String?),
      breed: data['breed'] as String?,
      birthDate: (data['birthDate'] as Timestamp?)?.toDate(),
      birthDateEstimated: data['birthDateEstimated'] as bool? ?? false,
      chipNumber: data['chipNumber'] as String?,
      sterilized: data['sterilized'] as bool? ?? false,
      notes: data['notes'] as String?,
      status: PetStatus.fromCode(data['status'] as String?),
      favorite: data['favorite'] as bool? ?? false,
      contacts: [
        for (final c in (data['contacts'] as List<dynamic>? ?? const []))
          PetContact.fromMap(Map<String, dynamic>.from(c as Map)),
      ],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  final String id;
  final String ownerId;
  final String name;
  final PetSpecies species;
  final PetSex sex;
  final String? breed;
  final DateTime? birthDate;
  final bool birthDateEstimated;

  /// Numéro de puce ou tatouage (15 chiffres I-CAD). Privé : jamais affiché en entier hors de la fiche.
  final String? chipNumber;
  final bool sterilized;
  final String? notes;
  final PetStatus status;
  final bool favorite;
  final List<PetContact> contacts;
  final DateTime? createdAt;

  bool get isArchived => status == PetStatus.archived;
  bool get isFemale => sex == PetSex.female;
  bool get hasBreed => breed != null && breed!.trim().isNotEmpty;
  bool get hasChip => chipNumber != null && chipNumber!.isNotEmpty;
}

/// Champs saisis dans le formulaire d'ajout ou de modification.
class PetDraft {
  const PetDraft({
    required this.name,
    required this.species,
    required this.sex,
    required this.birthDate,
    this.breed,
    this.birthDateEstimated = false,
    this.chipNumber,
    this.sterilized = false,
    this.notes,
  });

  final String name;
  final PetSpecies species;
  final PetSex sex;
  final DateTime birthDate;
  final String? breed;
  final bool birthDateEstimated;
  final String? chipNumber;
  final bool sterilized;
  final String? notes;

  static String? _clean(String? value) {
    final trimmed = value?.trim() ?? '';
    return trimmed.isEmpty ? null : trimmed;
  }

  Map<String, dynamic> toMap() => {
        'name': name.trim(),
        'species': species.code,
        'sex': sex.code,
        'breed': _clean(breed),
        'birthDate': Timestamp.fromDate(DateTime(birthDate.year, birthDate.month, birthDate.day)),
        'birthDateEstimated': birthDateEstimated,
        'chipNumber': _clean(chipNumber),
        'sterilized': sterilized,
        'notes': _clean(notes),
      };
}
