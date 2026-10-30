import 'package:cloud_firestore/cloud_firestore.dart';

/// Type d'acte médical (puces du formulaire « Ajouter un soin médical »).
enum HealthEntryType {
  visit('visite', 'Visite', 'Clinique'),
  vaccine('vaccin', 'Vaccin', 'Vaccination'),
  exam('examen', 'Examen', 'Examen'),
  allergy('allergie', 'Allergie', 'Sensibilité'),
  note('note', 'Note libre', 'Note');

  const HealthEntryType(this.firestoreValue, this.label, this.cardLabel);

  final String firestoreValue;

  /// Libellé de la puce dans le formulaire.
  final String label;

  /// Petit libellé coloré au-dessus du titre dans le carnet.
  final String cardLabel;

  static HealthEntryType fromFirestore(String? value) =>
      values.firstWhere((t) => t.firestoreValue == value, orElse: () => HealthEntryType.note);
}

/// Pièce jointe d'un soin (ordonnance, vignette vaccinale, facture).
///
/// Le fichier est stocké en octets dans `pets/{petId}/healthEntries/{entryId}/files/{index}`
/// (pas de Firebase Storage, comme les photos du module Adoption) ; l'entrée ne garde que
/// le nom, le type et la taille pour l'affichage.
class HealthAttachment {
  const HealthAttachment({required this.name, required this.mimeType, required this.size});

  factory HealthAttachment.fromMap(Map<String, dynamic> map) => HealthAttachment(
        name: map['name'] as String? ?? 'Document',
        mimeType: map['mimeType'] as String? ?? 'application/octet-stream',
        size: (map['size'] as num?)?.toInt() ?? 0,
      );

  final String name;
  final String mimeType;
  final int size;

  bool get isImage => mimeType.startsWith('image/');

  Map<String, dynamic> toMap() => {'name': name, 'mimeType': mimeType, 'size': size};
}

/// Une entrée du carnet de santé, stockée dans `pets/{petId}/healthEntries/{id}`.
///
/// Le carnet est privé : seul le propriétaire de l'animal le lit (voir `firestore.rules`).
class HealthEntry {
  const HealthEntry({
    required this.id,
    required this.type,
    required this.title,
    required this.date,
    this.description,
    this.practitioner,
    this.cost,
    this.vaccineName,
    this.batchNumber,
    this.nextReminderAt,
    this.reminderDone = false,
    this.weightKg,
    this.weightDeltaKg,
    this.attachments = const [],
  });

  factory HealthEntry.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const {};
    return HealthEntry(
      id: doc.id,
      type: HealthEntryType.fromFirestore(data['type'] as String?),
      title: data['title'] as String? ?? '',
      date: (data['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      description: data['description'] as String?,
      practitioner: data['practitioner'] as String?,
      cost: (data['cost'] as num?)?.toDouble(),
      vaccineName: data['vaccineName'] as String?,
      batchNumber: data['batchNumber'] as String?,
      nextReminderAt: (data['nextReminderAt'] as Timestamp?)?.toDate(),
      reminderDone: data['reminderDone'] as bool? ?? false,
      weightKg: (data['weightKg'] as num?)?.toDouble(),
      weightDeltaKg: (data['weightDeltaKg'] as num?)?.toDouble(),
      attachments: [
        for (final item in (data['attachments'] as List?) ?? const [])
          if (item is Map) HealthAttachment.fromMap(Map<String, dynamic>.from(item)),
      ],
    );
  }

  final String id;
  final HealthEntryType type;
  final String title;
  final DateTime date;
  final String? description;
  final String? practitioner;
  final double? cost;

  // Vaccin uniquement.
  final String? vaccineName;
  final String? batchNumber;
  final DateTime? nextReminderAt;

  /// Le propriétaire a indiqué que le rappel est déjà fait (bouton ✓✓ du carnet).
  final bool reminderDone;

  /// Poids relevé pendant la visite (« + Poids » du formulaire) et écart avec la pesée précédente.
  final double? weightKg;
  final double? weightDeltaKg;
  final List<HealthAttachment> attachments;

  /// Rappel vaccinal encore à faire.
  bool get hasPendingReminder => type == HealthEntryType.vaccine && nextReminderAt != null && !reminderDone;
}
