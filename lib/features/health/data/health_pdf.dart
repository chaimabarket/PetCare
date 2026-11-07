import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'health_entry.dart';
import 'health_format.dart';
import 'health_pet.dart';
import 'treatment.dart';

/// Contenu du PDF du carnet de santé d'un animal, préparé avant la mise en page (testé à part).
///
/// Le PDF ne contient jamais de coordonnées : ni l'e-mail ni le téléphone du propriétaire (ils ne sont pas
/// lus), et les e-mails ou numéros de téléphone écrits dans le texte libre des soins sont masqués.
class HealthPdfContent {
  const HealthPdfContent({
    required this.title,
    required this.generatedOn,
    required this.profile,
    required this.vaccines,
    required this.visits,
    required this.allergies,
    required this.currentTreatments,
    required this.pastTreatments,
  });

  final String title;
  final String generatedOn;

  /// Identité de l'animal : (libellé, valeur).
  final List<(String, String)> profile;

  /// Lignes des tableaux, dans l'ordre des en-têtes [vaccineHeaders]…
  final List<List<String>> vaccines;
  final List<List<String>> visits;
  final List<List<String>> allergies;
  final List<List<String>> currentTreatments;
  final List<List<String>> pastTreatments;

  static const vaccineHeaders = ['Date', 'Vaccin', 'Lot', 'Vétérinaire', 'Prochain rappel'];
  static const visitHeaders = ['Date', 'Type', 'Motif', 'Vétérinaire', 'Observations'];
  static const allergyHeaders = ['Depuis le', 'Allergie', 'Détails'];
  static const currentTreatmentHeaders = ['Médicament', 'Catégorie', 'Période', 'Posologie prescrite', 'Prescrit par'];
  static const pastTreatmentHeaders = ['Médicament', 'Période', 'Posologie prescrite', 'Fin'];

  /// Tout le texte du document, pour les tests.
  List<String> get allText => [
        title,
        generatedOn,
        for (final (label, value) in profile) ...[label, value],
        for (final table in [vaccines, visits, allergies, currentTreatments, pastTreatments])
          for (final row in table) ...row,
      ];
}

/// Nom du fichier : « Carnet_sante_Milo_2026-11-04.pdf » (lettres et chiffres seulement dans le nom de l'animal).
String healthPdfFileName(String petName, {DateTime? now}) {
  final d = now ?? DateTime.now();
  final name = petName.trim().replaceAll(RegExp(r'[^\p{L}\p{N}]+', unicode: true), '_').replaceAll(RegExp(r'^_|_$'), '');
  final day = '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  return 'Carnet_sante_${name.isEmpty ? 'animal' : name}_$day.pdf';
}

final _email = RegExp(r'[\w.+-]+@[\w-]+(\.[\w-]+)+');

/// 8 chiffres ou plus, éventuellement séparés par des espaces, points ou tirets (+216 20 123 456, 06.12.34.56.78).
final _phone = RegExp(r'(\+|\b00)?\d(?:[ .\-]?\d){7,}');

/// Masque les e-mails et les numéros de téléphone d'un texte libre.
String redactContacts(String text) =>
    text.replaceAll(_email, '[e-mail masqué]').replaceAll(_phone, '[numéro masqué]');

String _free(String? text) => text == null || text.trim().isEmpty ? '—' : redactContacts(text.trim());

String _sexLabel(String? sex) => switch (sex) {
      'male' => 'Mâle',
      'female' => 'Femelle',
      _ => '—',
    };

/// Prépare le contenu du PDF à partir du carnet déjà chargé dans l'écran.
HealthPdfContent buildHealthPdfContent({
  required HealthPet pet,
  required List<HealthEntry> entries,
  required List<Treatment> treatments,
  DateTime? now,
}) {
  final today = now ?? DateTime.now();
  final byDateDesc = [...entries]..sort((a, b) => b.date.compareTo(a.date));

  String reminder(HealthEntry e) {
    final next = e.nextReminderAt;
    if (next == null) return '—';
    if (e.reminderDone) return 'Fait';
    final late = dayOf(next).isBefore(dayOf(today));
    return late ? 'En retard (${formatHealthDate(next)})' : formatHealthDate(next);
  }

  final current = treatments.where((t) => t.statusAt(today) == TreatmentStatus.active).toList()
    ..sort((a, b) => b.startDate.compareTo(a.startDate));
  final past = treatments.where((t) => t.statusAt(today) != TreatmentStatus.active).toList()
    ..sort((a, b) => b.startDate.compareTo(a.startDate));

  String period(Treatment t) =>
      t.isSingleDay ? formatHealthDate(t.startDate) : formatHealthRange(t.startDate, t.endDate);

  return HealthPdfContent(
    title: 'Carnet de santé – ${pet.name}',
    generatedOn: 'Document généré le ${formatHealthDate(today)}',
    profile: [
      ('Nom', pet.name),
      ('Espèce', pet.speciesText),
      ('Race', pet.breed?.trim().isNotEmpty == true ? pet.breed!.trim() : '—'),
      ('Sexe', _sexLabel(pet.sex)),
      (
        'Naissance',
        pet.birthDate == null
            ? '—'
            : '${formatHealthDate(pet.birthDate!)} (${formatPetAge(pet.birthDate!, now: today)})',
      ),
      ('Identification (puce)', pet.chipNumber ?? '—'),
    ],
    vaccines: [
      for (final e in byDateDesc)
        if (e.type == HealthEntryType.vaccine)
          [formatHealthDate(e.date), _free(e.vaccineName ?? e.title), e.batchNumber ?? '—', _free(e.practitioner), reminder(e)],
    ],
    visits: [
      for (final e in byDateDesc)
        if (e.type == HealthEntryType.visit || e.type == HealthEntryType.exam)
          [
            formatHealthDate(e.date),
            e.type == HealthEntryType.visit ? 'Visite' : 'Examen',
            _free(e.title),
            _free(e.practitioner),
            [
              if (e.weightKg != null) 'Poids : ${formatKg(e.weightKg!).replaceAll('.', ',')} kg',
              if (e.description != null && e.description!.trim().isNotEmpty) _free(e.description),
              if (e.type == HealthEntryType.visit && e.nextReminderAt != null)
                'Prochain contrôle : ${formatHealthDate(e.nextReminderAt!)}',
            ].join('\n').ifEmpty('—'),
          ],
    ],
    allergies: [
      for (final e in byDateDesc)
        if (e.type == HealthEntryType.allergy) [formatHealthDate(e.date), _free(e.title), _free(e.description)],
    ],
    currentTreatments: [
      for (final t in current)
        [
          [_free(t.name), if (t.subtitle != null) _free(t.subtitle)].join('\n'),
          _free(t.category),
          period(t),
          _free(t.posology),
          _free(t.practitioner),
        ],
    ],
    pastTreatments: [
      for (final t in past)
        [
          _free(t.name),
          period(t),
          _free(t.posology),
          t.stoppedAt == null
              ? 'Terminé'
              : 'Arrêté le ${formatHealthDate(t.stoppedAt!)}${t.stopReason == null ? '' : ' : ${_free(t.stopReason)}'}',
        ],
    ],
  );
}

extension on String {
  String ifEmpty(String fallback) => isEmpty ? fallback : this;
}

const _teal = PdfColor.fromInt(0xFF0F766E);
const _grey = PdfColor.fromInt(0xFF6B7280);
const _light = PdfColor.fromInt(0xFFEFF4FF);

/// Met en page le PDF (A4). [regular] et [bold] : police Inter embarquée (accents, « œ », « € »).
Future<Uint8List> renderHealthPdf(
  HealthPdfContent content, {
  required pw.Font regular,
  required pw.Font bold,
  Uint8List? photo,
}) {
  final doc = pw.Document(
    title: content.title,
    author: 'PetCare Community',
    theme: pw.ThemeData.withFont(base: regular, bold: bold),
  );

  // Titre et tableau à plat dans la page (pas dans une Column) : MultiPage peut ainsi couper un long tableau.
  List<pw.Widget> section(String title, List<String> headers, List<List<String>> rows,
      {Map<int, pw.TableColumnWidth>? widths}) {
    return [
      pw.SizedBox(height: 16),
      pw.Text(title, style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: _teal)),
      pw.SizedBox(height: 6),
      if (rows.isEmpty)
        pw.Text('Aucune donnée.', style: const pw.TextStyle(fontSize: 9, color: _grey))
      else
        pw.TableHelper.fromTextArray(
          headers: headers,
          data: rows,
          columnWidths: widths,
          headerStyle: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
          headerDecoration: const pw.BoxDecoration(color: _teal),
          cellStyle: const pw.TextStyle(fontSize: 9),
          cellAlignment: pw.Alignment.topLeft,
          headerAlignment: pw.Alignment.centerLeft,
          oddRowDecoration: const pw.BoxDecoration(color: _light),
          border: null,
          cellPadding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
        ),
    ];
  }

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      footer: (context) => pw.Column(
        children: [
          pw.Divider(color: _grey, thickness: 0.5),
          pw.Row(
            children: [
              pw.Expanded(
                child: pw.Text(
                  "Informations saisies par le propriétaire dans PetCare Community. Ce document ne remplace pas "
                  "un certificat ni un carnet vétérinaire officiel.",
                  style: const pw.TextStyle(fontSize: 7, color: _grey),
                ),
              ),
              pw.SizedBox(width: 12),
              pw.Text('Page ${context.pageNumber}/${context.pagesCount}', style: const pw.TextStyle(fontSize: 8, color: _grey)),
            ],
          ),
        ],
      ),
      build: (context) => [
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            if (photo != null) ...[
              pw.ClipOval(child: pw.Image(pw.MemoryImage(photo), width: 56, height: 56, fit: pw.BoxFit.cover)),
              pw.SizedBox(width: 12),
            ],
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(content.title, style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
                  pw.Text(content.generatedOn, style: const pw.TextStyle(fontSize: 9, color: _grey)),
                ],
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 12),
        pw.Container(
          padding: const pw.EdgeInsets.all(10),
          decoration: pw.BoxDecoration(color: _light, borderRadius: pw.BorderRadius.circular(6)),
          child: pw.Wrap(
            spacing: 24,
            runSpacing: 6,
            children: [
              for (final (label, value) in content.profile)
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(label, style: const pw.TextStyle(fontSize: 8, color: _grey)),
                    pw.Text(value, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                  ],
                ),
            ],
          ),
        ),
        ...section('Vaccins et rappels', HealthPdfContent.vaccineHeaders, content.vaccines),
        ...section('Visites et examens', HealthPdfContent.visitHeaders, content.visits,
            widths: {4: const pw.FlexColumnWidth(2.5)}),
        ...section('Allergies', HealthPdfContent.allergyHeaders, content.allergies,
            widths: {2: const pw.FlexColumnWidth(3)}),
        ...section('Traitements en cours', HealthPdfContent.currentTreatmentHeaders, content.currentTreatments,
            widths: {3: const pw.FlexColumnWidth(2.5)}),
        ...section('Traitements passés', HealthPdfContent.pastTreatmentHeaders, content.pastTreatments,
            widths: {2: const pw.FlexColumnWidth(2.5), 3: const pw.FlexColumnWidth(2)}),
      ],
    ),
  );
  return doc.save();
}
