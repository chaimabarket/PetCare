import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'user_profile.dart';

/// Lecture et modification du profil `users/{uid}`.
class ProfileRepository {
  ProfileRepository({FirebaseFirestore? firestore, FirebaseAuth? auth})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  DocumentReference<Map<String, dynamic>> _doc(String uid) => _firestore.collection('users').doc(uid);

  /// Profil de l'utilisateur, mis à jour en direct à chaque modification.
  Stream<UserProfile?> watch(String uid) =>
      _doc(uid).snapshots().map((doc) => doc.exists ? UserProfile.fromFirestore(doc) : null);

  /// Modifie les informations personnelles. L'e-mail et le rôle ne sont pas modifiables ici.
  Future<void> update({
    required String uid,
    required String fullName,
    required String city,
    required String phone,
  }) async {
    await _doc(uid).update({
      'fullName': fullName.trim(),
      'city': city.trim(),
      'phone': phone.trim().isEmpty ? null : phone.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    final user = _auth.currentUser;
    if (user != null && user.uid == uid) await user.updateDisplayName(fullName.trim());
  }
}
