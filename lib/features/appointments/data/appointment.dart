import 'package:cloud_firestore/cloud_firestore.dart';

/// Une date lue dans Firestore (Timestamp) ou renvoyée par l'API REST (texte ISO en UTC).
DateTime? readDate(Object? value) {
  if (value is Timestamp) return value.toDate();
  if (value is String) return DateTime.tryParse(value)?.toLocal();
  if (value is DateTime) return value;
  return null;
}

/// Statuts d'un rendez-vous (cahier des charges, section 6).
///
/// PLANNED et CONFIRMED sont actifs ; COMPLETED et CANCELLED sont terminaux (RG-20).
enum AppointmentStatus {
  planned('planned', 'En attente'),
  confirmed('confirmed', 'Confirmé'),
  completed('completed', 'Terminé'),
  cancelled('cancelled', 'Annulé');

  const AppointmentStatus(this.firestoreValue, this.label);

  /// Valeur enregistrée dans Firestore.
  final String firestoreValue;

  /// Libellé affiché dans les pastilles de statut.
  final String label;

  bool get isActive => this == planned || this == confirmed;

  static AppointmentStatus fromFirestore(String? value) =>
      values.firstWhere((s) => s.firestoreValue == value, orElse: () => AppointmentStatus.planned);
}

/// Type de rendez-vous : les étiquettes colorées des cartes de l'agenda.
enum AppointmentType {
  vaccine('vaccin', 'Vaccin'),
  vet('veterinaire', 'Vétérinaire'),
  grooming('toilettage', 'Toilettage'),
  personalCare('soin', 'Soin personnel'),
  training('education', 'Séance éducation'),
  walk('garde', 'Garde / Promenade'),
  other('autre', 'Autre');

  const AppointmentType(this.firestoreValue, this.label);

  final String firestoreValue;
  final String label;

  /// Les types proposés dans le formulaire « Nouveau rendez-vous » (rendez-vous personnel).
  static const personalChoices = [personalCare, training, walk, other];

  static AppointmentType fromFirestore(String? value) =>
      values.firstWhere((t) => t.firestoreValue == value, orElse: () => AppointmentType.other);
}

/// Où se déroule un rendez-vous personnel.
enum AppointmentPlace {
  home('domicile', 'À domicile'),
  outdoor('exterieur', 'En extérieur / Parc'),
  other('autre', 'Autre adresse');

  const AppointmentPlace(this.firestoreValue, this.label);

  final String firestoreValue;
  final String label;

  static AppointmentPlace fromFirestore(String? value) =>
      values.firstWhere((p) => p.firestoreValue == value, orElse: () => AppointmentPlace.other);
}

/// Action enregistrée dans l'historique (AppointmentChange). « Reporté » est une action, pas un statut (RG-18).
enum AppointmentAction {
  created('create', 'Rendez-vous créé'),
  confirmed('confirm', 'Confirmé'),
  rescheduled('reschedule', 'Reporté'),
  cancelled('cancel', 'Annulé'),
  completed('complete', 'Terminé');

  const AppointmentAction(this.firestoreValue, this.label);

  final String firestoreValue;
  final String label;

  static AppointmentAction fromFirestore(String? value) =>
      values.firstWhere((a) => a.firestoreValue == value, orElse: () => AppointmentAction.created);
}

/// Une ligne de l'historique d'un rendez-vous (jamais modifiée, seulement ajoutée).
class AppointmentChange {
  const AppointmentChange({
    required this.action,
    required this.at,
    required this.byUserId,
    this.reason,
    this.oldStart,
    this.newStart,
  });

  factory AppointmentChange.fromMap(Map<String, dynamic> map) => AppointmentChange(
        action: AppointmentAction.fromFirestore(map['action'] as String?),
        at: readDate(map['at']) ?? DateTime.now(),
        byUserId: map['by'] as String? ?? '',
        reason: map['reason'] as String?,
        oldStart: readDate(map['oldStart']),
        newStart: readDate(map['newStart']),
      );

  final AppointmentAction action;
  final DateTime at;
  final String byUserId;
  final String? reason;
  final DateTime? oldStart;
  final DateTime? newStart;

  Map<String, dynamic> toMap() => {
        'action': action.firestoreValue,
        'at': Timestamp.fromDate(at),
        'by': byUserId,
        if (reason != null) 'reason': reason,
        if (oldStart != null) 'oldStart': Timestamp.fromDate(oldStart!),
        if (newStart != null) 'newStart': Timestamp.fromDate(newStart!),
      };
}

/// Un rendez-vous, stocké dans `appointments/{id}`.
///
/// Un seul objet pour les deux cas (RG-12) : avec `providerId` c'est une réservation
/// d'un service du module 6, sans `providerId` c'est un rendez-vous personnel.
class Appointment {
  const Appointment({
    required this.id,
    required this.ownerId,
    required this.petName,
    required this.title,
    required this.type,
    required this.startsAt,
    required this.endsAt,
    required this.status,
    this.petId,
    this.petBreed,
    this.petPhotoUrl,
    this.description,
    this.providerId,
    this.providerName,
    this.providerAddress,
    this.providerPhone,
    this.serviceId,
    this.price,
    this.place = AppointmentPlace.other,
    this.location = '',
    this.notes = '',
    this.reminderMinutes = 1440,
    this.pushReminder = true,
    this.cancelReason,
    this.reminderDoneAt,
    this.version = 1,
    this.changes = const [],
  });

  factory Appointment.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) =>
      Appointment.fromData(doc.id, doc.data() ?? const {});

  /// Rendez-vous renvoyé par l'API REST (`GET /api/appointments`).
  factory Appointment.fromJson(Map<String, dynamic> json) => Appointment.fromData(json['id'] as String? ?? '', json);

  factory Appointment.fromData(String id, Map<String, dynamic> data) {
    final startsAt = readDate(data['startsAt']) ?? DateTime.now();
    return Appointment(
      id: id,
      ownerId: data['ownerId'] as String? ?? '',
      petId: data['petId'] as String?,
      petName: data['petName'] as String? ?? '',
      petBreed: data['petBreed'] as String?,
      petPhotoUrl: data['petPhotoUrl'] as String?,
      title: data['title'] as String? ?? '',
      description: data['description'] as String?,
      type: AppointmentType.fromFirestore(data['type'] as String?),
      startsAt: startsAt,
      endsAt: readDate(data['endsAt']) ?? startsAt.add(const Duration(minutes: 30)),
      status: AppointmentStatus.fromFirestore(data['status'] as String?),
      providerId: data['providerId'] as String?,
      providerName: data['providerName'] as String?,
      providerAddress: data['providerAddress'] as String?,
      providerPhone: data['providerPhone'] as String?,
      serviceId: data['serviceId'] as String?,
      price: (data['price'] as num?)?.toDouble(),
      place: AppointmentPlace.fromFirestore(data['place'] as String?),
      location: data['location'] as String? ?? '',
      notes: data['notes'] as String? ?? '',
      reminderMinutes: (data['reminderMinutes'] as num?)?.toInt() ?? 0,
      pushReminder: data['pushReminder'] as bool? ?? false,
      cancelReason: data['cancelReason'] as String?,
      reminderDoneAt: readDate(data['reminderDoneAt']),
      version: (data['version'] as num?)?.toInt() ?? 1,
      changes: [
        for (final c in (data['changes'] as List<dynamic>? ?? const []))
          if (c is Map) AppointmentChange.fromMap(Map<String, dynamic>.from(c)),
      ],
    );
  }

  final String id;
  final String ownerId;
  final String? petId;
  final String petName;
  final String? petBreed;
  final String? petPhotoUrl;
  final String title;
  final String? description;
  final AppointmentType type;
  final DateTime startsAt;
  final DateTime endsAt;
  final AppointmentStatus status;

  /// Prestataire (module 6). Null pour un rendez-vous personnel.
  final String? providerId;
  final String? providerName;
  final String? providerAddress;
  final String? providerPhone;
  final String? serviceId;

  /// Prix indicatif du service, en dinars. Aucun paiement en ligne.
  final double? price;

  final AppointmentPlace place;
  final String location;
  final String notes;

  /// Délai du rappel avant le début, en minutes. 0 = sans rappel.
  final int reminderMinutes;
  final bool pushReminder;
  final String? cancelReason;

  /// Moment où l'utilisateur a validé le rappel (« Fait »). Remis à zéro après un report.
  final DateTime? reminderDoneAt;

  /// Incrémentée à chaque modification : sert à détecter une modification concurrente (RG-20).
  final int version;
  final List<AppointmentChange> changes;

  bool get isBooking => providerId != null;
  Duration get duration => endsAt.difference(startsAt);

  bool hasStarted([DateTime? now]) => !startsAt.isAfter(now ?? DateTime.now());
  bool hasEnded([DateTime? now]) => !endsAt.isAfter(now ?? DateTime.now());

  /// Seule une réservation en attente et pas encore commencée peut être confirmée (RG-16, RG-17).
  bool canConfirm([DateTime? now]) => status == AppointmentStatus.planned && !hasStarted(now);

  /// Report et annulation : seulement avant le début (RG-17).
  bool canReschedule([DateTime? now]) => status.isActive && !hasStarted(now);
  bool canCancel([DateTime? now]) => status.isActive && !hasStarted(now);

  /// COMPLETED seulement depuis CONFIRMED, après l'heure de fin (RG-19).
  bool canComplete([DateTime? now]) => status == AppointmentStatus.confirmed && hasEnded(now);

  /// Nom affiché du lieu : le prestataire pour une réservation, sinon le lieu saisi.
  String get placeLabel => providerName ?? (location.isEmpty ? place.label : location);

  /// Vrai si les deux rendez-vous se chevauchent sur l'intervalle [début, fin[.
  bool overlaps(DateTime start, DateTime end) => startsAt.isBefore(end) && start.isBefore(endsAt);
}
