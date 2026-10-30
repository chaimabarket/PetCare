import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../adoption/data/adoption_listing.dart';
import '../../../adoption/presentation/widgets/adoption_widgets.dart';
import '../../data/answer_parser.dart';
import '../../data/assistant_message.dart';
import '../../data/assistant_pet.dart';
import '../../data/assistant_prompt.dart';

class AssistantAvatar extends StatelessWidget {
  const AssistantAvatar({super.key, required this.radius});

  final double radius;

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: AppColors.tealLight,
      child: Icon(Icons.pets, size: radius, color: AppColors.teal),
    );
  }
}

class AssistantDisclaimer extends StatelessWidget {
  const AssistantDisclaimer({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: const Color(0xFFFEF3C7), borderRadius: BorderRadius.circular(12)),
      child: const Row(
        children: [
          Icon(Icons.info_outline, size: 18, color: Color(0xFF92400E)),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              "Je ne remplace pas un vétérinaire. N'indiquez pas de données personnelles.",
              style: TextStyle(fontSize: 12.5, height: 1.3, color: Color(0xFF92400E)),
            ),
          ),
        ],
      ),
    );
  }
}

/// Choix du sujet : « Général » ou un animal de l'utilisateur (sa fiche et son carnet sont joints).
class PetSelector extends StatelessWidget {
  const PetSelector({super.key, required this.pets, required this.selected, required this.onSelected, this.enabled = true});

  final List<AssistantPet> pets;
  final AssistantPet? selected;
  final ValueChanged<AssistantPet?> onSelected;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    Widget chip(String label, bool isSelected, VoidCallback onTap) => ChoiceChip(
          label: Text(label),
          selected: isSelected,
          onSelected: enabled ? (_) => onTap() : null,
          showCheckmark: false,
          selectedColor: AppColors.teal,
          backgroundColor: AppColors.surface,
          side: BorderSide(color: isSelected ? AppColors.teal : AppColors.border),
          labelStyle: TextStyle(
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : AppColors.textPrimary,
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 48,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            children: [
              chip('💬 Général', selected == null, () => onSelected(null)),
              for (final p in pets) ...[
                const SizedBox(width: 8),
                chip('${p.emoji} ${p.name}', selected?.id == p.id, () => onSelected(p)),
              ],
            ],
          ),
        ),
        if (selected != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 6, 20, 0),
            child: Text(
              'Les infos et le carnet de santé de ${selected!.name} sont utilisés pour répondre.',
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ),
      ],
    );
  }
}

class SuggestionChips extends StatelessWidget {
  const SuggestionChips({super.key, required this.suggestions, required this.onTap});

  final List<AssistantSuggestion> suggestions;
  final ValueChanged<AssistantSuggestion> onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final s in suggestions)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Material(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                onTap: () => onTap(s),
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.border),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      Expanded(child: Text(s.label, style: const TextStyle(fontSize: 14.5, height: 1.3))),
                      const Icon(Icons.north_east, size: 16, color: AppColors.teal),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class UserBubble extends StatelessWidget {
  const UserBubble({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.8),
        margin: const EdgeInsets.only(bottom: 12, left: 48),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: const BoxDecoration(
          color: AppColors.teal,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
            bottomLeft: Radius.circular(16),
            bottomRight: Radius.circular(4),
          ),
        ),
        child: Text(text, style: const TextStyle(fontSize: 15, height: 1.4, color: Colors.white)),
      ),
    );
  }
}

/// Réponse de l'assistant : texte, cartes d'annonces, rappels proposés et actions (copier, 👍 / 👎).
class AssistantBubble extends StatelessWidget {
  const AssistantBubble({
    super.key,
    required this.message,
    this.listings = const [],
    this.createdReminders = const {},
    this.onCreateReminder,
    this.onRate,
    this.onRetry,
    this.writing = false,
  });

  final AssistantMessage message;
  final List<AdoptionListing> listings;

  /// Rappels déjà créés depuis ce message (bouton remplacé par « Rappel créé »).
  final Set<String> createdReminders;
  final ValueChanged<ReminderSuggestion>? onCreateReminder;
  final ValueChanged<AnswerRating?>? onRate;
  final VoidCallback? onRetry;
  final bool writing;

  @override
  Widget build(BuildContext context) {
    final urgent = message.text.startsWith('⚠️');
    final highlight = message.isError || urgent;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12, right: 24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AssistantAvatar(radius: 14),
          const SizedBox(width: 8),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: message.isError ? const Color(0xFFFEF2F2) : AppColors.surface,
                    border: Border.all(color: highlight ? AppColors.error : AppColors.border, width: highlight ? 1.5 : 1),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(4),
                      topRight: Radius.circular(16),
                      bottomLeft: Radius.circular(16),
                      bottomRight: Radius.circular(16),
                    ),
                  ),
                  child: Text(
                    writing ? '${message.text} ▍' : message.text,
                    style: TextStyle(
                      fontSize: 15,
                      height: 1.45,
                      color: message.isError ? AppColors.error : AppColors.textPrimary,
                    ),
                  ),
                ),
                for (final r in message.reminders) ...[
                  const SizedBox(height: 8),
                  _ReminderButton(
                    suggestion: r,
                    created: createdReminders.contains(r.title),
                    onTap: onCreateReminder == null ? null : () => onCreateReminder!(r),
                  ),
                ],
                for (final l in listings) ...[
                  const SizedBox(height: 8),
                  ListingSuggestionCard(listing: l),
                ],
                if (listings.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  const Text(
                    "La décision finale revient au refuge ou au propriétaire de l'annonce.",
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                ],
                if (onRetry != null)
                  TextButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('Réessayer'),
                  ),
                if (!message.isError && !writing) _AnswerActions(message: message, onRate: onRate),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AnswerActions extends StatelessWidget {
  const _AnswerActions({required this.message, required this.onRate});

  final AssistantMessage message;
  final ValueChanged<AnswerRating?>? onRate;

  @override
  Widget build(BuildContext context) {
    Widget action(IconData icon, IconData activeIcon, String tooltip, bool active, VoidCallback? onTap) => IconButton(
          tooltip: tooltip,
          visualDensity: VisualDensity.compact,
          iconSize: 18,
          onPressed: onTap,
          icon: Icon(active ? activeIcon : icon, color: active ? AppColors.teal : AppColors.textSecondary),
        );

    final rating = message.rating;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        action(Icons.copy_rounded, Icons.copy_rounded, 'Copier', false, () async {
          await Clipboard.setData(ClipboardData(text: message.text));
          if (context.mounted) showAdoptionMessage(context, 'Réponse copiée');
        }),
        if (onRate != null) ...[
          action(Icons.thumb_up_outlined, Icons.thumb_up, 'Réponse utile', rating == AnswerRating.up,
              () => onRate!(rating == AnswerRating.up ? null : AnswerRating.up)),
          action(Icons.thumb_down_outlined, Icons.thumb_down, 'Réponse peu utile', rating == AnswerRating.down,
              () => onRate!(rating == AnswerRating.down ? null : AnswerRating.down)),
        ],
      ],
    );
  }
}

class _ReminderButton extends StatelessWidget {
  const _ReminderButton({required this.suggestion, required this.created, required this.onTap});

  final ReminderSuggestion suggestion;
  final bool created;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final date = formatShortDate(suggestion.dueAt);
    return Material(
      color: created ? AppColors.tealLight : const Color(0xFFFFF4EF),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: created ? null : onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Icon(created ? Icons.check_circle : Icons.alarm_add, size: 20, color: created ? AppColors.teal : AppColors.coralText),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      created ? 'Rappel créé' : 'Créer un rappel',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: created ? AppColors.teal : AppColors.coralText,
                      ),
                    ),
                    Text('${suggestion.title} · $date', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              if (!created) const Icon(Icons.chevron_right, color: AppColors.coralText),
            ],
          ),
        ),
      ),
    );
  }
}

class ListingSuggestionCard extends StatelessWidget {
  const ListingSuggestionCard({super.key, required this.listing});

  final AdoptionListing listing;

  @override
  Widget build(BuildContext context) {
    final l = listing;
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).pushNamed(AppRoutes.adoptionListing, arguments: l.id),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(border: Border.all(color: AppColors.border), borderRadius: BorderRadius.circular(16)),
          child: Row(
            children: [
              SizedBox(
                width: 64,
                height: 64,
                child: PetPhoto(bytes: l.cover, species: l.species, borderRadius: BorderRadius.circular(12), emojiSize: 28),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text('${l.species.label} · ${l.ageLabel}',
                        style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Icon(Icons.place_outlined, size: 14, color: AppColors.textSecondary),
                        const SizedBox(width: 2),
                        Expanded(
                          child: Text(l.city,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Text('Voir la fiche', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.teal)),
              const Icon(Icons.chevron_right, color: AppColors.teal),
            ],
          ),
        ),
      ),
    );
  }
}

class TypingIndicator extends StatelessWidget {
  const TypingIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          AssistantAvatar(radius: 14),
          SizedBox(width: 10),
          SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
          SizedBox(width: 10),
          Text("L'assistant écrit…", style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}

class AssistantInputBar extends StatelessWidget {
  const AssistantInputBar({
    super.key,
    required this.controller,
    required this.busy,
    required this.onSend,
    required this.onStop,
    this.hint = 'Posez votre question…',
  });

  final TextEditingController controller;
  final bool busy;
  final VoidCallback onSend;
  final VoidCallback onStop;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.divider)),
      ),
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
      child: SafeArea(
        top: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                enabled: !busy,
                minLines: 1,
                maxLines: 4,
                maxLength: kAssistantQuestionMax,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => onSend(),
                decoration: InputDecoration(
                  hintText: hint,
                  filled: true,
                  fillColor: AppColors.background,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Padding(
              padding: const EdgeInsets.only(bottom: 22),
              child: busy
                  ? IconButton.filledTonal(tooltip: 'Arrêter', onPressed: onStop, icon: const Icon(Icons.stop_rounded))
                  : IconButton.filled(
                      tooltip: 'Envoyer',
                      onPressed: onSend,
                      style: IconButton.styleFrom(backgroundColor: AppColors.teal),
                      icon: const Icon(Icons.send_rounded, color: Colors.white),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
