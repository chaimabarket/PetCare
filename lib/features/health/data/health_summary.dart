import 'health_entry.dart';
import 'health_format.dart';
import 'treatment.dart';

/// Un vaccin rappelé dans l'onglet Santé : « à jour », « bientôt » (30 jours ou moins) ou « en retard ».
enum VaccineStatus { none, upToDate, soon, overdue }

/// Nombre de jours avant un rappel pour l'annoncer « bientôt ».
const vaccineSoonDays = 30;

/// Une prise prévue aujourd'hui l'est à cette heure ± 3 h (même règle que [Treatment.nextDose]).
const _doseToleranceMinutes = 180;

/// Rappel vaccinal pas encore fait.
class PendingVaccine {
  const PendingVaccine({required this.entryId, required this.title, required this.dueAt, this.practitioner});

  factory PendingVaccine.fromJson(Map<String, dynamic> json) => PendingVaccine(
        entryId: json['id'] as String? ?? '',
        title: (json['vaccineName'] as String?) ?? (json['title'] as String? ?? ''),
        dueAt: healthDate(json['nextReminderAt']) ?? DateTime.now(),
        practitioner: json['practitioner'] as String?,
      );

  factory PendingVaccine.fromEntry(HealthEntry e) => PendingVaccine(
        entryId: e.id,
        title: e.vaccineName ?? e.title,
        dueAt: e.nextReminderAt!,
        practitioner: e.practitioner,
      );

  final String entryId;
  final String title;
  final DateTime dueAt;
  final String? practitioner;

  VaccineStatus statusAt(DateTime now) {
    final days = dayOf(dueAt).difference(dayOf(now)).inDays;
    if (days < 0) return VaccineStatus.overdue;
    if (days <= vaccineSoonDays) return VaccineStatus.soon;
    return VaccineStatus.upToDate;
  }
}

/// Une prise prévue aujourd'hui, à cocher dans le tableau du jour.
class DoseSlot {
  const DoseSlot({
    required this.petId,
    required this.petName,
    required this.treatment,
    required this.time,
    required this.done,
  });

  final String petId;
  final String petName;
  final Treatment treatment;
  final DateTime time;
  final bool done;
}

/// Résumé santé d'un animal pour l'onglet Santé (réponse de `GET /api/health/summary`).
class PetHealthSummary {
  const PetHealthSummary({
    required this.id,
    required this.name,
    this.species,
    this.breed,
    this.archived = false,
    this.pendingVaccines = const [],
    this.lastVisitTitle,
    this.lastVisitDate,
    this.allergies = const [],
    this.activeTreatments = const [],
  });

  factory PetHealthSummary.fromJson(Map<String, dynamic> json) {
    final lastVisit = json['lastVisit'] as Map<String, dynamic>?;
    return PetHealthSummary(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      species: json['species'] as String?,
      breed: json['breed'] as String?,
      archived: json['status'] == 'archived',
      pendingVaccines: [
        for (final v in (json['pendingVaccines'] as List?) ?? const [])
          PendingVaccine.fromJson(Map<String, dynamic>.from(v as Map)),
      ]..sort((a, b) => a.dueAt.compareTo(b.dueAt)),
      lastVisitTitle: lastVisit?['title'] as String?,
      lastVisitDate: healthDate(lastVisit?['date']),
      allergies: [
        for (final a in (json['allergies'] as List?) ?? const []) (a as Map)['title'] as String? ?? '',
      ],
      activeTreatments: [
        for (final t in (json['activeTreatments'] as List?) ?? const [])
          Treatment.fromJson(Map<String, dynamic>.from(t as Map)),
      ],
    );
  }

  /// Même résumé construit à partir du carnet lu dans Firestore (serveur éteint), comme `petSummary` du backend.
  factory PetHealthSummary.fromRecords({
    required String id,
    required Map<String, dynamic> pet,
    required List<HealthEntry> entries,
    required List<Treatment> treatments,
    DateTime? now,
  }) {
    final today = now ?? DateTime.now();
    final visits = entries.where((e) => e.type == HealthEntryType.visit || e.type == HealthEntryType.exam).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    final allergies = entries.where((e) => e.type == HealthEntryType.allergy).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    return PetHealthSummary(
      id: id,
      name: pet['name'] as String? ?? '',
      species: pet['species'] as String?,
      breed: pet['breed'] as String?,
      archived: pet['status'] == 'archived',
      pendingVaccines: [for (final e in entries) if (e.hasPendingReminder) PendingVaccine.fromEntry(e)]
        ..sort((a, b) => a.dueAt.compareTo(b.dueAt)),
      lastVisitTitle: visits.firstOrNull?.title,
      lastVisitDate: visits.firstOrNull?.date,
      allergies: [for (final a in allergies) a.title],
      activeTreatments: [
        for (final t in treatments)
          if (t.stoppedAt == null && !dayOf(today).isAfter(dayOf(t.endDate).add(const Duration(days: 1)))) t,
      ],
    );
  }

  final String id;
  final String name;
  final String? species;
  final String? breed;
  final bool archived;
  final List<PendingVaccine> pendingVaccines;
  final String? lastVisitTitle;
  final DateTime? lastVisitDate;
  final List<String> allergies;
  final List<Treatment> activeTreatments;

  /// Le prochain rappel vaccinal (le plus proche, éventuellement en retard).
  PendingVaccine? get nextVaccine => pendingVaccines.firstOrNull;

  VaccineStatus vaccineStatus(DateTime now) => nextVaccine?.statusAt(now) ?? VaccineStatus.none;

  /// Traitements en cours aujourd'hui (pas arrêtés, ni terminés, ni à venir).
  List<Treatment> runningTreatments(DateTime now) => [
        for (final t in activeTreatments)
          if (t.statusAt(now) == TreatmentStatus.active && !dayOf(now).isBefore(dayOf(t.startDate))) t,
      ];

  /// Prises prévues aujourd'hui, par heure ; une prise notée à ± 3 h couvre le créneau.
  List<DoseSlot> todayDoses(DateTime now) {
    final day = dayOf(now);
    final slots = <DoseSlot>[];
    for (final t in runningTreatments(now)) {
      for (final value in t.doseTimes) {
        final parts = value.split(':');
        final hour = int.tryParse(parts.first);
        final minute = parts.length == 2 ? int.tryParse(parts[1]) : null;
        if (hour == null || minute == null) continue;
        final time = DateTime(day.year, day.month, day.day, hour, minute);
        final done = t.doses.any((d) => d.difference(time).inMinutes.abs() <= _doseToleranceMinutes);
        slots.add(DoseSlot(petId: id, petName: name, treatment: t, time: time, done: done));
      }
    }
    return slots..sort((a, b) => a.time.compareTo(b.time));
  }

  /// Ordre des cartes : rappel en retard (3), prises à faire aujourd'hui (2), rappel bientôt (1), rien (0).
  int actionScore(DateTime now) {
    final vaccine = vaccineStatus(now);
    if (vaccine == VaccineStatus.overdue) return 3;
    if (todayDoses(now).any((s) => !s.done)) return 2;
    if (vaccine == VaccineStatus.soon) return 1;
    return 0;
  }
}

/// Réponse complète de la synthèse : tous les animaux de l'utilisateur.
class HealthSummary {
  const HealthSummary({required this.pets});

  factory HealthSummary.fromJson(Map<String, dynamic> json) => HealthSummary(
        pets: [
          for (final p in (json['pets'] as List?) ?? const [])
            PetHealthSummary.fromJson(Map<String, dynamic>.from(p as Map)),
        ],
      );

  final List<PetHealthSummary> pets;

  List<PetHealthSummary> get archived =>
      pets.where((p) => p.archived).toList()..sort((a, b) => a.name.compareTo(b.name));

  /// Animaux actifs, ceux qui demandent une action en premier.
  List<PetHealthSummary> activeSorted(DateTime now) => pets.where((p) => !p.archived).toList()
    ..sort((a, b) {
      final byScore = b.actionScore(now).compareTo(a.actionScore(now));
      return byScore != 0 ? byScore : a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });

  /// Toutes les prises du jour, animaux actifs seulement, par heure.
  List<DoseSlot> todayDoses(DateTime now) => [
        for (final p in pets)
          if (!p.archived) ...p.todayDoses(now),
      ]..sort((a, b) => a.time.compareTo(b.time));

  /// Rappels en retard puis ceux des [vaccineSoonDays] prochains jours, animaux actifs seulement.
  List<(PetHealthSummary, PendingVaccine)> vaccinesDue(DateTime now) => [
        for (final p in pets)
          if (!p.archived)
            for (final v in p.pendingVaccines)
              if (v.statusAt(now) != VaccineStatus.upToDate) (p, v),
      ]..sort((a, b) => a.$2.dueAt.compareTo(b.$2.dueAt));
}
