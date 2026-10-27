import 'adoption_application.dart';
import 'adoption_enums.dart';
import 'adoption_listing.dart';

/// Un point du dossier : critère respecté (✓) ou point de vigilance (⚠).
class CompatibilityPoint {
  const CompatibilityPoint({required this.ok, required this.label, required this.detail});

  factory CompatibilityPoint.fromMap(Map<String, dynamic> data) => CompatibilityPoint(
        ok: data['ok'] as bool? ?? true,
        label: data['label'] as String? ?? '',
        detail: data['detail'] as String? ?? '',
      );

  final bool ok;
  final String label;
  final String detail;

  Map<String, dynamic> toMap() => {'ok': ok, 'label': label, 'detail': detail};
}

class CompatibilityResult {
  const CompatibilityResult(this.score, this.points);

  final int score;
  final List<CompatibilityPoint> points;
}

/// Niveau affiché sous la jauge.
enum CompatibilityLevel {
  high('Élevée'),
  medium('Moyenne'),
  low('Faible');

  const CompatibilityLevel(this.label);

  final String label;

  static CompatibilityLevel of(int score) {
    if (score >= 75) return high;
    if (score >= 50) return medium;
    return low;
  }
}

/// Pénalités du score : un seul endroit pour les ajuster.
abstract final class CompatibilityWeights {
  static const noGarden = 20;
  static const kids = 25;
  static const cats = 20;
  static const dogs = 20;
  static const energyMismatch = 15;
  static const tooLongAlone = 15;
  static const noLandlordAgreement = 30;
  static const allergies = 10;
  static const firstTime = 5;
}

/// Compare les besoins de l'animal et les réponses du candidat.
///
/// Le score part de 100 et chaque incompatibilité retire des points. C'est une aide à la
/// décision pour l'annonceur : elle ne refuse jamais une candidature automatiquement.
CompatibilityResult computeCompatibility(AdoptionListing listing, ApplicationAnswers a) {
  final name = listing.name;
  var score = 100;
  final points = <CompatibilityPoint>[];

  void check(bool ok, int penalty, String label, String okDetail, String warnDetail) {
    if (!ok) score -= penalty;
    points.add(CompatibilityPoint(ok: ok, label: label, detail: ok ? okDetail : warnDetail));
  }

  if (listing.needsGarden) {
    check(a.hasGarden, CompatibilityWeights.noGarden, 'Extérieur', 'Jardin ou extérieur accessible.',
        "$name a besoin d'un extérieur, le foyer n'en a pas.");
  }

  if (a.kids > 0) {
    check(listing.goodWithKids, CompatibilityWeights.kids, 'Enfants', '$name est à l\'aise avec les enfants.',
        "$name n'est pas indiqué(e) comme compatible avec des enfants.");
  }

  if (a.cats > 0) {
    check(listing.goodWithCats, CompatibilityWeights.cats, 'Chats au foyer', '$name s\'entend avec les chats.',
        'Le foyer a déjà un chat, $name ne cohabite pas avec eux.');
  }

  if (a.dogs > 0) {
    check(listing.goodWithDogs, CompatibilityWeights.dogs, 'Chiens au foyer', '$name s\'entend avec les chiens.',
        'Le foyer a déjà un chien, $name ne cohabite pas avec eux.');
  }

  final energyMismatch = (listing.energy == EnergyLevel.high && a.lifestyle == Lifestyle.calm) ||
      (listing.energy == EnergyLevel.low && a.lifestyle == Lifestyle.dynamic);
  check(!energyMismatch, CompatibilityWeights.energyMismatch, 'Rythme de vie',
      'Ambiance du foyer adaptée à son énergie.', "Énergie de $name et rythme du foyer peu compatibles.");

  check(a.hoursAlone <= listing.okAloneHours, CompatibilityWeights.tooLongAlone, 'Temps seul',
      'Absences compatibles (${a.hoursAloneLabel}).',
      '$name supporte ${listing.okAloneHours} h seul(e), le candidat est absent ${a.hoursAloneLabel}.');

  if (a.tenure == Tenure.tenant) {
    check(a.landlordAgrees, CompatibilityWeights.noLandlordAgreement, 'Logement',
        'Locataire avec accord du propriétaire.', "Locataire sans accord confirmé du propriétaire.");
  }

  if (a.allergies) {
    score -= CompatibilityWeights.allergies;
    points.add(const CompatibilityPoint(
        ok: false, label: 'Allergies', detail: 'Allergies signalées dans le foyer.'));
  }

  if (a.experience == Experience.first) {
    score -= CompatibilityWeights.firstTime;
    points.add(CompatibilityPoint(
        ok: false,
        label: 'Expérience',
        detail: 'Premier animal de ce type : prévoir des conseils d\'intégration.'));
  } else {
    points.add(CompatibilityPoint(ok: true, label: 'Expérience', detail: a.experience.hint));
  }

  return CompatibilityResult(score.clamp(0, 100), points);
}
