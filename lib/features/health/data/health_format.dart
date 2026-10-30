/// Dates, durées et montants en français pour le module Santé, sans package externe.
library;

const _shortMonths = [
  'janv.', 'févr.', 'mars', 'avr.', 'mai', 'juin',
  'juil.', 'août', 'sept.', 'oct.', 'nov.', 'déc.',
];
const _shortDays = ['Lun.', 'Mar.', 'Mer.', 'Jeu.', 'Ven.', 'Sam.', 'Dim.'];

String _two(int n) => n.toString().padLeft(2, '0');

DateTime dayOf(DateTime d) => DateTime(d.year, d.month, d.day);

/// 01 sept. 2024
String formatHealthDate(DateTime d) => '${_two(d.day)} ${_shortMonths[d.month - 1]} ${d.year}';

/// 08 nov.
String formatShortHealthDate(DateTime d) => '${_two(d.day)} ${_shortMonths[d.month - 1]}';

/// 12 / 11 / 2025
String formatSlashDate(DateTime d) => '${_two(d.day)} / ${_two(d.month)} / ${d.year}';

/// « Du 08 nov. au 18 nov. 2024 » (l'année n'est répétée que si elle change).
String formatHealthRange(DateTime start, DateTime end) {
  final from = start.year == end.year ? formatShortHealthDate(start) : formatHealthDate(start);
  return 'Du $from au ${formatHealthDate(end)}';
}

/// « Aujourd'hui • 12 nov. 2024 » pour le champ date du formulaire.
String formatCareDate(DateTime d, {DateTime? now}) {
  final today = dayOf(now ?? DateTime.now());
  return dayOf(d) == today ? "Aujourd'hui • ${formatHealthDate(d)}" : formatHealthDate(d);
}

/// « Dans 15 jours », « Dans 3 mois », « Dans 1 an », « Aujourd'hui », « En retard de 2 jours ».
String formatTimeUntil(DateTime d, {DateTime? now}) {
  final days = dayOf(d).difference(dayOf(now ?? DateTime.now())).inDays;
  if (days == 0) return "Aujourd'hui";
  if (days == 1) return 'Demain';
  if (days < 0) return days == -1 ? 'En retard de 1 jour' : 'En retard de ${-days} jours';
  if (days < 45) return 'Dans $days jours';
  if (days < 335) return 'Dans ${(days / 30.4).round()} mois';
  final years = (days / 365.25).round();
  return years <= 1 ? 'Dans 1 an' : 'Dans $years ans';
}

/// Âge de l'animal : « 4 ans et 10 mois » (ou « 4 ans » en version courte).
String formatPetAge(DateTime birth, {bool short = false, DateTime? now}) {
  final today = now ?? DateTime.now();
  var months = (today.year - birth.year) * 12 + today.month - birth.month;
  if (today.day < birth.day) months--;
  if (months < 1) {
    final weeks = today.difference(birth).inDays ~/ 7;
    return weeks <= 1 ? '1 semaine' : '$weeks semaines';
  }
  final years = months ~/ 12;
  final rest = months % 12;
  if (years == 0) return '$rest mois';
  final yearsText = years == 1 ? '1 an' : '$years ans';
  if (short || rest == 0) return yearsText;
  return '$yearsText et $rest mois';
}

/// Prochaine prise : « Aujourd'hui 14h00 », « Ce soir 20h00 », « Demain 08h00 », « Lun. 18 nov. 08h00 ».
String formatDoseMoment(DateTime d, {DateTime? now}) {
  final today = dayOf(now ?? DateTime.now());
  final time = '${_two(d.hour)}h${_two(d.minute)}';
  final days = dayOf(d).difference(today).inDays;
  if (days == 0) return d.hour >= 18 ? 'Ce soir $time' : "Aujourd'hui $time";
  if (days == 1) return 'Demain $time';
  return '${_shortDays[d.weekday - 1]} ${formatShortHealthDate(d)} $time';
}

/// Date et heure d'une prise notée : « 12 nov. 2024 à 08:05 ».
String formatDoseLog(DateTime d) => '${formatHealthDate(d)} à ${_two(d.hour)}:${_two(d.minute)}';

/// « début mars 2025 », « mi-mars 2025 », « fin mars 2025 ».
String formatApproxMonth(DateTime d) {
  const months = [
    'janvier', 'février', 'mars', 'avril', 'mai', 'juin',
    'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre',
  ];
  final part = d.day <= 10 ? 'début' : (d.day <= 20 ? 'mi-' : 'fin');
  final month = months[d.month - 1];
  return part == 'mi-' ? 'mi-$month ${d.year}' : '$part $month ${d.year}';
}

/// 65,00 €
String formatEuro(double value) => '${value.toStringAsFixed(2).replaceAll('.', ',')} €';

/// 320 Ko, 1.4 Mo
String formatFileSize(int bytes) {
  if (bytes < 1024 * 1024) return '${(bytes / 1024).ceil()} Ko';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} Mo';
}

/// 31.4 (sans zéro inutile) pour les poids.
String formatKg(double kg) {
  final text = kg.toStringAsFixed(1);
  return text.endsWith('.0') ? text.substring(0, text.length - 2) : text;
}

/// Espèce du module 1 (`dog`, `cat`…) en français.
String speciesLabel(String? species) => switch (species) {
      'dog' => 'Chien',
      'cat' => 'Chat',
      'rabbit' => 'Lapin',
      'rodent' => 'Rongeur',
      'bird' => 'Oiseau',
      _ => 'Animal',
    };

/// « À la une ce printemps », « cet été »…
String seasonLabel(DateTime d) => switch (d.month) {
      3 || 4 || 5 => 'ce printemps',
      6 || 7 || 8 => 'cet été',
      9 || 10 || 11 => 'cet automne',
      _ => 'cet hiver',
    };
