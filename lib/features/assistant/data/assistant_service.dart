import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_ai/firebase_ai.dart';
import 'package:flutter/foundation.dart';

import '../../adoption/data/adoption_enums.dart';
import '../../adoption/data/adoption_listing.dart';
import 'assistant_message.dart';
import 'assistant_prompt.dart';

/// Erreur affichable telle quelle dans la conversation.
class AssistantException implements Exception {
  const AssistantException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Assistant IA : Gemini via Firebase AI Logic (gratuit, aucune clé dans l'application),
/// annonces d'adoption et compteur quotidien dans Firestore.
class AssistantService {
  AssistantService({FirebaseFirestore? firestore}) : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  // `googleAI()` = Gemini Developer API, utilisable sur le plan gratuit. Ne pas passer à `vertexAI()`.
  late final GenerativeModel _model = FirebaseAI.googleAI().generativeModel(
    model: kAssistantModel,
    systemInstruction: Content.system(kAssistantSystemPrompt),
    generationConfig: GenerationConfig(temperature: 0.4, maxOutputTokens: 700),
  );

  late final GenerativeModel _writer = FirebaseAI.googleAI().generativeModel(
    model: kAssistantModel,
    systemInstruction: Content.system(kListingWriterPrompt),
    generationConfig: GenerationConfig(temperature: 0.7, maxOutputTokens: 400),
  );

  static const limitReachedMessage = 'Vous avez atteint vos $kAssistantDailyLimit messages du jour. À demain ! 🐾';

  /// Annonces disponibles, jointes aux questions d'adoption.
  Future<List<AdoptionListing>> fetchAvailableListings() async {
    final snap = await _firestore
        .collection('adoptions')
        .where('status', isEqualTo: ListingStatus.available.firestoreValue)
        .get();
    return snap.docs.map(AdoptionListing.fromFirestore).toList()
      ..sort((a, b) => (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)));
  }

  /// Compte un message dans `users/{uid}/assistantUsage/{jour}` ; refuse au-delà de la limite.
  Future<void> countMessage(String uid) async {
    final ref = _firestore.collection('users').doc(uid).collection('assistantUsage').doc(isoDay(DateTime.now()));
    try {
      await _firestore.runTransaction((tx) async {
        final snap = await tx.get(ref);
        final count = (snap.data()?['count'] as num?)?.toInt() ?? 0;
        if (count >= kAssistantDailyLimit) throw const AssistantException(limitReachedMessage);
        tx.set(ref, {'count': count + 1, 'updatedAt': FieldValue.serverTimestamp()});
      });
    } on FirebaseException catch (e) {
      debugPrint('AssistantService.countMessage: $e');
      throw AssistantException(
        e.code == 'permission-denied' ? limitReachedMessage : "Impossible d'envoyer le message. Vérifiez votre connexion.",
      );
    }
  }

  /// Envoie la question avec les derniers messages ; renvoie la réponse au fur et à mesure (texte cumulé).
  ///
  /// [context] (date du jour, animal sélectionné, annonces) est ajouté à la question sans être affiché.
  Stream<String> reply({
    required List<AssistantMessage> history,
    required String question,
    required String context,
  }) async* {
    final previous = history.where((m) => !m.isError && m.text.isNotEmpty).toList();
    final recent = previous.skip(previous.length > kAssistantHistoryLength ? previous.length - kAssistantHistoryLength : 0);
    final contents = [
      for (final m in recent) m.fromUser ? Content.text(m.text) : Content.model([TextPart(m.text)]),
      Content.text('$context\n\nQUESTION : $question'),
    ];

    final buffer = StringBuffer();
    try {
      await for (final chunk in _model.generateContentStream(contents)) {
        final text = chunk.text;
        if (text == null || text.isEmpty) continue;
        buffer.write(text);
        yield buffer.toString();
      }
    } catch (e) {
      throw _mapError(e);
    }
    if (buffer.isEmpty) {
      throw const AssistantException('Je ne peux pas répondre à cette question. Essayez de la reformuler.');
    }
  }

  /// « Rédiger avec l'IA » : description d'annonce à partir des champs du formulaire.
  Future<String> writeListingDescription(ListingDraft draft) async {
    final age = DateTime.now().difference(draft.birthDate).inDays ~/ 30;
    final facts = [
      'Nom : ${draft.name.trim()}',
      'Espèce : ${draft.species.label}',
      if (draft.breed.trim().isNotEmpty) 'Race : ${draft.breed.trim()}',
      'Sexe : ${draft.sex.label}',
      'Âge : ${age < 12 ? '${age < 1 ? 1 : age} mois' : '${age ~/ 12} an(s)'}',
      'Gabarit : ${draft.size.label}',
      if (draft.badges.isNotEmpty) 'Personnalité : ${draft.badges.map((b) => b.label).join(', ')}',
      'Énergie : ${draft.energy.label}',
      'Entente enfants : ${draft.goodWithKids ? 'oui' : 'non'}',
      'Entente chats : ${draft.goodWithCats ? 'oui' : 'non'}',
      'Entente chiens : ${draft.goodWithDogs ? 'oui' : 'non'}',
      if (draft.needsGarden) 'Besoin d\'un jardin',
      'Peut rester seul : ${draft.okAloneHours} h',
      if (draft.story.trim().isNotEmpty) 'Notes actuelles : ${draft.story.trim()}',
    ];
    try {
      final response = await _writer.generateContent([Content.text(facts.join('\n'))]);
      final text = response.text?.trim() ?? '';
      if (text.isEmpty) throw const AssistantException("L'IA n'a pas pu rédiger de description. Réessayez.");
      return text;
    } catch (e) {
      throw _mapError(e);
    }
  }

  AssistantException _mapError(Object e) {
    if (e is AssistantException) return e;
    debugPrint('AssistantService: $e');
    return switch (e) {
      QuotaExceeded() => const AssistantException("L'assistant est très demandé, réessayez dans quelques minutes."),
      ServiceApiNotEnabled() => const AssistantException("L'assistant n'est pas encore activé pour ce projet."),
      FirebaseAIException(:final message) when message.contains('blocked') || message.contains('SAFETY') =>
        const AssistantException('Je ne peux pas répondre à cette question. Essayez de la reformuler.'),
      FirebaseAIException() =>
        const AssistantException("L'assistant n'est pas disponible pour le moment. Réessayez plus tard."),
      _ => const AssistantException('Pas de connexion internet. Vérifiez votre réseau et réessayez.'),
    };
  }
}
