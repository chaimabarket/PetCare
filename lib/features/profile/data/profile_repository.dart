import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/polling.dart';
import 'user_profile.dart';

/// Lecture et modification du profil `users/{uid}`, par l'API REST PetCare.
///
/// Si le serveur est éteint ou injoignable, la lecture et la modification passent directement par
/// Firestore : les règles de sécurité sont les mêmes, l'application reste utilisable.
class ProfileRepository {
  ProfileRepository({FirebaseFirestore? firestore, FirebaseAuth? auth, ApiClient? api})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance,
        _api = api ?? ApiClient();

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final ApiClient _api;

  DocumentReference<Map<String, dynamic>> _doc(String uid) => _firestore.collection('users').doc(uid);

  /// Profil de l'utilisateur, rafraîchi régulièrement et après chaque modification.
  Stream<UserProfile?> watch(String uid) {
    // L'API ne sert que le profil de l'utilisateur connecté.
    if (_auth.currentUser?.uid != uid) return _watchFirestore(uid);

    return poll(() async {
      try {
        return UserProfile.fromJson(await _api.get('/api/users/me') as Map<String, dynamic>);
      } on ApiException catch (e) {
        if (e.statusCode == 404) return null;
        if (e.isUnreachable) return _readFirestore(uid);
        rethrow;
      }
    });
  }

  Stream<UserProfile?> _watchFirestore(String uid) =>
      _doc(uid).snapshots().map((doc) => doc.exists ? UserProfile.fromFirestore(doc) : null);

  Future<UserProfile?> _readFirestore(String uid) async {
    final doc = await _doc(uid).get();
    return doc.exists ? UserProfile.fromFirestore(doc) : null;
  }

  /// Modifie les informations personnelles. L'e-mail et le rôle ne sont pas modifiables ici.
  Future<void> update({
    required String uid,
    required String fullName,
    required String city,
    required String phone,
  }) async {
    try {
      await _api.put('/api/users/me', {
        'fullName': fullName.trim(),
        'city': city.trim(),
        'phone': phone.trim().isEmpty ? null : phone.trim(),
      });
    } on ApiException catch (e) {
      if (!e.isUnreachable) rethrow;
      await _doc(uid).update({
        'fullName': fullName.trim(),
        'city': city.trim(),
        'phone': phone.trim().isEmpty ? null : phone.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
    final user = _auth.currentUser;
    if (user != null && user.uid == uid) await user.updateDisplayName(fullName.trim());
    notifyApiDataChanged();
  }
}
