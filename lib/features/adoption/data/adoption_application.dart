import 'package:cloud_firestore/cloud_firestore.dart';

import 'adoption_enums.dart';
import 'adoption_listing.dart' show toDate;
import 'compatibility.dart';

/// Réponses du questionnaire d'adoption (4 étapes du formulaire).
class ApplicationAnswers {
  ApplicationAnswers({
    this.housing = HousingType.apartment,
    this.hasGarden = false,
    this.tenure = Tenure.owner,
    this.landlordAgrees = false,
    this.city = '',
    this.adults = 1,
    this.kids = 0,
    Set<String>? kidsAges,
    this.cats = 0,
    this.dogs = 0,
    this.otherPets = 0,
    this.allergies = false,
    this.hoursAlone = 4,
    this.lifestyle = Lifestyle.calm,
    this.experience = Experience.some,
    this.motivation = '',
  }) : kidsAges = kidsAges ?? {};

  factory ApplicationAnswers.fromMap(Map<String, dynamic> data) => ApplicationAnswers(
        housing: HousingType.fromFirestore(data['housing'] as String?),
        hasGarden: data['hasGarden'] as bool? ?? false,
        tenure: Tenure.fromFirestore(data['tenure'] as String?),
        landlordAgrees: data['landlordAgrees'] as bool? ?? false,
        city: data['city'] as String? ?? '',
        adults: (data['adults'] as num?)?.toInt() ?? 1,
        kids: (data['kids'] as num?)?.toInt() ?? 0,
        kidsAges: {for (final a in (data['kidsAges'] as List<dynamic>? ?? const [])) a as String},
        cats: (data['cats'] as num?)?.toInt() ?? 0,
        dogs: (data['dogs'] as num?)?.toInt() ?? 0,
        otherPets: (data['otherPets'] as num?)?.toInt() ?? 0,
        allergies: data['allergies'] as bool? ?? false,
        hoursAlone: (data['hoursAlone'] as num?)?.toInt() ?? 4,
        lifestyle: Lifestyle.fromFirestore(data['lifestyle'] as String?),
        experience: Experience.fromFirestore(data['experience'] as String?),
        motivation: data['motivation'] as String? ?? '',
      );

  HousingType housing;
  bool hasGarden;
  Tenure tenure;
  bool landlordAgrees;
  String city;
  int adults;
  int kids;
  Set<String> kidsAges;
  int cats;
  int dogs;
  int otherPets;
  bool allergies;
  int hoursAlone;
  Lifestyle lifestyle;
  Experience experience;
  String motivation;

  int get currentPets => cats + dogs + otherPets;

  Map<String, dynamic> toMap() => {
        'housing': housing.firestoreValue,
        'hasGarden': hasGarden,
        'tenure': tenure.firestoreValue,
        'landlordAgrees': tenure == Tenure.tenant && landlordAgrees,
        'city': city.trim(),
        'adults': adults,
        'kids': kids,
        'kidsAges': kids == 0 ? <String>[] : kidsAges.toList(),
        'cats': cats,
        'dogs': dogs,
        'otherPets': otherPets,
        'allergies': allergies,
        'hoursAlone': hoursAlone,
        'lifestyle': lifestyle.firestoreValue,
        'experience': experience.firestoreValue,
        'motivation': motivation.trim(),
      };

  // Phrases du récapitulatif et du dossier.
  String get housingSummary => '${housing.label}${hasGarden ? ' avec jardin ou extérieur' : ', sans jardin'}';

  String get tenureSummary => tenure == Tenure.owner
      ? 'Propriétaire'
      : 'Locataire (${landlordAgrees ? 'accord du propriétaire' : 'accord du propriétaire non confirmé'})';

  String get familySummary {
    final a = '$adults adulte${adults > 1 ? 's' : ''}';
    if (kids == 0) return '$a, sans enfant';
    return '$a, $kids enfant${kids > 1 ? 's' : ''}';
  }

  String get petsSummary {
    final parts = [
      if (cats > 0) '$cats chat${cats > 1 ? 's' : ''}',
      if (dogs > 0) '$dogs chien${dogs > 1 ? 's' : ''}',
      if (otherPets > 0) '$otherPets autre${otherPets > 1 ? 's' : ''}',
    ];
    return parts.isEmpty ? 'Aucun autre animal' : parts.join(', ');
  }

  String get hoursAloneLabel => hoursAlone >= 10 ? '10 h et plus / jour' : '$hoursAlone h / jour';
}

/// Candidature d'adoption, stockée dans `adoptionApplications/{listingId}_{applicantId}`.
///
/// L'identifiant composé garantit une seule candidature par personne et par annonce.
class AdoptionApplication {
  const AdoptionApplication({
    required this.id,
    required this.listingId,
    required this.listingName,
    required this.listingSpecies,
    required this.publisherId,
    required this.publisherName,
    required this.applicantId,
    required this.applicantName,
    required this.answers,
    required this.score,
    required this.points,
    required this.status,
    this.refusalReason,
    this.createdAt,
    this.updatedAt,
  });

  factory AdoptionApplication.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) =>
      AdoptionApplication.fromData(doc.id, doc.data() ?? const {});

  /// Candidature renvoyée par l'API REST : mêmes champs, les dates sont des textes ISO.
  factory AdoptionApplication.fromJson(Map<String, dynamic> json) =>
      AdoptionApplication.fromData(json['id'] as String? ?? '', json);

  factory AdoptionApplication.fromData(String id, Map<String, dynamic> data) {
    return AdoptionApplication(
      id: id,
      listingId: data['listingId'] as String? ?? '',
      listingName: data['listingName'] as String? ?? '',
      listingSpecies: Species.fromFirestore(data['listingSpecies'] as String?),
      publisherId: data['publisherId'] as String? ?? '',
      publisherName: data['publisherName'] as String? ?? '',
      applicantId: data['applicantId'] as String? ?? '',
      applicantName: data['applicantName'] as String? ?? '',
      answers: ApplicationAnswers.fromMap(Map<String, dynamic>.from(data['answers'] as Map? ?? const {})),
      score: (data['score'] as num?)?.toInt() ?? 0,
      points: [
        for (final p in (data['points'] as List<dynamic>? ?? const []))
          CompatibilityPoint.fromMap(Map<String, dynamic>.from(p as Map)),
      ],
      status: ApplicationStatus.fromFirestore(data['status'] as String?),
      refusalReason: data['refusalReason'] as String?,
      createdAt: toDate(data['createdAt']),
      updatedAt: toDate(data['updatedAt']),
    );
  }

  static String idFor(String listingId, String applicantId) => '${listingId}_$applicantId';

  final String id;
  final String listingId;
  final String listingName;
  final Species listingSpecies;
  final String publisherId;
  final String publisherName;
  final String applicantId;
  final String applicantName;
  final ApplicationAnswers answers;

  /// Score de compatibilité 0-100, visible uniquement côté annonceur.
  final int score;
  final List<CompatibilityPoint> points;
  final ApplicationStatus status;
  final String? refusalReason;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  /// Numéro de dossier affiché (ex. « AD-84920 »).
  String get reference {
    // Calcul stable (contrairement à hashCode) pour afficher le même numéro sur le web et Android.
    var hash = 0;
    for (final unit in id.codeUnits) {
      hash = (hash * 31 + unit) % 100000;
    }
    return 'AD-${hash.toString().padLeft(5, '0')}';
  }
}
