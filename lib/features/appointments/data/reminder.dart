import 'package:cloud_firestore/cloud_firestore.dart';

/// Catégorie d'un rappel : l'étiquette et l'icône de la carte (maquette « Rappels & Soins »).
enum ReminderCategory {
  medication('medicament', 'Médicament'),
  care('soin', 'Soin'),
  vet('veterinaire', 'Vétérinaire'),
  treatment('traitement', 'Traitement'),
  hygiene('hygiene', 'Hygiène'),
  checkup('controle', 'Contrôle');

  const ReminderCategory(this.firestoreValue, this.label);

  final String firestoreValue;
  final String label;

  static ReminderCategory fromFirestore(String? value) =>
      values.firstWhere((c) => c.firestoreValue == value, orElse: () => ReminderCategory.care);
}

/// Un rappel, stocké dans `reminders/{id}`.
///
/// Il est soit créé à la main (« Nouveau rappel »), soit créé automatiquement avec un
/// rendez-vous : dans ce cas `appointmentId` pointe vers le rendez-vous.
class Reminder {
  const Reminder({
    required this.id,
    required this.ownerId,
    required this.petName,
    required this.title,
    required this.category,
    required this.dueAt,
    this.petBreed,
    this.petPhotoUrl,
    this.description,
    this.detail,
    this.appointmentId,
    this.done = false,
    this.doneAt,
  });

  factory Reminder.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const {};
    return Reminder(
      id: doc.id,
      ownerId: data['ownerId'] as String? ?? '',
      petName: data['petName'] as String? ?? '',
      petBreed: data['petBreed'] as String?,
      petPhotoUrl: data['petPhotoUrl'] as String?,
      title: data['title'] as String? ?? '',
      description: data['description'] as String?,
      detail: data['detail'] as String?,
      category: ReminderCategory.fromFirestore(data['category'] as String?),
      dueAt: (data['dueAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      appointmentId: data['appointmentId'] as String?,
      done: data['done'] as bool? ?? false,
      doneAt: (data['doneAt'] as Timestamp?)?.toDate(),
    );
  }

  final String id;
  final String ownerId;
  final String petName;
  final String? petBreed;
  final String? petPhotoUrl;
  final String title;
  final String? description;

  /// Petite information en bas de la carte : « 1 comprimé », « Protection 1 mois »…
  final String? detail;
  final ReminderCategory category;
  final DateTime dueAt;
  final String? appointmentId;
  final bool done;
  final DateTime? doneAt;
}
