import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/pdf.dart' show TtfParser;
import 'package:pdf/widgets.dart' as pw;
import 'package:projet_flutter/features/health/data/health_entry.dart';
import 'package:projet_flutter/features/health/data/health_pdf.dart';
import 'package:projet_flutter/features/health/data/health_pet.dart';
import 'package:projet_flutter/features/health/data/treatment.dart';

final _now = DateTime(2026, 11, 4, 12);

ByteData _font(String name) => ByteData.sublistView(File('assets/fonts/$name').readAsBytesSync());

const _pet = HealthPet(
  id: 'p1',
  name: 'Milo',
  species: 'dog',
  breed: 'Golden Retriever',
  sex: 'male',
  chipNumber: '250269608123456',
);

/// Un carnet « piégé » : e-mail et téléphone du propriétaire glissés dans le texte libre.
final _entries = [
  HealthEntry(
    id: 'v1',
    type: HealthEntryType.vaccine,
    title: 'Rage',
    vaccineName: 'Rabisin',
    batchNumber: '#VX-99482',
    practitioner: 'Dr. Mercier',
    date: DateTime(2025, 11, 12),
    nextReminderAt: DateTime(2026, 11, 12),
  ),
  HealthEntry(
    id: 'v2',
    type: HealthEntryType.vaccine,
    title: 'CHPPiL',
    vaccineName: 'CHPPiL',
    date: DateTime(2025, 1, 10),
    nextReminderAt: DateTime(2026, 1, 10),
  ),
  HealthEntry(
    id: 'v3',
    type: HealthEntryType.vaccine,
    title: 'Toux du chenil',
    date: DateTime(2024, 5, 12),
    nextReminderAt: DateTime(2025, 5, 12),
    reminderDone: true,
  ),
  HealthEntry(
    id: 'e1',
    type: HealthEntryType.visit,
    title: 'Bilan annuel',
    practitioner: 'Clinique des Lilas',
    description: 'Dentition saine. Me rappeler au +216 20 123 456 ou lina.ben@exemple.com, poids 29,5.',
    date: DateTime(2026, 10, 15),
    nextReminderAt: DateTime(2027, 4, 15),
    weightKg: 29.5,
  ),
  HealthEntry(
    id: 'a1',
    type: HealthEntryType.allergy,
    title: 'Bœuf',
    description: 'Gravité : modérée — démangeaisons « fréquentes »',
    date: DateTime(2026, 1, 14),
  ),
  HealthEntry(id: 'n1', type: HealthEntryType.note, title: 'Note privée', date: DateTime(2026, 2, 1)),
];

final _treatments = [
  Treatment(
    id: 't1',
    category: 'Antibiotique',
    name: 'Synulox 250 mg',
    subtitle: 'Amoxicilline',
    posology: '1 comprimé matin et soir pendant 10 jours.',
    practitioner: 'Dr. Mercier',
    startDate: DateTime(2026, 11, 1),
    endDate: DateTime(2026, 11, 10),
  ),
  Treatment(
    id: 't2',
    category: 'Anti-infectieux',
    name: 'Metrobactin 500 mg',
    posology: '1/2 comprimé 2 fois par jour.',
    startDate: DateTime(2026, 1, 15),
    endDate: DateTime(2026, 1, 24),
    stoppedAt: DateTime(2026, 1, 20),
    stopReason: 'Intolérance, appeler le 06 12 34 56 78',
  ),
  Treatment(
    id: 't3',
    category: 'Vermifuge',
    name: 'Milbemax',
    posology: '1 comprimé',
    startDate: DateTime(2026, 9, 1),
    endDate: DateTime(2026, 9, 1),
  ),
];

HealthPdfContent _content() => buildHealthPdfContent(pet: _pet, entries: _entries, treatments: _treatments, now: _now);

void main() {
  test('la police embarquée contient les caractères du français', () {
    for (final name in ['Inter-Regular.ttf', 'Inter-Bold.ttf']) {
      final glyphs = TtfParser(_font(name)).charToGlyphIndexMap;
      for (final char in 'éèêàâçôûœŒ€«»’–•°'.runes) {
        expect(glyphs.containsKey(char), isTrue, reason: '$name : ${String.fromCharCode(char)}');
      }
    }
  });

  test("profil de l'animal", () {
    final profile = Map.fromEntries(_content().profile.map((p) => MapEntry(p.$1, p.$2)));
    expect(profile['Nom'], 'Milo');
    expect(profile['Espèce'], 'Chien');
    expect(profile['Sexe'], 'Mâle');
    expect(profile['Identification (puce)'], '250269608123456', reason: 'la puce reste lisible');
  });

  test('vaccins : fait, en retard ou date du prochain rappel', () {
    final vaccines = _content().vaccines;
    expect(vaccines.map((v) => v[1]), ['Rabisin', 'CHPPiL', 'Toux du chenil']);
    expect(vaccines[0][2], '#VX-99482', reason: 'le numéro de lot reste lisible');
    expect(vaccines[0][4], '12 nov. 2026');
    expect(vaccines[1][4], startsWith('En retard'));
    expect(vaccines[2][4], 'Fait');
  });

  test('visites, allergies et traitements en cours ou passés ; pas de notes', () {
    final content = _content();
    expect(content.visits.single[2], 'Bilan annuel');
    expect(content.visits.single[4], contains('Prochain contrôle : 15 avr. 2027'));
    expect(content.visits.single[4], startsWith('Poids : 29,5 kg'));
    expect(content.allergies.single[1], 'Bœuf');
    expect(content.currentTreatments.single[0], startsWith('Synulox 250 mg'));
    expect(content.pastTreatments.map((t) => t[0]), ['Milbemax', 'Metrobactin 500 mg']);
    expect(content.pastTreatments.last[3], startsWith('Arrêté le 20 janv. 2026'));
    expect(content.allText.join(' '), isNot(contains('Note privée')));
  });

  test('jamais d’e-mail ni de numéro de téléphone', () {
    final text = _content().allText.join('\n');
    expect(text, isNot(contains('@')));
    expect(text, isNot(contains('20 123 456')));
    expect(text, isNot(contains('06 12 34 56 78')));
    expect(text, contains('[e-mail masqué]'));
    expect(text, contains('[numéro masqué]'));
    expect(redactContacts('Rappel le 12/11/2025, lot #VX-99482, 29,5 kg'), 'Rappel le 12/11/2025, lot #VX-99482, 29,5 kg',
        reason: 'dates, lots et poids ne sont pas des numéros de téléphone');
  });

  test('génère un PDF valide, sur plusieurs pages si le carnet est long', () async {
    final long = [
      for (var i = 0; i < 80; i++)
        HealthEntry(
          id: 'e$i',
          type: HealthEntryType.visit,
          title: 'Visite $i',
          description: 'Observation détaillée numéro $i, tolérance « bonne ».',
          date: DateTime(2020, 1, 1).add(Duration(days: i * 10)),
        ),
    ];
    final bytes = await renderHealthPdf(
      buildHealthPdfContent(pet: _pet, entries: [..._entries, ...long], treatments: _treatments, now: _now),
      regular: pw.Font.ttf(_font('Inter-Regular.ttf')),
      bold: pw.Font.ttf(_font('Inter-Bold.ttf')),
    );
    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    expect(bytes.length, greaterThan(5000));
    expect(RegExp(r'/Type\s*/Page\b').allMatches(String.fromCharCodes(bytes)).length, greaterThan(1));
  });

  test('nom du fichier', () {
    expect(healthPdfFileName('Milo', now: _now), 'Carnet_sante_Milo_2026-11-04.pdf');
    expect(healthPdfFileName('  Nala / Bébé ', now: _now), 'Carnet_sante_Nala_Bébé_2026-11-04.pdf');
    expect(healthPdfFileName('', now: _now), 'Carnet_sante_animal_2026-11-04.pdf');
  });

  test("avec la photo de l'animal", () async {
    // PNG de 1 × 1 pixel.
    final png = Uint8List.fromList(const [
      0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52, //
      0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, 0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4,
      0x89, 0x00, 0x00, 0x00, 0x0D, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x60, 0x60, 0x60, 0xF8,
      0x0F, 0x00, 0x01, 0x04, 0x01, 0x00, 0x5F, 0xE5, 0xC3, 0x4B, 0x00, 0x00, 0x00, 0x00, 0x49, 0x45,
      0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
    ]);
    final bytes = await renderHealthPdf(
      _content(),
      regular: pw.Font.ttf(_font('Inter-Regular.ttf')),
      bold: pw.Font.ttf(_font('Inter-Bold.ttf')),
      photo: png,
    );
    expect(String.fromCharCodes(bytes), matches(RegExp(r'/Subtype\s*/Image')));
  });
}
