import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/polling.dart';
import 'app_notification.dart';

/// Notifications dans l'application.
///
/// La lecture et le marquage « lu » passent par l'API REST PetCare ; si le serveur est injoignable,
/// ils passent directement par Firestore. L'envoi ([send]) reste direct : les autres modules l'appellent
/// avec le compte de l'expéditeur, pour un destinataire différent.
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
  NotificationService({FirebaseFirestore? firestore, FirebaseAuth? auth, ApiClient? api})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance,
        _api = api ?? ApiClient();

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final ApiClient _api;

  CollectionReference<Map<String, dynamic>> _collection(String uid) =>
      _firestore.collection('users').doc(uid).collection('notifications');

  bool _useApi(String uid) => _auth.currentUser?.uid == uid;

  /// Notifications de l'utilisateur, les plus récentes d'abord.
  Stream<List<AppNotification>> watch(String uid, {int limit = 50}) {
    if (!_useApi(uid)) return _watchFirestore(uid, limit);

    return poll(() async {
      try {
        final items = await _api.get('/api/users/me/notifications?limit=$limit') as List<dynamic>;
        return items.map((e) => AppNotification.fromJson(e as Map<String, dynamic>)).toList();
      } on ApiException catch (e) {
        if (!e.isUnreachable) rethrow;
        return _watchFirestore(uid, limit).first;
      }
    });
  }

  Stream<List<AppNotification>> _watchFirestore(String uid, int limit) => _collection(uid)
      .orderBy('createdAt', descending: true)
      .limit(limit)
      .snapshots()
      .map((snap) => snap.docs.map(AppNotification.fromFirestore).toList());

  /// Nombre de notifications non lues (pastille de la cloche).
  Stream<int> watchUnreadCount(String uid) {
    if (!_useApi(uid)) return _watchUnreadFirestore(uid);

    return poll(() async {
      try {
        final result = await _api.get('/api/users/me/notifications/unread-count') as Map<String, dynamic>;
        return result['count'] as int;
      } on ApiException catch (e) {
        if (!e.isUnreachable) rethrow;
        return _watchUnreadFirestore(uid).first;
      }
    });
  }

  Stream<int> _watchUnreadFirestore(String uid) =>
      _collection(uid).where('read', isEqualTo: false).snapshots().map((snap) => snap.size);

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

  Future<void> markAsRead(String uid, String notificationId) async {
    try {
      await _api.patch('/api/users/me/notifications/$notificationId/read');
    } on ApiException catch (e) {
      if (!e.isUnreachable) rethrow;
      await _collection(uid).doc(notificationId).update({'read': true});
    }
    notifyApiDataChanged();
  }

  Future<void> markAllAsRead(String uid) async {
    try {
      await _api.post('/api/users/me/notifications/read-all');
    } on ApiException catch (e) {
      if (!e.isUnreachable) rethrow;
      await _markAllAsReadFirestore(uid);
    }
    notifyApiDataChanged();
  }

  Future<void> _markAllAsReadFirestore(String uid) async {
    final unread = await _collection(uid).where('read', isEqualTo: false).get();
    if (unread.docs.isEmpty) return;
    final batch = _firestore.batch();
    for (final doc in unread.docs) {
      batch.update(doc.reference, {'read': true});
    }
    await batch.commit();
  }
}
