import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/relative_time.dart';
import '../../adoption/presentation/widgets/adoption_widgets.dart';
import '../data/assistant_chat_repository.dart';
import '../data/assistant_prompt.dart';

/// « Mes conversations » (maquette Stitch M6). Renvoie l'id de la conversation choisie,
/// ou une chaîne vide pour une nouvelle conversation.
class AssistantHistoryScreen extends StatefulWidget {
  const AssistantHistoryScreen({super.key});

  @override
  State<AssistantHistoryScreen> createState() => _AssistantHistoryScreenState();
}

class _AssistantHistoryScreenState extends State<AssistantHistoryScreen> {
  final _repository = AssistantChatRepository();
  final _uid = FirebaseAuth.instance.currentUser!.uid;
  late final _chats = _repository.watchChats(_uid);

  Future<void> _delete(AssistantChat chat) async {
    try {
      await _repository.deleteChat(_uid, chat.id);
      if (mounted) showAdoptionMessage(context, 'Conversation supprimée');
    } catch (e) {
      debugPrint('AssistantHistoryScreen: $e');
      if (mounted) showAdoptionMessage(context, 'La suppression a échoué. Réessayez.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        title: const Text('Mes conversations'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: TextButton.icon(
              onPressed: () => Navigator.of(context).pop(''),
              icon: const Icon(Icons.add),
              label: const Text('Nouvelle'),
            ),
          ),
        ],
      ),
      body: StreamBuilder<List<AssistantChat>>(
        stream: _chats,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return EmptyState.loadError(title: 'Historique indisponible', error: snapshot.error);
          }
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final chats = snapshot.data!;
          if (chats.isEmpty) {
            return const EmptyState(
              icon: Icons.chat_bubble_outline,
              title: 'Aucune conversation',
              text: 'Vos échanges avec l\'assistant apparaîtront ici.',
            );
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            children: [
              const Padding(
                padding: EdgeInsets.only(bottom: 12, left: 4),
                child: Text(
                  'Vos $kAssistantHistoryChats dernières conversations',
                  style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                ),
              ),
              for (final chat in chats)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Dismissible(
                    key: ValueKey(chat.id),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 20),
                      decoration: BoxDecoration(color: AppColors.error, borderRadius: BorderRadius.circular(16)),
                      child: const Text('Supprimer', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                    ),
                    onDismissed: (_) => _delete(chat),
                    child: Material(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      child: ListTile(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        leading: const CircleAvatar(
                          backgroundColor: AppColors.tealLight,
                          child: Icon(Icons.chat_bubble_outline, color: AppColors.teal, size: 20),
                        ),
                        title: Text(chat.title, maxLines: 2, overflow: TextOverflow.ellipsis),
                        subtitle: Text(
                          [
                            if (chat.petName != null) chat.petName!,
                            if (chat.updatedAt != null) formatRelativeTime(chat.updatedAt!),
                          ].join(' · '),
                        ),
                        trailing: IconButton(
                          tooltip: 'Supprimer',
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () => _delete(chat),
                        ),
                        onTap: () => Navigator.of(context).pop(chat.id),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
