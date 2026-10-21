import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'user_role.dart';

/// Accès à Firebase Authentication pour le module Utilisateurs.
class AuthService {
  AuthService({FirebaseAuth? auth, FirebaseFirestore? firestore})
      : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  Future<void> signIn({required String email, required String password}) async {
    try {
      await _auth.signInWithEmailAndPassword(email: email.trim(), password: password);
    } on FirebaseAuthException catch (e) {
      throw AuthException(_messageFor(e.code));
    }
  }

  /// Crée le compte Firebase puis le profil `users/{uid}` dans Firestore.
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
      await _firestore.collection('users').doc(user.uid).set({
        'fullName': fullName.trim(),
        'email': email.trim(),
        'city': city.trim(),
        'role': role.firestoreValue,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } on FirebaseException {
      // Sans profil, le compte serait inutilisable : on l'annule pour permettre de réessayer.
      await user.delete();
      throw const AuthException("Impossible d'enregistrer votre profil. Réessayez.");
    }
  }

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
