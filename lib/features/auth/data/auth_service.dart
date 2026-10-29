import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../core/api/api_client.dart';
import 'user_role.dart';

/// Accès à Firebase Authentication pour le module Utilisateurs.
class AuthService {
  AuthService({FirebaseAuth? auth, FirebaseFirestore? firestore, ApiClient? api})
      : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance,
        _api = api ?? ApiClient();

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final ApiClient _api;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  Future<void> signIn({required String email, required String password}) async {
    try {
      await _auth.signInWithEmailAndPassword(email: email.trim(), password: password);
    } on FirebaseAuthException catch (e) {
      throw AuthException(_messageFor(e.code));
    }
  }

  /// Crée le compte Firebase puis le profil `users/{uid}` par l'API REST
  /// (directement dans Firestore si le serveur est injoignable).
  Future<void> register({
    required String fullName,
    required String email,
    required String city,
    required String password,
    required UserRole role,
  }) async {
    final UserCredential credential;
    try {
      credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      throw AuthException(_messageFor(e.code));
    }

    final user = credential.user!;
    try {
      await user.updateDisplayName(fullName.trim());
      await _createProfile(user.uid, fullName: fullName, email: email, city: city, role: role);
    } on FirebaseException {
      await _cancelAccount(user);
      throw const AuthException("Impossible d'enregistrer votre profil. Réessayez.");
    } on ApiException catch (e) {
      await _cancelAccount(user);
      throw AuthException(e.message);
    }
  }

  Future<void> _createProfile(
    String uid, {
    required String fullName,
    required String email,
    required String city,
    required UserRole role,
  }) async {
    try {
      await _api.post('/api/users/me', {
        'fullName': fullName.trim(),
        'city': city.trim(),
        'role': role.firestoreValue,
      });
    } on ApiException catch (e) {
      if (!e.isUnreachable) rethrow;
      await _firestore.collection('users').doc(uid).set({
        'fullName': fullName.trim(),
        'email': email.trim(),
        'city': city.trim(),
        'role': role.firestoreValue,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
  }

  /// Sans profil, le compte serait inutilisable : on l'annule pour permettre de réessayer.
  Future<void> _cancelAccount(User user) => user.delete();

  /// Envoie l'e-mail de réinitialisation (en français).
  /// Firebase ne signale pas les adresses inconnues, pour ne pas révéler quels comptes existent.
  Future<void> sendPasswordReset(String email) async {
    try {
      await _auth.setLanguageCode('fr');
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (e) {
      throw AuthException(_messageFor(e.code));
    }
  }

  Future<void> signOut() => _auth.signOut();

  static String _messageFor(String code) => switch (code) {
        'email-already-in-use' => 'Un compte existe déjà avec cette adresse e-mail.',
        'weak-password' => 'Le mot de passe est trop faible.',
        'invalid-email' => "L'adresse e-mail n'est pas valide.",
        'user-disabled' => 'Ce compte a été désactivé.',
        'user-not-found' ||
        'wrong-password' ||
        'invalid-credential' =>
          'E-mail ou mot de passe incorrect.',
        'too-many-requests' => 'Trop de tentatives. Réessayez dans quelques minutes.',
        'network-request-failed' => 'Pas de connexion internet. Vérifiez votre réseau.',
        _ => 'Une erreur est survenue. Réessayez.',
      };
}

/// Erreur d'authentification avec un message prêt à afficher.
class AuthException implements Exception {
  const AuthException(this.message);

  final String message;

  @override
  String toString() => message;
}
