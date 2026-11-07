import 'package:intl/intl.dart';

import '../../../l10n/app_localizations.dart';
import '../data/pet.dart';

/// « 12 mai 2020 » / « May 12, 2020 ».
String formatLongDate(AppLocalizations l, DateTime date) => DateFormat.yMMMMd(l.localeName).format(date);

/// « 12 / 05 / 2023 », format du champ de date de la maquette.
String formatInputDate(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')} / ${date.month.toString().padLeft(2, '0')} / ${date.year}';

/// Mois abrégé pour l'axe du graphique de poids (« nov. », « Mar »), avec majuscule.
String formatShortMonth(AppLocalizations l, DateTime date) {
  final text = DateFormat.MMM(l.localeName).format(date);
  return text.isEmpty ? text : text[0].toUpperCase() + text.substring(1);
}

/// « 29,5 » en français, « 29.5 » en anglais, sans zéro inutile.
String formatKg(AppLocalizations l, double kg) => NumberFormat('0.##', l.localeName).format(kg);

String speciesLabel(AppLocalizations l, PetSpecies species) => switch (species) {
      PetSpecies.dog => l.speciesDog,
      PetSpecies.cat => l.speciesCat,
      PetSpecies.rabbit => l.speciesRabbit,
      PetSpecies.rodent => l.speciesRodent,
      PetSpecies.bird => l.speciesBird,
      PetSpecies.other => l.speciesOther,
    };

String sexLabel(AppLocalizations l, PetSex sex) => sex == PetSex.female ? l.sexFemale : l.sexMale;

/// Âge affiché sur les cartes : « 4 ans et 10 mois », « 2 ans et demi », « 8 mois », « 3 semaines ».
String formatAge(AppLocalizations l, DateTime? birthDate, {DateTime? now}) {
  if (birthDate == null) return l.petsAgeUnknown;
  final today = now ?? DateTime.now();
  var months = (today.year - birthDate.year) * 12 + today.month - birthDate.month;
  if (today.day < birthDate.day) months--;
  if (months < 1) {
    final weeks = today.difference(birthDate).inDays ~/ 7;
    return weeks < 1 ? l.petsAgeNewborn : l.petsAgeWeeks(weeks);
  }
  final years = months ~/ 12;
  final rest = months % 12;
  if (years == 0) return l.petsAgeMonths(months);
  final yearsText = l.petsAgeYears(years);
  if (rest == 0) return yearsText;
  if (rest == 6) return l.petsAgeYearsHalf(yearsText);
  return l.petsAgeYearsMonths(yearsText, rest);
}

int _daysSince(DateTime date, DateTime? now) {
  final today = now ?? DateTime.now();
  return DateTime(today.year, today.month, today.day).difference(DateTime(date.year, date.month, date.day)).inDays;
}

/// « il y a 12 j », « il y a 3 sem », « le mois dernier » (pastille « Dernier poids »).
String formatSince(AppLocalizations l, DateTime date, {DateTime? now}) {
  final days = _daysSince(date, now);
  if (days <= 0) return l.petsSinceToday;
  if (days == 1) return l.petsSinceYesterday;
  if (days < 14) return l.petsSinceDays(days);
  if (days < 30) return l.petsSinceWeeks(days ~/ 7);
  if (days < 60) return l.petsSinceLastMonth;
  if (days < 365) return l.petsSinceMonths(days ~/ 30);
  return l.petsSinceOverYear;
}

/// « il y a 8 jours » (en-tête de la carte « Poids & Croissance »).
String formatDaysAgo(AppLocalizations l, DateTime date, {DateTime? now}) {
  final days = _daysSince(date, now);
  if (days <= 0) return l.petsSinceToday;
  if (days == 1) return l.petsSinceYesterday;
  return l.petsDaysAgo(days);
}

/// Numéro de puce tronqué pour l'affichage (« 25026... »). Le numéro complet n'apparaît que sur la fiche.
String truncateChip(String chip, {int keep = 5}) => chip.length <= keep ? chip : '${chip.substring(0, keep)}...';

/// « Stérilisé » ou « Stérilisée » selon le sexe.
String sterilizedLabel(AppLocalizations l, Pet pet) => pet.isFemale ? l.petsSterilizedFemale : l.petsSterilizedMale;

/// Espèce affichée : avec « Autre », c'est l'animal saisi librement (« Ours », « Tigre »…), gardé dans `breed`.
String petKindLabel(AppLocalizations l, Pet pet) =>
    pet.species == PetSpecies.other && pet.hasBreed ? pet.breed! : speciesLabel(l, pet.species);

/// « Chien • Golden Retriever », « Chien » si la race est inconnue, « Ours » pour un animal saisi librement.
String speciesAndBreed(AppLocalizations l, Pet pet) =>
    pet.hasBreed && pet.species != PetSpecies.other ? '${speciesLabel(l, pet.species)} • ${pet.breed}' : petKindLabel(l, pet);
