/// Lecture d'une ordonnance ou d'une vignette vaccinale à partir du texte reconnu sur la photo
/// (ML Kit, voir `text_scanner.dart`).
///
/// Dart pur, testé à part. On ne propose que ce qui sert à pré-remplir un formulaire : nom du vaccin ou du
/// médicament, date, numéro de lot, vétérinaire. **Jamais de posologie ni de diagnostic** : l'utilisateur
/// recopie lui-même la posologie prescrite et vérifie chaque champ avant d'enregistrer.
library;

/// Ce que le scan a trouvé ; chaque champ peut manquer.
class ScanResult {
  const ScanResult({
    this.productName,
    this.isVaccine = false,
    this.date,
    this.nextDate,
    this.batchNumber,
    this.practitioner,
  });

  /// Nom du vaccin ou du médicament, avec son dosage commercial s'il est collé au nom (« Synulox 250 mg »).
  final String? productName;

  /// Le texte parle d'un vaccin (nom connu, « vaccin », « vignette »…).
  final bool isVaccine;

  /// Date de l'acte ou de la prescription (jamais une date de péremption).
  final DateTime? date;

  /// Date du prochain rappel, si elle est écrite près de « rappel » ou « prochain ».
  final DateTime? nextDate;
  final String? batchNumber;
  final String? practitioner;

  bool get isEmpty =>
      productName == null && date == null && nextDate == null && batchNumber == null && practitioner == null;
}

/// Noms commerciaux et valences de vaccins vétérinaires courants.
const _vaccineNames = [
  'Rabisin', 'Nobivac', 'Eurican', 'Versican', 'Canigen', 'Vanguard', 'Duramune', 'Dohyvac', 'Rabigen',
  'Purevax', 'Leucogen', 'Feligen', 'Felocell', 'Fevaxyn', 'Leucofeligen', 'Pneumodog', 'Bronchi-Shield',
  'CHPPiL', 'CHPPi', 'DHPPiL', 'DHPPi', 'DAPPi', 'RCPCh', 'Leptospirose', 'Toux du chenil', 'Typhus',
  'Coryza', 'Leucose', 'Parvovirose', 'Rage',
];

/// Médicaments vétérinaires courants (antiparasitaires, antibiotiques, anti-inflammatoires, collyres).
const _medicineNames = [
  'Synulox', 'Clavaseptin', 'Kesium', 'Metrobactin', 'Marbocyl', 'Baytril', 'Doxyval', 'Ronaxan',
  'Milbemax', 'Drontal', 'Milpro', 'Panacur', 'Profender', 'Cestem', 'Dolthene',
  'Frontline', 'Advocate', 'Advantage', 'Advantix', 'Bravecto', 'Nexgard', 'Simparica', 'Credelio',
  'Stronghold', 'Broadline', 'Seresto', 'Scalibor',
  'Metacam', 'Previcox', 'Rimadyl', 'Onsior', 'Galliprant', 'Meloxidyl', 'Prednisolone', 'Dexadreson',
  'Fradexam', 'Tobrex', 'Ocryl', 'Isathal', 'Surolan', 'Easotic', 'Osurnia',
  'Amoxicilline', 'Doxycycline', 'Métronidazole', 'Metronidazole', 'Céfalexine', 'Cefalexine',
];

/// Termes génériques de vaccin, gardés seulement si aucun nom commercial n'est trouvé.
const _genericVaccineTerms = {
  'Leptospirose', 'Toux du chenil', 'Typhus', 'Coryza', 'Leucose', 'Parvovirose', 'Rage',
};

const _months = {
  'janv': 1, 'janvier': 1, 'fev': 2, 'fevr': 2, 'fevrier': 2, 'mars': 3, 'avr': 4, 'avril': 4, 'mai': 5,
  'juin': 6, 'juil': 7, 'juillet': 7, 'aout': 8, 'sept': 9, 'septembre': 9, 'oct': 10, 'octobre': 10,
  'nov': 11, 'novembre': 11, 'dec': 12, 'decembre': 12,
};

final _numericDate = RegExp(r'\b(\d{1,2})[/.\-](\d{1,2})[/.\-](\d{4}|\d{2})\b');
final _textDate = RegExp(
  r'\b(\d{1,2})(?:er)?\s+(janv(?:ier)?|f[ée]vr?(?:ier)?|mars|avr(?:il)?|mai|juin|juil(?:let)?|ao[uû]t|sept(?:embre)?|oct(?:obre)?|nov(?:embre)?|d[ée]c(?:embre)?)\.?\s+(\d{4})\b',
  caseSensitive: false,
);

/// Lignes de péremption ou de fabrication : leurs dates ne sont pas celles du soin.
final _expiryLine = RegExp(r'\bexp|p[ée]rem|valable|use by|utiliser avant|\bfab\b|fabrication|\bmfg\b', caseSensitive: false);
final _nextLine = RegExp(r'rappel|prochain|[àa] refaire|renouvel|revaccin', caseSensitive: false);

final _batch = RegExp(
  r'(?:\bn[°o]\s*(?:de\s*)?lot\b|\blot\s*n[°o]?|\blot\b|\bbatch\b|\bch\.?-?b\b)\s*[:#.\-]?\s*([A-Z0-9][A-Z0-9\-/]{2,19})',
  caseSensitive: false,
);

final _doctor = RegExp(r'\b(?:dr|docteur|doctoresse)\b\.?\s+', caseSensitive: false);
final _clinic = RegExp(r'\b(?:clinique|cabinet|centre|h[oô]pital)\s+v[ée]t', caseSensitive: false);
final _label = RegExp(
  r'^(?:vaccins?|m[ée]dicaments?|produit|sp[ée]cialit[ée]|traitement)\s*[:\-]\s*(.*)$',
  caseSensitive: false,
);

/// Numéros de téléphone et e-mails : retirés de la ligne du vétérinaire.
final _contact = RegExp(r'[\w.+-]+@[\w-]+(\.[\w-]+)+|(\+|\b00)?\d(?:[ .\-]?\d){7,}');

String _ascii(String s) => s
    .toLowerCase()
    .replaceAll(RegExp('[éèêë]'), 'e')
    .replaceAll(RegExp('[àâä]'), 'a')
    .replaceAll(RegExp('[ûüù]'), 'u')
    .replaceAll(RegExp('[ôö]'), 'o')
    .replaceAll(RegExp('[îï]'), 'i')
    .replaceAll('ç', 'c');

DateTime? _validDate(int day, int month, int year) {
  if (year < 100) year += 2000;
  if (month < 1 || month > 12 || day < 1 || year < 1990 || year > 2100) return null;
  final date = DateTime(year, month, day);
  return date.month == month && date.day == day ? date : null;
}

Iterable<DateTime> _datesIn(String line) sync* {
  for (final m in _numericDate.allMatches(line)) {
    final date = _validDate(int.parse(m[1]!), int.parse(m[2]!), int.parse(m[3]!));
    if (date != null) yield date;
  }
  for (final m in _textDate.allMatches(line)) {
    final month = _months[_ascii(m[2]!)];
    final date = month == null ? null : _validDate(int.parse(m[1]!), month, int.parse(m[3]!));
    if (date != null) yield date;
  }
}

/// Une unité de dosage commercial collée au nom (« 250 mg », « 2,5ml »).
final _strength = RegExp(r'^\d+(?:[.,]\d+)?(?:\s?(?:mg|ml|g|µg|mcg|ui|%))?$', caseSensitive: false);
final _unit = RegExp(r'^(?:mg|ml|g|µg|mcg|ui|%)$', caseSensitive: false);

/// Suite du nom sur la même ligne : valence (« DHPPi », « L4 ») ou dosage commercial, 3 mots au plus.
String _withSuffix(String line, int start, String name) {
  final words = line.substring(start + name.length).trim().split(RegExp(r'\s+'));
  final kept = <String>[];
  for (final word in words.take(4)) {
    final clean = word.replaceAll(RegExp(r'[,;:()]+$'), '');
    if (clean.isEmpty) break;
    final looksLikeValence = RegExp(r'^[A-Z][A-Za-z0-9+]{0,7}$').hasMatch(clean) &&
        (RegExp(r'[A-Z].*[A-Z0-9]').hasMatch(clean) || const {'Rabies', 'Tricat', 'Ducat', 'Plus', 'Grand', 'Chien', 'Chat'}.contains(clean));
    final isStrength = _strength.hasMatch(clean) || (kept.isNotEmpty && _unit.hasMatch(clean) && _strength.hasMatch(kept.last));
    if (!looksLikeValence && !isStrength) break;
    kept.add(clean);
    if (clean != word) break;
  }
  return [name, ...kept].join(' ');
}

({String name, bool vaccine, int index})? _knownProduct(String text) {
  ({String name, bool vaccine, int index})? best;
  for (final (names, vaccine) in [(_vaccineNames, true), (_medicineNames, false)]) {
    for (final name in names) {
      final m = RegExp('\\b${RegExp.escape(name)}\\b', caseSensitive: false).firstMatch(text);
      if (m == null) continue;
      // Un terme générique (« Rage ») ne l'emporte pas sur un nom commercial trouvé ailleurs.
      final generic = _genericVaccineTerms.contains(name);
      final rank = m.start + (generic ? text.length : 0);
      if (best == null || rank < best.index) best = (name: name, vaccine: vaccine, index: rank);
    }
  }
  return best;
}

String? _practitionerIn(List<String> lines) {
  String? doctor;
  String? clinic;
  for (final line in lines) {
    final clean = line.replaceAll(_contact, '').replaceAll(RegExp(r'\b(?:t[ée]l|tel|fax|e-?mail)\b\.?\s*:?', caseSensitive: false), '');
    final cut = clean.split(RegExp(r'\s[-–|]\s|,|;')).first.trim();
    if (doctor == null) {
      final m = _doctor.firstMatch(cut);
      if (m != null) {
        final name = cut.substring(m.end).trim();
        if (name.isNotEmpty) doctor = 'Dr. ${name.split(RegExp(r'\s+')).take(3).join(' ')}';
      }
    }
    if (clinic == null && _clinic.hasMatch(cut)) clinic = cut.substring(_clinic.firstMatch(cut)!.start).trim();
  }
  final parts = [?doctor, ?clinic];
  if (parts.isEmpty) return null;
  final value = parts.join(' • ');
  return value.length > 120 ? value.substring(0, 120).trim() : value;
}

/// Analyse le texte reconnu sur la photo d'une ordonnance ou d'une vignette vaccinale.
ScanResult parsePrescriptionText(String text, {DateTime? now}) {
  final today = now ?? DateTime.now();
  final lines = [
    for (final raw in text.split(RegExp(r'\r?\n')))
      if (raw.trim().isNotEmpty) raw.trim().replaceAll(RegExp(r'\s+'), ' '),
  ];
  final joined = lines.join('\n');

  // Nom : la valeur d'une étiquette « Vaccin : … » / « Médicament : … » (le plus explicite), sinon un nom connu.
  String? product;
  var isVaccine = RegExp(r'\bvaccin|\bvignette|\bvaccination', caseSensitive: false).hasMatch(joined);
  for (var i = 0; i < lines.length; i++) {
    final m = _label.firstMatch(lines[i]);
    if (m == null) continue;
    final value = m[1]!.trim().isNotEmpty ? m[1]!.trim() : (i + 1 < lines.length ? lines[i + 1] : '');
    // « Traitement : 1 comprimé matin et soir » est une posologie, pas un nom de produit.
    if (value.isNotEmpty && !RegExp(r'^\d').hasMatch(value)) {
      product = value.length > 60 ? value.substring(0, 60).trim() : value;
      if (lines[i].toLowerCase().startsWith('vaccin') || (_knownProduct(value)?.vaccine ?? false)) isVaccine = true;
      break;
    }
  }
  final known = product == null ? _knownProduct(joined) : null;
  if (known != null) {
    final line = lines.firstWhere((l) => l.toLowerCase().contains(known.name.toLowerCase()));
    final start = line.toLowerCase().indexOf(known.name.toLowerCase());
    product = _withSuffix(line, start, line.substring(start, start + known.name.length));
    isVaccine = isVaccine || known.vaccine;
  }

  // Dates : celle du soin (la plus récente qui n'est pas dans le futur), et le prochain rappel s'il est écrit.
  final actDates = <DateTime>[];
  final nextDates = <DateTime>[];
  for (final line in lines) {
    if (_expiryLine.hasMatch(line)) continue;
    final dates = _datesIn(line).toList();
    (_nextLine.hasMatch(line) ? nextDates : actDates).addAll(dates);
  }
  final latestAllowed = DateTime(today.year, today.month, today.day).add(const Duration(days: 1));
  final pastDates = actDates.where((d) => d.isBefore(latestAllowed)).toList()..sort();
  final date = pastDates.isEmpty ? null : pastDates.last;
  final upcoming = nextDates.where((d) => date == null || d.isAfter(date)).toList()..sort();

  final batch = _batch.allMatches(joined).map((m) => m[1]!.toUpperCase()).where((b) => RegExp(r'\d').hasMatch(b));

  return ScanResult(
    productName: product,
    isVaccine: isVaccine,
    date: date,
    nextDate: upcoming.isEmpty ? null : upcoming.first,
    batchNumber: batch.isEmpty ? null : batch.first,
    practitioner: _practitionerIn(lines),
  );
}
