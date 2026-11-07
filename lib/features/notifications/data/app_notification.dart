import 'package:cloud_firestore/cloud_firestore.dart';

/// Catégories de notification, utilisées pour les filtres et les icônes.
enum NotificationCategory {
  health('sante', 'Santé & Soins'),
  appointment('rendezvous', 'Rendez-vous'),
  adoption('adoption', 'Adoptions'),
  community('communaute', 'Communauté'),
  message('message', 'Messages');

  const NotificationCategory(this.firestoreValue, this.label);

  final String firestoreValue;
  final String label;

  static NotificationCategory fromFirestore(String? value) => values.firstWhere(
        (c) => c.firestoreValue == value,
        orElse: () => NotificationCategory.message,
      );
}

/// Notification dans l'application, stockée dans `users/{uid}/notifications/{id}`.
class AppNotification {
  const AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.category,
    required this.read,
    required this.createdAt,
  });

  factory AppNotification.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const {};
    return AppNotification(
      id: doc.id,
      title: data['title'] as String? ?? '',
      body: data['body'] as String? ?? '',
      category: NotificationCategory.fromFirestore(data['category'] as String?),
      read: data['read'] as bool? ?? false,
      // Une notification tout juste créée n'a pas encore l'heure du serveur.
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  /// Notification renvoyée par l'API REST (`GET /api/users/me/notifications`).
  factory AppNotification.fromJson(Map<String, dynamic> json) => AppNotification(
        id: json['id'] as String? ?? '',
        title: json['title'] as String? ?? '',
        body: json['body'] as String? ?? '',
        category: NotificationCategory.fromFirestore(json['category'] as String?),
        read: json['read'] as bool? ?? false,
        createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '')?.toLocal() ?? DateTime.now(),
      );

  final String id;
  final String title;
  final String body;
  final NotificationCategory category;
  final bool read;
  final DateTime createdAt;
}
