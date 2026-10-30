import 'package:cloud_firestore/cloud_firestore.dart';

import 'assistant_message.dart';
import 'assistant_prompt.dart';

/// Conversation enregistrée dans `users/{uid}/assistantChats/{chatId}`.
class AssistantChat {
  const AssistantChat({required this.id, required this.title, this.petId, this.petName, this.updatedAt});

  factory AssistantChat.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const {};
    return AssistantChat(
      id: doc.id,
      title: data['title'] as String? ?? 'Conversation',
      petId: data['petId'] as String?,
      petName: data['petName'] as String?,
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  final String id;
  final String title;
  final String? petId;
  final String? petName;
  final DateTime? updatedAt;
}

/// Historique privé des conversations : les [kAssistantHistoryChats] plus récentes sont gardées.
class AssistantChatRepository {
  AssistantChatRepository({FirebaseFirestore? firestore}) : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _chats(String uid) =>
      _firestore.collection('users').doc(uid).collection('assistantChats');

  CollectionReference<Map<String, dynamic>> _messages(String uid, String chatId) =>
      _chats(uid).doc(chatId).collection('messages');

  Stream<List<AssistantChat>> watchChats(String uid) => _chats(uid)
      .orderBy('updatedAt', descending: true)
      .limit(kAssistantHistoryChats)
      .snapshots()
      .map((snap) => snap.docs.map(AssistantChat.fromFirestore).toList());

  Future<List<AssistantMessage>> fetchMessages(String uid, String chatId) async {
    final snap = await _messages(uid, chatId).orderBy('createdAt').get();
    return [for (final d in snap.docs) AssistantMessage.fromMap(d.id, d.data())];
  }

  /// Crée la conversation à la première question, puis supprime les plus anciennes au-delà de la limite.
  Future<String> createChat(String uid, {required String firstQuestion, String? petId, String? petName}) async {
    final title = firstQuestion.replaceAll(RegExp(r'\s+'), ' ').trim();
    final ref = await _chats(uid).add({
      'title': title.length > 60 ? '${title.substring(0, 57)}…' : title,
      'petId': petId,
      'petName': petName,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    _pruneOldChats(uid);
    return ref.id;
  }

  /// Ajoute un message et remonte la conversation en tête de l'historique.
  Future<String> addMessage(String uid, String chatId, AssistantMessage message, {String? petId, String? petName}) async {
    final ref = _messages(uid, chatId).doc();
    final batch = _firestore.batch()
      ..set(ref, {...message.toMap(), 'createdAt': FieldValue.serverTimestamp()})
      ..update(_chats(uid).doc(chatId), {
        'updatedAt': FieldValue.serverTimestamp(),
        'petId': petId,
        'petName': petName,
      });
    await batch.commit();
    return ref.id;
  }

  Future<void> rate(String uid, String chatId, String messageId, AnswerRating? rating) =>
      _messages(uid, chatId).doc(messageId).update({'rating': rating?.firestoreValue});

  Future<void> deleteChat(String uid, String chatId) async {
    final messages = await _messages(uid, chatId).get();
    final batch = _firestore.batch();
    for (final d in messages.docs) {
      batch.delete(d.reference);
    }
    batch.delete(_chats(uid).doc(chatId));
    await batch.commit();
  }

  Future<void> _pruneOldChats(String uid) async {
    try {
      final snap = await _chats(uid).orderBy('updatedAt', descending: true).get();
      for (final doc in snap.docs.skip(kAssistantHistoryChats)) {
        await deleteChat(uid, doc.id);
      }
    } on FirebaseException {
      // Le nettoyage n'est pas bloquant.
    }
  }
}
