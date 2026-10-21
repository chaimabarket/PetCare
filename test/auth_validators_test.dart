import 'package:flutter_test/flutter_test.dart';
import 'package:projet_flutter/features/auth/presentation/validators.dart';

void main() {
  group('AuthValidators.email', () {
    test('refuse un e-mail vide ou mal formé', () {
      expect(AuthValidators.email(''), isNotNull);
      expect(AuthValidators.email('lina'), isNotNull);
      expect(AuthValidators.email('lina@exemple'), isNotNull);
    });

    test('accepte un e-mail valide, même avec des espaces autour', () {
      expect(AuthValidators.email('lina.mercier@exemple.fr'), isNull);
      expect(AuthValidators.email('  lina@exemple.fr '), isNull);
    });
  });

  group('AuthValidators.newPassword', () {
    test('exige au moins 8 caractères', () {
      expect(AuthValidators.newPassword('Court1!'), isNotNull);
      expect(AuthValidators.newPassword('Assez1!x'), isNull);
    });
  });

  group('AuthValidators.passwordStrength', () {
    test('compte longueur, casse, chiffre et caractère spécial', () {
      expect(AuthValidators.passwordStrength(''), 0);
      expect(AuthValidators.passwordStrength('abc'), 0);
      expect(AuthValidators.passwordStrength('abcdefgh'), 1);
      expect(AuthValidators.passwordStrength('Abcdefgh'), 2);
      expect(AuthValidators.passwordStrength('Abcdefg1'), 3);
      expect(AuthValidators.passwordStrength('MonChienFidele33!'), 4);
    });
  });
}
