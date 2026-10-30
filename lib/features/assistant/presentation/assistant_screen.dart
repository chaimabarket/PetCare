import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../core/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../adoption/data/adoption_listing.dart';
import '../../adoption/data/adoption_repository.dart';
import '../../adoption/presentation/widgets/adoption_widgets.dart';
import '../data/answer_parser.dart';
import '../data/assistant_chat_repository.dart';
import '../data/assistant_message.dart';
import '../data/assistant_pet.dart';
import '../data/assistant_prompt.dart';
import '../data/assistant_service.dart';
import '../data/listing_context.dart';
import 'assistant_history_screen.dart';
import 'widgets/assistant_widgets.dart';
import 'widgets/reminder_sheet.dart';

/// Assistant PetCare : conversation avec l'IA (maquettes Stitch M2 à M6).
///
/// - Visiteur : questions générales et suggestions d'adoption.
/// - Connecté : en plus, choix d'un de ses animaux (fiche et carnet joints), rappels,
///   historique et avis 👍 / 👎.
///
/// [startWithAdoption] envoie directement « Trouver mon compagnon » (bannière du fil d'adoption).
class AssistantScreen extends StatefulWidget {
  const AssistantScreen({super.key, this.startWithAdoption = false});

  final bool startWithAdoption;

  @override
  State<AssistantScreen> createState() => _AssistantScreenState();
}

class _AssistantScreenState extends State<AssistantScreen> {
  final _service = AssistantService();
  final _chatRepository = AssistantChatRepository();
  final _petRepository = AssistantPetRepository();
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final _user = FirebaseAuth.instance.currentUser;

  final _messages = <AssistantMessage>[];

  /// Annonces connues de la conversation, pour afficher les cartes proposées.
  final _listings = <String, AdoptionListing>{};

  /// Rappels déjà créés, par index de message.
  final _createdReminders = <int, Set<String>>{};

  StreamSubscription<List<AssistantPet>>? _petsSubscription;
  List<AssistantPet> _pets = const [];
  AssistantPet? _pet;

  /// Animal à resélectionner à l'ouverture d'une conversation de l'historique.
  String? _pendingPetId;

  /// Conversation enregistrée (`null` tant qu'aucune question n'a été posée, et pour un visiteur).
  String? _chatId;

  StreamSubscription<String>? _subscription;
  bool _busy = false;
  bool _loadingChat = false;

  /// Réponse en cours d'écriture (texte brut, avec les tags).
  String? _streaming;
  Set<String> _streamingIds = const {};
  AssistantPet? _streamingPet;
  String _pendingQuestion = '';

  bool get _signedIn => _user != null;

  @override
  void initState() {
    super.initState();
    final user = _user;
    if (user != null) {
      _petsSubscription = _petRepository.watchPets(user.uid).listen((pets) {
        if (!mounted) return;
        setState(() {
          _pets = pets;
          if (_pendingPetId != null) {
            _pet = pets.where((p) => p.id == _pendingPetId).firstOrNull;
            _pendingPetId = null;
          } else if (_pet != null) {
            _pet = pets.where((p) => p.id == _pet!.id).firstOrNull;
          }
        });
      });
    }
    if (widget.startWithAdoption) {
      final suggestion = recommendedQuestions(signedIn: _signedIn).firstWhere((s) => s.adoption);
      WidgetsBinding.instance.addPostFrameCallback((_) => _send(suggestion.question, adoption: true));
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _petsSubscription?.cancel();
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  // ------------------------------------------------------------------ Envoi

  Future<void> _send(String text, {bool adoption = false, bool retry = false}) async {
    final question = text.trim();
    if (question.isEmpty || _busy) return;

    setState(() {
      if (retry && _messages.isNotEmpty && _messages.last.isError) _messages.removeLast();
      if (!retry) _messages.add(AssistantMessage.user(question));
      _busy = true;
    });
    _input.clear();
    _scrollToEnd();

    final history = _messages.sublist(0, _messages.length - 1);
    final pet = _signedIn ? _pet : null;
    try {
      final user = _user;
      if (user != null) await _service.countMessage(user.uid);

      final now = DateTime.now();
      final context = StringBuffer('DATE DU JOUR : ${isoDay(now)}');
      if (pet != null) {
        final results = await Future.wait([
          _petRepository.fetchLatestWeight(pet.id),
          _petRepository.fetchHealthSummary(pet.id),
        ]);
        context
          ..write('\n\n')
          ..write(buildPetContext(pet, weight: results[0] as PetWeight?, health: results[1] as List<String>, now: now));
      }

      var knownIds = <String>{};
      if (adoption || isAdoptionQuestion(question)) {
        try {
          final listings = await _service.fetchAvailableListings();
          for (final l in listings) {
            _listings[l.id] = l;
          }
          knownIds = listings.take(kListingContextMax).map((l) => l.id).toSet();
          context
            ..write('\n\n')
            ..write(buildListingContext(listings));
        } catch (e) {
          // Sans les annonces, l'assistant répond quand même (sans proposer d'animal).
          debugPrint('AssistantScreen: annonces indisponibles : $e');
        }
      }
      // Écran fermé ou « Arrêter » pendant la préparation.
      if (!mounted || !_busy) return;

      setState(() {
        _streaming = '';
        _streamingIds = knownIds;
        _streamingPet = pet;
        _pendingQuestion = question;
      });
      _subscription = _service.reply(history: history, question: question, context: context.toString()).listen(
        (raw) {
          setState(() => _streaming = raw);
          _scrollToEnd();
        },
        onError: (Object e) => _finish(error: e),
        onDone: _finish,
        cancelOnError: true,
      );
    } catch (e) {
      _finish(error: e);
    }
  }

  /// Termine la réponse en cours : réponse complète, réponse interrompue ou erreur.
  void _finish({Object? error}) {
    if (!mounted) return;
    final raw = _streaming ?? '';
    AssistantMessage? answer;
    setState(() {
      if (raw.trim().isNotEmpty) {
        final parsed = parseAnswer(raw, _streamingIds, allowReminders: _streamingPet != null);
        answer = AssistantMessage.assistant(parsed.text, listingIds: parsed.listingIds, reminders: parsed.reminders);
        _messages.add(answer!);
      }
      if (error != null) {
        final message = error is AssistantException
            ? error.message
            : "L'assistant n'est pas disponible pour le moment. Réessayez plus tard.";
        _messages.add(AssistantMessage.assistant(message, isError: true));
      }
      _streaming = null;
      _subscription = null;
      _busy = false;
    });
    _scrollToEnd();
    if (answer != null) _saveExchange(_pendingQuestion, answer!, _streamingPet);
  }

  /// Enregistre la question et la réponse dans l'historique (utilisateur connecté).
  Future<void> _saveExchange(String question, AssistantMessage answer, AssistantPet? pet) async {
    final user = _user;
    if (user == null) return;
    try {
      _chatId ??= await _chatRepository.createChat(user.uid, firstQuestion: question, petId: pet?.id, petName: pet?.name);
      final chatId = _chatId!;
      await _chatRepository.addMessage(user.uid, chatId, AssistantMessage.user(question), petId: pet?.id, petName: pet?.name);
      final answerId =
          await _chatRepository.addMessage(user.uid, chatId, answer, petId: pet?.id, petName: pet?.name);
      final index = _messages.indexOf(answer);
      if (mounted && index >= 0) setState(() => _messages[index] = _messages[index].copyWith(id: answerId));
    } catch (e) {
      // L'historique n'est pas bloquant : la conversation continue.
      debugPrint('AssistantScreen: historique non enregistré : $e');
    }
  }

  Future<void> _stop() async {
    await _subscription?.cancel();
    _finish();
  }

  void _retry() {
    final lastQuestion = _messages.lastWhere((m) => m.fromUser, orElse: () => const AssistantMessage.user(''));
    _send(lastQuestion.text, retry: true);
  }

  // ------------------------------------------------------------------ Actions sur les réponses

  Future<void> _rate(int index, AnswerRating? rating) async {
    final message = _messages[index];
    setState(() => _messages[index] = message.copyWith(rating: rating, clearRating: rating == null));
    final user = _user;
    final chatId = _chatId;
    if (user == null || chatId == null || message.id == null) return;
    try {
      await _chatRepository.rate(user.uid, chatId, message.id!, rating);
    } catch (e) {
      debugPrint('AssistantScreen: avis non enregistré : $e');
    }
  }

  Future<void> _createReminder(int index, ReminderSuggestion suggestion) async {
    final pet = _pet;
    if (pet == null) {
      showAdoptionMessage(context, 'Sélectionnez un animal pour créer un rappel.');
      return;
    }
    final created = await showReminderSheet(context, suggestion: suggestion, pet: pet);
    if (!created || !mounted) return;
    setState(() => _createdReminders.putIfAbsent(index, () => {}).add(suggestion.title));
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text('Rappel créé pour ${pet.name}'),
        action: SnackBarAction(label: 'Voir', onPressed: () => Navigator.of(context).pushNamed(AppRoutes.reminders)),
      ));
  }

  // ------------------------------------------------------------------ Historique

  void _newConversation() {
    setState(() {
      _messages.clear();
      _createdReminders.clear();
      _chatId = null;
    });
  }

  Future<void> _openHistory() async {
    final chatId = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const AssistantHistoryScreen()),
    );
    if (chatId == null || !mounted) return;
    if (chatId.isEmpty) {
      _newConversation();
      return;
    }
    await _loadChat(chatId);
  }

  Future<void> _loadChat(String chatId) async {
    final user = _user!;
    setState(() => _loadingChat = true);
    try {
      final chat = await _chatRepository
          .watchChats(user.uid)
          .first
          .then((chats) => chats.where((c) => c.id == chatId).firstOrNull);
      final messages = await _chatRepository.fetchMessages(user.uid, chatId);
      final missing = {for (final m in messages) ...m.listingIds}.where((id) => !_listings.containsKey(id));
      if (missing.isNotEmpty) {
        for (final l in await AdoptionRepository().fetchListings(missing)) {
          _listings[l.id] = l;
        }
      }
      if (!mounted) return;
      setState(() {
        _messages
          ..clear()
          ..addAll(messages);
        _createdReminders.clear();
        _chatId = chatId;
        final petId = chat?.petId;
        _pet = petId == null ? null : _pets.where((p) => p.id == petId).firstOrNull;
        if (petId != null && _pet == null) _pendingPetId = petId;
      });
      _scrollToEnd();
    } catch (e) {
      debugPrint('AssistantScreen: conversation non chargée : $e');
      if (mounted) showAdoptionMessage(context, "La conversation n'a pas pu être ouverte.");
    } finally {
      if (mounted) setState(() => _loadingChat = false);
    }
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // ------------------------------------------------------------------ Interface

  @override
  Widget build(BuildContext context) {
    final empty = _messages.isEmpty && _streaming == null;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        titleSpacing: 0,
        title: const Row(
          children: [
            AssistantAvatar(radius: 18),
            SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Assistant PetCare', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                Text('IA · Réponses indicatives', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              ],
            ),
          ],
        ),
        actions: [
          if (_messages.isNotEmpty && !_busy)
            IconButton(
              tooltip: 'Nouvelle conversation',
              onPressed: _newConversation,
              icon: const Icon(Icons.add_comment_outlined),
            ),
          if (_signedIn)
            IconButton(
              tooltip: 'Mes conversations',
              onPressed: _busy ? null : _openHistory,
              icon: const Icon(Icons.history),
            ),
        ],
      ),
      body: Column(
        children: [
          const AssistantDisclaimer(),
          if (_signedIn && _pets.isNotEmpty)
            PetSelector(
              pets: _pets,
              selected: _pet,
              enabled: !_busy,
              onSelected: (pet) => setState(() => _pet = pet),
            ),
          Expanded(
            child: _loadingChat
                ? const Center(child: CircularProgressIndicator())
                : empty
                    ? _emptyState()
                    : _conversation(),
          ),
          AssistantInputBar(
            controller: _input,
            busy: _busy,
            hint: _pet == null ? 'Posez votre question…' : 'Une question sur ${_pet!.name} ?',
            onSend: () => _send(_input.text),
            onStop: _stop,
          ),
        ],
      ),
    );
  }

  Widget _emptyState() {
    final suggestions = recommendedQuestions(signedIn: _signedIn, pet: _signedIn ? _pet : null);
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
      children: [
        const Center(child: AssistantAvatar(radius: 36)),
        const SizedBox(height: 14),
        Text(
          _pet == null ? 'Comment puis-je vous aider ?' : 'Une question sur ${_pet!.name} ?',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: -0.3),
        ),
        const SizedBox(height: 6),
        Text(
          _signedIn
              ? "Posez une question sur les soins, l'alimentation, le comportement ou l'adoption."
              : 'Connectez-vous pour des réponses adaptées à vos animaux et des rappels de soins.',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 14, height: 1.4, color: AppColors.textSecondary),
        ),
        if (!_signedIn)
          Center(
            child: TextButton(
              onPressed: () => Navigator.of(context).pushNamed(AppRoutes.login),
              child: const Text('Se connecter'),
            ),
          ),
        const SizedBox(height: 20),
        const Text(
          'Questions recommandées',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 10),
        SuggestionChips(
          suggestions: suggestions,
          onTap: (s) => _send(s.question, adoption: s.adoption),
        ),
      ],
    );
  }

  Widget _conversation() {
    final streaming = _streaming;
    final partial = streaming == null
        ? null
        : parseAnswer(streaming, _streamingIds, allowReminders: _streamingPet != null, streaming: true);
    return ListView(
      controller: _scroll,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      children: [
        for (final (i, m) in _messages.indexed)
          m.fromUser
              ? UserBubble(text: m.text)
              : AssistantBubble(
                  message: m,
                  listings: [for (final id in m.listingIds) ?_listings[id]],
                  createdReminders: _createdReminders[i] ?? const {},
                  onCreateReminder: _signedIn ? (r) => _createReminder(i, r) : null,
                  onRate: m.isError ? null : (rating) => _rate(i, rating),
                  onRetry: m.isError && i == _messages.length - 1 && !_busy ? _retry : null,
                ),
        if (_busy && (partial == null || partial.text.isEmpty)) const TypingIndicator(),
        if (partial != null && partial.text.isNotEmpty)
          AssistantBubble(message: AssistantMessage.assistant(partial.text), writing: true),
      ],
    );
  }
}
