import 'assistant_prompt.dart';

/// Rappel proposé par l'assistant, à confirmer par l'utilisateur.
class ReminderSuggestion {
  const ReminderSuggestion({required this.title, required this.dueAt});

  final String title;
  final DateTime dueAt;

  Map<String, dynamic> toMap() => {'title': title, 'dueAt': isoDay(dueAt)};

  static ReminderSuggestion? fromMap(Object? value) {
    if (value is! Map) return null;
    final title = value['title'];
    final due = DateTime.tryParse('${value['dueAt']}');
    if (title is! String || due == null) return null;
    return ReminderSuggestion(title: title, dueAt: due);
  }
}

/// Réponse du modèle prête à afficher : texte sans tags, annonces et rappels proposés.
class ParsedAnswer {
  const ParsedAnswer({required this.text, required this.listingIds, this.reminders = const []});

  final String text;
  final List<String> listingIds;
  final List<ReminderSuggestion> reminders;
}

final _listingTag = RegExp(r'\[\[\s*annonce\s*:\s*([A-Za-z0-9_-]+)\s*\]\]');
final _reminderTag = RegExp(r'\[\[\s*rappel\s*:\s*([^|\]]+)\|\s*(\d{4}-\d{2}-\d{2})\s*\]\]');

/// Début de tag pas encore terminé à la fin d'une réponse en cours d'écriture.
final _partialTag = RegExp(r'\[\[?[^\]]*$');

/// Retire les tags du texte et garde ce qui est valide.
///
/// - `[[annonce:ID]]` : seulement si ID est dans [knownIds] (jamais d'animal inventé), 3 au plus.
/// - `[[rappel:Intitulé|AAAA-MM-JJ]]` : seulement si [allowReminders], date dans les 2 ans à venir, 2 au plus.
///
/// [streaming] masque aussi un tag en cours d'écriture.
ParsedAnswer parseAnswer(
  String raw,
  Set<String> knownIds, {
  bool allowReminders = false,
  bool streaming = false,
  DateTime? now,
}) {
  final ids = <String>[];
  for (final match in _listingTag.allMatches(raw)) {
    final id = match.group(1)!;
    if (knownIds.contains(id) && !ids.contains(id) && ids.length < kAssistantMaxSuggestions) ids.add(id);
  }

  final reminders = <ReminderSuggestion>[];
  if (allowReminders) {
    final today = now ?? DateTime.now();
    final start = DateTime(today.year, today.month, today.day);
    final end = start.add(const Duration(days: 731));
    for (final match in _reminderTag.allMatches(raw)) {
      final title = match.group(1)!.replaceAll(RegExp(r'\s+'), ' ').trim();
      final due = DateTime.tryParse(match.group(2)!);
      if (title.length < 3 || title.length > 80 || due == null) continue;
      if (due.isBefore(start) || due.isAfter(end)) continue;
      if (reminders.length < kAssistantMaxReminders) reminders.add(ReminderSuggestion(title: title, dueAt: due));
    }
  }

  var text = raw.replaceAll(_listingTag, '').replaceAll(_reminderTag, '');
  if (streaming) text = text.replaceFirst(_partialTag, '');
  text = text
      .replaceAll(RegExp(r'[ \t]+\n'), '\n')
      .replaceAll(RegExp(r'[ \t]{2,}'), ' ')
      .replaceAll(RegExp(r'\n{3,}'), '\n\n')
      .trim();
  return ParsedAnswer(text: text, listingIds: ids, reminders: reminders);
}
