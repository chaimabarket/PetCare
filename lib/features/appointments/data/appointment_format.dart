/// Dates en français pour le module Rendez-vous, sans package externe.
library;

const _days = ['Lundi', 'Mardi', 'Mercredi', 'Jeudi', 'Vendredi', 'Samedi', 'Dimanche'];
const _shortDays = ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim'];
const _months = [
  'janvier', 'février', 'mars', 'avril', 'mai', 'juin',
  'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre',
];
const _shortMonths = [
  'janv.', 'févr.', 'mars', 'avr.', 'mai', 'juin',
  'juil.', 'août', 'sept.', 'oct.', 'nov.', 'déc.',
];

String _two(int n) => n.toString().padLeft(2, '0');

/// 09:30
String formatTime(DateTime d) => '${_two(d.hour)}:${_two(d.minute)}';

/// Mardi 12 novembre 2024
String formatLongDate(DateTime d) => '${_days[d.weekday - 1]} ${d.day} ${_months[d.month - 1]} ${d.year}';

/// Mercredi 13 novembre
String formatDayTitle(DateTime d) => '${_days[d.weekday - 1]} ${d.day} ${_months[d.month - 1]}';

/// Novembre 2024
String formatMonthYear(DateTime d) {
  final month = _months[d.month - 1];
  return '${month[0].toUpperCase()}${month.substring(1)} ${d.year}';
}

/// 12 nov.
String formatDayMonth(DateTime d) => '${d.day} ${_shortMonths[d.month - 1]}';

/// Jeu. 14 nov.
String formatShortDayMonth(DateTime d) => '${_shortDays[d.weekday - 1]}. ${formatDayMonth(d)}';

/// Lundi 11 nov. à 10:00
String formatReminderMoment(DateTime d) =>
    '${_days[d.weekday - 1]} ${formatDayMonth(d)} à ${formatTime(d)}';

/// Mar (nom court du jour, comme dans la bande de la semaine)
String shortDayName(DateTime d) => _shortDays[d.weekday - 1];

/// 45 min, 1 h, 1 h 30
String formatDuration(Duration duration) {
  final hours = duration.inHours;
  final minutes = duration.inMinutes % 60;
  if (hours == 0) return '$minutes min';
  if (minutes == 0) return '$hours h';
  return '$hours h ${_two(minutes)}';
}

/// 45,00 DT (prix indicatif, aucun paiement en ligne)
String formatPrice(double price) => '${price.toStringAsFixed(2).replaceAll('.', ',')} DT';

/// Numéro de semaine ISO 8601 (« Semaine 46 »).
int isoWeekNumber(DateTime d) {
  final date = DateTime(d.year, d.month, d.day);
  final thursday = date.add(Duration(days: 4 - date.weekday));
  final firstDay = DateTime(thursday.year, 1, 1);
  return ((thursday.difference(firstDay).inDays) ~/ 7) + 1;
}

/// « Dans 3 jours », « Aujourd'hui », « Demain », « Il y a 2 jours ».
String formatRelativeDay(DateTime d, {DateTime? now}) {
  final today = dayOnly(now ?? DateTime.now());
  final diff = dayOnly(d).difference(today).inDays;
  if (diff == 0) return "Aujourd'hui";
  if (diff == 1) return 'Demain';
  if (diff == -1) return 'Hier';
  if (diff > 1) return 'Dans $diff jours';
  return 'Il y a ${-diff} jours';
}

/// Rappel : « Sans rappel », « 1 heure avant », « 1 jour avant », « 2 jours avant ».
String formatReminderOffset(int minutes) {
  if (minutes <= 0) return 'Sans rappel';
  if (minutes % 1440 == 0) {
    final days = minutes ~/ 1440;
    return days == 1 ? '1 jour avant' : '$days jours avant';
  }
  if (minutes % 60 == 0) {
    final hours = minutes ~/ 60;
    return hours == 1 ? '1 heure avant' : '$hours heures avant';
  }
  return '$minutes min avant';
}

/// Le même jour à minuit, pour comparer des jours sans l'heure.
DateTime dayOnly(DateTime d) => DateTime(d.year, d.month, d.day);

bool isSameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;
