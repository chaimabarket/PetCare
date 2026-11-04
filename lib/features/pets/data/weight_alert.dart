import 'pet_media.dart';

/// Alerte de poids : variation anormale entre la dernière pesée et les pesées des 90 jours précédents.
///
/// Même logique que `backend/src/pets/weight_alert.js` (cas communs : `backend/test/fixtures/weight_alert_cases.json`).
/// Ce sont des repères d'alerte, pas un diagnostic. Les sources sont listées dans [weightAlertSources].

enum WeightAlertKind { loss, gain, check }

enum WeightAlertLevel {
  /// À surveiller.
  watch,

  /// Consultez un vétérinaire rapidement.
  consult,
}

/// D'où vient un seuil : une source publiée, ou un repère PetCare (non officiel).
enum WeightAlertSource { vca, aaha, petcare }

class _Rule {
  const _Rule(this.id, this.kind, this.level, this.direction, this.percent, this.days, this.source,
      {this.percentSmall, this.adultOnly = false});

  final String id;
  final WeightAlertKind kind;
  final WeightAlertLevel level;

  /// -1 perte, 1 prise, 0 les deux.
  final int direction;
  final double percent;
  final double? percentSmall;

  /// Écart maximal, en jours, avec la pesée de référence.
  final int days;
  final WeightAlertSource source;
  final bool adultOnly;
}

/// De la plus grave à la moins grave : la première règle qui correspond est retenue.
const _rules = [
  _Rule('extreme', WeightAlertKind.check, WeightAlertLevel.consult, 0, 30, 7, WeightAlertSource.petcare),
  _Rule('loss-10', WeightAlertKind.loss, WeightAlertLevel.consult, -1, 10, 90, WeightAlertSource.vca),
  _Rule('rapid-loss', WeightAlertKind.loss, WeightAlertLevel.consult, -1, 5, 7, WeightAlertSource.petcare,
      percentSmall: 3),
  _Rule('gain-20', WeightAlertKind.gain, WeightAlertLevel.consult, 1, 20, 90, WeightAlertSource.petcare,
      adultOnly: true),
  _Rule('loss-5', WeightAlertKind.loss, WeightAlertLevel.watch, -1, 5, 30, WeightAlertSource.petcare),
  _Rule('gain-10', WeightAlertKind.gain, WeightAlertLevel.watch, 1, 10, 90, WeightAlertSource.aaha, adultOnly: true),
];

/// Au-delà, la dernière pesée est trop ancienne pour signaler un problème actuel.
const _maxAgeDays = 30;

/// Animaux plus fragiles : une perte rapide plus faible suffit.
const _smallSpecies = {'rabbit', 'rodent', 'bird'};

class WeightAlert {
  const WeightAlert({
    required this.rule,
    required this.kind,
    required this.level,
    required this.source,
    required this.percent,
    required this.days,
    required this.reference,
    required this.latest,
  });

  final String rule;
  final WeightAlertKind kind;
  final WeightAlertLevel level;
  final WeightAlertSource source;

  /// Variation en %, arrondie au dixième (toujours positive).
  final double percent;
  final int days;
  final WeightEntry reference;
  final WeightEntry latest;

  /// Identifiant de l'épisode : même règle et même pesée de référence donnent la même alerte.
  String get id => '$rule-${reference.id}';
}

int _daysBetween(DateTime from, DateTime to) => (to.difference(from).inMilliseconds / Duration.millisecondsPerDay).round();

int _ageInMonths(DateTime birth, DateTime at) {
  final b = birth.toUtc();
  final a = at.toUtc();
  final months = (a.year - b.year) * 12 + a.month - b.month;
  return a.day < b.day ? months - 1 : months;
}

/// Analyse les pesées ; renvoie l'alerte la plus grave, ou `null`.
///
/// Une prise de poids n'est signalée que chez l'adulte (un jeune animal grandit) et seulement si la dernière
/// pesée dépasse toutes les précédentes de la fenêtre (un retour au poids habituel n'est pas une prise).
WeightAlert? analyzeWeights({
  required List<WeightEntry> entries,
  required String species,
  DateTime? birthDate,
  bool archived = false,
  DateTime? now,
}) {
  if (archived) return null;
  final list = entries.where((e) => e.weightKg > 0).toList()..sort((a, b) => a.measuredOn.compareTo(b.measuredOn));
  if (list.length < 2) return null;

  final latest = list.last;
  if (_daysBetween(latest.measuredOn, now ?? DateTime.now()) > _maxAgeDays) return null;
  final young = birthDate != null && _ageInMonths(birthDate, latest.measuredOn) < 12;
  final small = _smallSpecies.contains(species);

  for (final rule in _rules) {
    if (rule.adultOnly && young) continue;
    final threshold = small && rule.percentSmall != null ? rule.percentSmall! : rule.percent;
    final window = list.sublist(0, list.length - 1).where((e) {
      final days = _daysBetween(e.measuredOn, latest.measuredOn);
      return days >= 1 && days <= rule.days;
    }).toList();
    if (rule.direction > 0 && window.any((e) => e.weightKg >= latest.weightKg)) continue;

    WeightEntry? bestRef;
    var bestMagnitude = 0.0;
    for (final ref in window) {
      final change = (latest.weightKg - ref.weightKg) / ref.weightKg * 100;
      if (rule.direction == 0 && young && change > 0) continue;
      final magnitude = rule.direction == 0 ? change.abs() : change * rule.direction;
      if (magnitude + 1e-9 < threshold) continue;
      if (bestRef == null || magnitude > bestMagnitude) {
        bestRef = ref;
        bestMagnitude = magnitude;
      }
    }
    if (bestRef != null) {
      return WeightAlert(
        rule: rule.id,
        kind: rule.kind,
        level: rule.level,
        source: rule.source,
        percent: (bestMagnitude * 10).round() / 10,
        days: _daysBetween(bestRef.measuredOn, latest.measuredOn),
        reference: bestRef,
        latest: latest,
      );
    }
  }
  return null;
}

/// « 9,4 », « 10 », « 5,5 » : au plus deux décimales, sans zéro inutile.
String _formatNumber(double value) => value.toStringAsFixed(2).replaceFirst(RegExp(r'\.?0+$'), '').replaceAll('.', ',');

/// Texte de la notification, en français comme les autres notifications (identique au backend).
({String title, String body}) weightAlertMessage(WeightAlert alert, String petName) {
  final name = petName.trim().isEmpty ? 'votre animal' : petName.trim();
  final period = '${_formatNumber(alert.percent)} % en ${alert.days} ${alert.days == 1 ? 'jour' : 'jours'}';
  final values = '(${_formatNumber(alert.reference.weightKg)} kg → ${_formatNumber(alert.latest.weightKg)} kg)';
  final fact = switch (alert.kind) {
    WeightAlertKind.loss => '$name a perdu $period $values.',
    WeightAlertKind.gain => '$name a pris $period $values.',
    WeightAlertKind.check => 'Le poids de $name a varié de $period $values : vérifiez la pesée.',
  };
  final consult = alert.level == WeightAlertLevel.consult;
  final advice =
      consult ? 'Prenez rendez-vous avec un vétérinaire.' : 'Surveillez son poids et parlez-en à votre vétérinaire.';
  return (
    title: consult ? 'Poids de $name : consultez un vétérinaire' : 'Poids de $name à surveiller',
    body: "$fact $advice Ce n'est pas un diagnostic.",
  );
}

/// Une notification par épisode (même identifiant que le backend).
String weightAlertNotificationId(String petId, WeightAlert alert) => 'poids-$petId-${alert.id}';

/// Sources des seuils, affichées dans l'application (consultées le 04/11/2026).
const weightAlertSources = [
  (
    title: 'WSAVA – Nutritional Assessment Guidelines (2011)',
    url: 'https://pmc.ncbi.nlm.nih.gov/articles/PMC11107980/',
  ),
  (
    title: 'VCA Hospitals – Abnormal weight loss in cats',
    url: 'https://vcahospitals.com/know-your-pet/abnormal-weight-loss-in-cats',
  ),
  (
    title: 'VCA Hospitals – Weight loss in dogs',
    url: 'https://vcahospitals.com/know-your-pet/weight-loss-abnormal-in-dogs',
  ),
  (
    title: 'AAHA – 2021 Nutrition and Weight Management Guidelines',
    url: 'https://www.aaha.org/resources/2021-aaha-nutrition-and-weight-management-guidelines/home/',
  ),
];
