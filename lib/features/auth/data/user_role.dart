/// Rôles des utilisateurs, enregistrés dans le champ `role` du document `users/{uid}`.
enum UserRole {
  owner('proprietaire', 'Propriétaire'),
  provider('prestataire', 'Prestataire'),
  shelter('refuge', 'Refuge'),
  // Jamais proposé à l'inscription : attribué à la main dans la console Firebase.
  admin('admin', 'Administrateur');

  const UserRole(this.firestoreValue, this.label);

  /// Valeur enregistrée dans Firestore.
  final String firestoreValue;

  /// Libellé affiché dans l'application.
  final String label;

  static UserRole fromFirestore(String? value) =>
      values.firstWhere((r) => r.firestoreValue == value, orElse: () => UserRole.owner);
}
