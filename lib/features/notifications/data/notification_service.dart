import 'package:cloud_firestore/cloud_firestore.dart';

import 'app_notification.dart';

/// Notifications dans l'application.
///
/// Les autres modules envoient une notification avec [send], par exemple :
/// ```dart
/// await NotificationService().send(
///   toUserId: candidatureUserId,
///   title: 'Candidature acceptée',
///   body: 'Le refuge a accepté votre demande pour Nala.',
///   category: NotificationCategory.adoption,
/// );
/// ```
class NotificationService {
  NotificationService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _collection(String uid) =>
      _firestore.collection('users').doc(uid).collection('notifications');

  /// Notifications de l'utilisateur, les plus récentes d'abord.
  Stream<List<AppNotification>> watch(String uid, {int limit = 50}) => _collection(uid)
      .orderBy('createdAt', descending: true)
      .limit(limit)
      .snapshots()
      .map((snap) => snap.docs.map(AppNotification.fromFirestore).toList());

  /// Nombre de notifications non lues (pastille de la cloche).
  Stream<int> watchUnreadCount(String uid) => _collection(uid)
      .where('read', isEqualTo: false)
      .snapshots()
      .map((snap) => snap.size);

  Future<void> send({
    required String toUserId,
    required String title,
    required String body,
    required NotificationCategory category,
  }) {
    return _collection(toUserId).add({
      'title': title,
      'body': body,
      'category': category.firestoreValue,
      'read': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> markAsRead(String uid, String notificationId) =>
      _collection(uid).doc(notificationId).update({'read': true});

  Future<void> markAllAsRead(String uid) async {
    final unread = await _collection(uid).where('read', isEqualTo: false).get();
    if (unread.docs.isEmpty) return;
    final batch = _firestore.batch();
    for (final doc in unread.docs) {
      batch.update(doc.reference, {'read': true});
    }
    await batch.commit();
  }
}
