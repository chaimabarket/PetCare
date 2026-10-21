/// Règles de validation des formulaires du module Utilisateurs.
abstract final class AuthValidators {
  static const minPasswordLength = 8;

  static String? email(String? value) {
    final email = value?.trim() ?? '';
    if (email.isEmpty) return 'Saisissez votre adresse e-mail.';
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      return "L'adresse e-mail n'est pas valide.";
    }
    return null;
  }

  static String? required(String? value, String message) =>
      (value == null || value.trim().isEmpty) ? message : null;

  static String? newPassword(String? value) {
    if (value == null || value.isEmpty) return 'Saisissez un mot de passe.';
    if (value.length < minPasswordLength) {
      return 'Le mot de passe doit contenir au moins $minPasswordLength caractères.';
    }
    return null;
  }

  /// Robustesse de 0 à 4 : longueur, majuscules + minuscules, chiffre, caractère spécial.
  static int passwordStrength(String value) {
    if (value.isEmpty) return 0;
    var score = 0;
    if (value.length >= minPasswordLength) score++;
    if (RegExp('[a-z]').hasMatch(value) && RegExp('[A-Z]').hasMatch(value)) score++;
    if (RegExp(r'\d').hasMatch(value)) score++;
    if (RegExp(r'[^A-Za-z0-9]').hasMatch(value)) score++;
    return score;
  }
}
