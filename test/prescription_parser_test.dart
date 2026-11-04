import 'package:flutter_test/flutter_test.dart';
import 'package:projet_flutter/features/health/data/prescription_parser.dart';

final _now = DateTime(2026, 11, 4, 12);

ScanResult _parse(String text) => parsePrescriptionText(text, now: _now);

void main() {
  test('vignette Rabisin : vaccin, lot, date ; la péremption est ignorée', () {
    final r = _parse('''
RABISIN
Vaccin antirabique inactivé
Lot L456789
EXP 08/2027
Exp: 31/08/2027
Clinique Vétérinaire des Lilas
Dr Mercier - Tél. 71 123 456
Le 12/11/2025
''');
    expect(r.productName, 'RABISIN');
    expect(r.isVaccine, isTrue);
    expect(r.batchNumber, 'L456789');
    expect(r.date, DateTime(2025, 11, 12));
    expect(r.nextDate, isNull);
    expect(r.practitioner, 'Dr. Mercier • Clinique Vétérinaire des Lilas');
  });

  test('passeport : valence collée au nom, prochain rappel', () {
    final r = _parse('''
Vaccination
Nobivac DHPPi L4
N° de lot : A123-45B
Date : 3 nov. 2026
Prochain rappel : 3 nov. 2027
''');
    expect(r.productName, 'Nobivac DHPPi L4');
    expect(r.isVaccine, isTrue);
    expect(r.batchNumber, 'A123-45B');
    expect(r.date, DateTime(2026, 11, 3));
    expect(r.nextDate, DateTime(2027, 11, 3));
  });

  test('ordonnance : médicament avec son dosage commercial, sans posologie', () {
    final r = _parse('''
CLINIQUE VETERINAIRE DU LAC
Docteur Amira Ben Salah
Tunis, le 28/10/2026
Pour : Milo (chien, 29 kg)
Synulox 250 mg
1 comprimé matin et soir pendant 10 jours
Metacam 2,5 ml : selon prescription
''');
    expect(r.productName, 'Synulox 250 mg');
    expect(r.isVaccine, isFalse);
    expect(r.date, DateTime(2026, 10, 28));
    expect(r.practitioner, 'Dr. Amira Ben Salah • CLINIQUE VETERINAIRE DU LAC');
    expect(r.batchNumber, isNull);
  });

  test('jamais de posologie ni de diagnostic dans le résultat', () {
    final r = _parse('''
Diagnostic : otite bactérienne
Surolan
Posologie : 5 gouttes 2 fois par jour pendant 7 jours
Le 01/11/2026
''');
    expect(r.productName, 'Surolan');
    final everything = [r.productName, r.batchNumber, r.practitioner].whereType<String>().join(' ');
    expect(everything, isNot(contains('gouttes')));
    expect(everything, isNot(contains('otite')));

    final posologyLabel = _parse('Traitement : 1 comprimé matin et soir\nMilbemax');
    expect(posologyLabel.productName, 'Milbemax', reason: 'une posologie derrière « Traitement : » est ignorée');
  });

  test('étiquette « Médicament : » quand le nom est inconnu', () {
    final r = _parse('Médicament : Zylexis spray\nLe 2/11/26');
    expect(r.productName, 'Zylexis spray');
    expect(r.date, DateTime(2026, 11, 2));
    final next = _parse('Vaccin :\nCanixin DHPPi\n02.11.2026');
    expect(next.productName, startsWith('Canixin'));
    expect(next.isVaccine, isTrue);
  });

  test('un nom commercial passe avant un terme générique écrit plus haut', () {
    final r = _parse('Vaccination contre la rage\nRabisin\n12/11/2025');
    expect(r.productName, 'Rabisin');
    final generic = _parse('Rappel Rage effectué\n12/11/2025');
    expect(generic.productName, 'Rage');
    expect(generic.isVaccine, isTrue);
  });

  test('deux dates : la plus récente passée pour le soin ; une date future sans « rappel » est ignorée', () {
    final r = _parse('Rabisin\nPrimo-vaccination 10/10/2024\nVaccin du 12/11/2025\nRDV 15/12/2027');
    expect(r.date, DateTime(2025, 11, 12));
    expect(r.nextDate, isNull);
  });

  test('texte bruité : dates impossibles et faux lots écartés', () {
    final r = _parse('Lotion auriculaire\nLOT ABC\n31/02/2026\n45/13/2026\nBravecto 1000mg');
    expect(r.batchNumber, isNull, reason: 'un lot contient des chiffres ; « Lotion » n’est pas « Lot »');
    expect(r.date, isNull);
    expect(r.productName, 'Bravecto 1000mg');
  });

  test('le téléphone et l’e-mail ne passent pas dans le vétérinaire', () {
    final r = _parse('Dr Karim Haddad 98 765 432 contact@vet-lac.tn\nFrontline');
    expect(r.practitioner, 'Dr. Karim Haddad');
  });

  test('rien d’utilisable', () {
    expect(_parse('').isEmpty, isTrue);
    expect(_parse('Merci de votre visite !\nÀ bientôt').isEmpty, isTrue);
  });
}
