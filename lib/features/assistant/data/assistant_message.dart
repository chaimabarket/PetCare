import 'answer_parser.dart';

/// Avis de l'utilisateur sur une réponse (👍 / 👎).
enum AnswerRating {
  up('up'),
  down('down');

  const AnswerRating(this.firestoreValue);

  final String firestoreValue;

  static AnswerRating? tryParse(Object? value) {
    for (final r in values) {
      if (r.firestoreValue == value) return r;
    }
    return null;
  }
}

/// Message de la conversation avec l'assistant.
class AssistantMessage {
  const AssistantMessage.user(this.text, {this.id})
      : fromUser = true,
        listingIds = const [],
        reminders = const [],
        rating = null,
        isError = false;

  const AssistantMessage.assistant(
    this.text, {
    this.id,
    this.listingIds = const [],
    this.reminders = const [],
    this.rating,
    this.isError = false,
  }) : fromUser = false;

  factory AssistantMessage.fromMap(String id, Map<String, dynamic> data) {
    final text = data['text'] as String? ?? '';
    if (data['role'] == 'user') return AssistantMessage.user(text, id: id);
    return AssistantMessage.assistant(
      text,
      id: id,
      listingIds: [for (final l in (data['listingIds'] as List<dynamic>? ?? const [])) '$l'],
      reminders: [
        for (final r in (data['reminders'] as List<dynamic>? ?? const [])) ?ReminderSuggestion.fromMap(r),
      ],
      rating: AnswerRating.tryParse(data['rating']),
    );
  }

  /// Identifiant dans l'historique (`null` pour un visiteur ou une erreur).
  final String? id;
  final bool fromUser;
  final String text;

  /// Annonces d'adoption proposées, affichées en cartes sous le message.
  final List<String> listingIds;

  /// Rappels proposés (animal sélectionné).
  final List<ReminderSuggestion> reminders;

  final AnswerRating? rating;

  /// Message d'erreur affiché à la place d'une réponse (non envoyé au modèle, non enregistré).
  final bool isError;

  AssistantMessage copyWith({String? id, AnswerRating? rating, bool clearRating = false}) => fromUser
      ? AssistantMessage.user(text, id: id ?? this.id)
      : AssistantMessage.assistant(
          text,
          id: id ?? this.id,
          listingIds: listingIds,
          reminders: reminders,
          rating: clearRating ? null : rating ?? this.rating,
          isError: isError,
        );

  Map<String, dynamic> toMap() => {
        'role': fromUser ? 'user' : 'model',
        'text': text,
        if (listingIds.isNotEmpty) 'listingIds': listingIds,
        if (reminders.isNotEmpty) 'reminders': [for (final r in reminders) r.toMap()],
      };
}
