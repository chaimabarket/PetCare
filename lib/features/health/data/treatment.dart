import 'package:cloud_firestore/cloud_firestore.dart';

import 'health_format.dart';

/// Statut affiché sur la carte (maquette « Traitements ») : En cours, Terminé, Arrêté.
enum TreatmentStatus {
  active('En cours'),
  completed('Terminé'),
  stopped('Arrêté');

  const TreatmentStatus(this.label);

  final String label;
}

/// Forme du médicament : choisit l'icône de la posologie et le libellé du bouton de prise.
enum TreatmentForm {
  tablet('comprime', 'Comprimé', 'Noter la prise'),
  drops('gouttes', 'Gouttes / collyre', "Noter l'instillation"),
  injection('injection', 'Injection', "Noter l'injection"),
  spotOn('pipette', 'Pipette', "Noter l'application"),
  other('autre', 'Autre', 'Noter la prise');

  const TreatmentForm(this.firestoreValue, this.label, this.logLabel);

  final String firestoreValue;
  final String label;
  final String logLabel;

  static TreatmentForm fromFirestore(String? value) =>
      values.firstWhere((f) => f.firestoreValue == value, orElse: () => TreatmentForm.other);
}

/// Catégories proposées dans « Nouveau traitement » (texte libre accepté aussi).
const treatmentCategories = [
  'Antibiotique',
  'Antiparasitaire',
  'Vermifuge',
  'Anti-inflammatoire',
  'Soin des yeux',
  'Anti-infectieux',
  'Autre',
];

/// Un traitement prescrit, stocké dans `pets/{petId}/treatments/{id}`.
///
/// Le statut n'est pas stocké : « Arrêté » vient de `stoppedAt`, « Terminé » de la date de fin.
class Treatment {
  const Treatment({
    required this.id,
    required this.category,
    required this.name,
    required this.posology,
    required this.startDate,
    required this.endDate,
    this.subtitle,
    this.form = TreatmentForm.other,
    this.practitioner,
    this.doseTimes = const [],
    this.doses = const [],
    this.stoppedAt,
    this.stopReason,
    this.renewalAt,
    this.scheduleNote,
  });

  factory Treatment.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const {};
    final start = (data['startDate'] as Timestamp?)?.toDate() ?? DateTime.now();
    return Treatment(
      id: doc.id,
      category: data['category'] as String? ?? 'Autre',
      name: data['name'] as String? ?? '',
      subtitle: data['subtitle'] as String?,
      form: TreatmentForm.fromFirestore(data['form'] as String?),
      practitioner: data['practitioner'] as String?,
      posology: data['posology'] as String? ?? '',
      startDate: start,
      endDate: (data['endDate'] as Timestamp?)?.toDate() ?? start,
      doseTimes: [for (final t in (data['doseTimes'] as List?) ?? const []) if (t is String) t],
      doses: [
        for (final t in (data['doses'] as List?) ?? const [])
          if (t is Timestamp) t.toDate(),
      ]..sort(),
      stoppedAt: (data['stoppedAt'] as Timestamp?)?.toDate(),
      stopReason: data['stopReason'] as String?,
      renewalAt: (data['renewalAt'] as Timestamp?)?.toDate(),
      scheduleNote: data['scheduleNote'] as String?,
    );
  }

  final String id;
  final String category;
  final String name;

  /// Principe actif ou forme : « Amoxicilline + Acide Clavulanique ».
  final String? subtitle;
  final TreatmentForm form;
  final String? practitioner;

  /// Posologie telle que prescrite par le vétérinaire (texte libre, jamais calculée).
  final String posology;
  final DateTime startDate;
  final DateTime endDate;

  /// Heures de prise prévues, « 08:00 », « 20:00 ».
  final List<String> doseTimes;

  /// Prises notées par le propriétaire.
  final List<DateTime> doses;
  final DateTime? stoppedAt;
  final String? stopReason;
  final DateTime? renewalAt;

  /// « Protocole préventif semestriel ».
  final String? scheduleNote;

  TreatmentStatus statusAt(DateTime now) {
    if (stoppedAt != null) return TreatmentStatus.stopped;
    return dayOf(now).isAfter(dayOf(endDate)) ? TreatmentStatus.completed : TreatmentStatus.active;
  }

  TreatmentStatus get status => statusAt(DateTime.now());

  /// Durée prévue en jours (début et fin compris).
  int get totalDays => dayOf(endDate).difference(dayOf(startDate)).inDays + 1;

  bool get isSingleDay => totalDays <= 1;

  /// Jour en cours du traitement (1 à [totalDays]).
  int currentDay(DateTime now) =>
      (dayOf(now).difference(dayOf(startDate)).inDays + 1).clamp(0, totalDays);

  /// Jours effectués avant l'arrêt.
  int get daysDoneBeforeStop =>
      stoppedAt == null ? 0 : (dayOf(stoppedAt!).difference(dayOf(startDate)).inDays + 1).clamp(0, totalDays);

  /// Prochaine prise prévue : la première heure de prise à venir qui n'a pas déjà été notée
  /// (une prise notée jusqu'à 3 h avant ou après l'heure prévue compte pour ce créneau).
  DateTime? nextDose(DateTime now) {
    if (statusAt(now) != TreatmentStatus.active || doseTimes.isEmpty) return null;
    final times = [
      for (final t in doseTimes) ?_parseTime(t),
    ]..sort((a, b) => (a.$1 * 60 + a.$2).compareTo(b.$1 * 60 + b.$2));
    final first = dayOf(now).isBefore(dayOf(startDate)) ? dayOf(startDate) : dayOf(now);
    for (var day = first; !day.isAfter(dayOf(endDate)); day = day.add(const Duration(days: 1))) {
      for (final (hour, minute) in times) {
        final slot = DateTime(day.year, day.month, day.day, hour, minute);
        if (slot.isBefore(now.subtract(const Duration(hours: 1)))) continue;
        final covered = doses.any((d) => d.difference(slot).inMinutes.abs() <= 180);
        if (!covered) return slot;
      }
    }
    return null;
  }

  static (int, int)? _parseTime(String value) {
    final parts = value.split(':');
    if (parts.length != 2) return null;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null || hour > 23 || minute > 59) return null;
    return (hour, minute);
  }
}
