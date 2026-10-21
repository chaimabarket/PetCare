/// Formate une date au style des maquettes : « 10 min », « Il y a 2h », « Hier, 18:45 », « Il y a 3j ».
String formatRelativeTime(DateTime date, {DateTime? now}) {
  final current = now ?? DateTime.now();
  final diff = current.difference(date);

  if (diff.inMinutes < 1) return "À l'instant";
  if (diff.inMinutes < 60) return '${diff.inMinutes} min';

  final today = DateTime(current.year, current.month, current.day);
  final day = DateTime(date.year, date.month, date.day);
  final daysAgo = today.difference(day).inDays;
  final time = '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';

  if (daysAgo == 0) return 'Il y a ${diff.inHours}h';
  if (daysAgo == 1) return 'Hier, $time';
  if (daysAgo < 7) return 'Il y a ${daysAgo}j';
  return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
}

/// Vrai si la date est aujourd'hui.
bool isToday(DateTime date, {DateTime? now}) {
  final current = now ?? DateTime.now();
  return date.year == current.year && date.month == current.month && date.day == current.day;
}
