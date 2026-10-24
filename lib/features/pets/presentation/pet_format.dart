import '../data/pet.dart';

const _months = [
  'janvier', 'février', 'mars', 'avril', 'mai', 'juin',
  'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre',
];

const _shortMonths = ['Janv', 'Fév', 'Mars', 'Avr', 'Mai', 'Juin', 'Juil', 'Août', 'Sept', 'Oct', 'Nov', 'Déc'];

/// « 12 mai 2020 ».
String formatLongDate(DateTime date) => '${date.day} ${_months[date.month - 1]} ${date.year}';

/// « 12 / 05 / 2023 », format du champ de date de la maquette.
String formatInputDate(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')} / ${date.month.toString().padLeft(2, '0')} / ${date.year}';

/// Libellé court du mois pour l'axe du graphique de poids (« Nov », « Mars »).
String formatShortMonth(DateTime date) => _shortMonths[date.month - 1];

/// « 29,5 » : séparateur décimal français, sans zéro inutile.
String formatKg(double kg) =>
    kg.toStringAsFixed(2).replaceFirst(RegExp(r'\.?0+$'), '').replaceAll('.', ',');

/// Âge affiché sur les cartes : « 4 ans et 10 mois », « 2 ans », « 8 mois », « 3 semaines ».
String formatAge(DateTime? birthDate, {DateTime? now}) {
  if (birthDate == null) return 'Âge inconnu';
  final today = now ?? DateTime.now();
  var months = (today.year - birthDate.year) * 12 + today.month - birthDate.month;
  if (today.day < birthDate.day) months--;
  if (months < 1) {
    final weeks = today.difference(birthDate).inDays ~/ 7;
    if (weeks < 1) return 'Nouveau-né';
    return weeks == 1 ? '1 semaine' : '$weeks semaines';
  }
  final years = months ~/ 12;
  final rest = months % 12;
  if (years == 0) return '$months mois';
  final yearsText = years == 1 ? '1 an' : '$years ans';
  if (rest == 0) return yearsText;
  if (rest == 6) return '$yearsText et demi';
  return '$yearsText et $rest mois';
}

/// « il y a 12 j », « il y a 3 sem », « le mois dernier » (pastille « Dernier poids »).
String formatSince(DateTime date, {DateTime? now}) {
  final today = now ?? DateTime.now();
  final days = DateTime(today.year, today.month, today.day)
      .difference(DateTime(date.year, date.month, date.day))
      .inDays;
  if (days <= 0) return "aujourd'hui";
  if (days == 1) return 'hier';
  if (days < 14) return 'il y a $days j';
  if (days < 30) return 'il y a ${days ~/ 7} sem';
  if (days < 60) return 'le mois dernier';
  if (days < 365) return 'il y a ${days ~/ 30} mois';
  return 'il y a plus d’un an';
}

/// « il y a 8 jours » (en-tête de la carte « Poids & Croissance »).
String formatDaysAgo(DateTime date, {DateTime? now}) {
  final today = now ?? DateTime.now();
  final days = DateTime(today.year, today.month, today.day)
      .difference(DateTime(date.year, date.month, date.day))
      .inDays;
  if (days <= 0) return "aujourd'hui";
  if (days == 1) return 'hier';
  return 'il y a $days jours';
}

/// Numéro de puce tronqué pour l'affichage (« 25026... »). Le numéro complet n'apparaît que sur la fiche.
String truncateChip(String chip, {int keep = 5}) => chip.length <= keep ? chip : '${chip.substring(0, keep)}...';

/// « Stérilisé » ou « Stérilisée » selon le sexe.
String sterilizedLabel(Pet pet) => pet.isFemale ? 'Stérilisée' : 'Stérilisé';

/// « Chien • Golden Retriever » ou « Chien » si la race est inconnue.
String speciesAndBreed(Pet pet) => pet.hasBreed ? '${pet.species.label} • ${pet.breed}' : pet.species.label;
