import 'package:flutter/material.dart';

import '../../../../core/routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../pets/presentation/pet_detail_screen.dart';
import '../../data/assistant_actions.dart';

/// Carte de confirmation d'une action préparée par l'assistant : rien n'est enregistré avant « Confirmer ».
class ActionCard extends StatelessWidget {
  const ActionCard({
    super.key,
    required this.action,
    required this.petId,
    this.saving = false,
    this.error,
    this.onConfirm,
    this.onCancel,
  });

  final AssistantAction action;

  /// Animal concerné, pour « Voir » après l'enregistrement (`null` s'il n'existe plus).
  final String? petId;
  final bool saving;
  final String? error;
  final VoidCallback? onConfirm;
  final VoidCallback? onCancel;

  IconData get _icon => switch (action.type) {
        AssistantActionType.healthEntry => Icons.medical_information_outlined,
        AssistantActionType.treatment => Icons.medication_outlined,
        AssistantActionType.appointment => Icons.event_available_outlined,
        AssistantActionType.weight => Icons.monitor_weight_outlined,
        AssistantActionType.reminder => Icons.alarm_add,
      };

  void _open(BuildContext context) {
    final navigator = Navigator.of(context);
    final id = petId;
    switch (action.type) {
      case AssistantActionType.healthEntry when id != null:
        navigator.pushNamed(AppRoutes.healthRecord, arguments: id);
      case AssistantActionType.treatment when id != null:
        navigator.pushNamed(AppRoutes.treatments, arguments: id);
      case AssistantActionType.weight when id != null:
        navigator.push(MaterialPageRoute<void>(builder: (_) => PetDetailScreen(petId: id)));
      case AssistantActionType.appointment:
        navigator.pushNamed(AppRoutes.agenda);
      case AssistantActionType.reminder:
        navigator.pushNamed(AppRoutes.reminders);
      default:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = action.status;
    final done = status == AssistantActionStatus.done;
    final cancelled = status == AssistantActionStatus.cancelled;
    final accent = done ? AppColors.teal : (cancelled ? AppColors.textSecondary : AppColors.coralText);

    return Container(
      decoration: BoxDecoration(
        color: done ? AppColors.tealLight : (cancelled ? AppColors.divider : const Color(0xFFFFF4EF)),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withValues(alpha: 0.35)),
      ),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(done ? Icons.check_circle : _icon, size: 20, color: accent),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  switch (status) {
                    AssistantActionStatus.done => '${action.type.label} · enregistré',
                    AssistantActionStatus.cancelled => '${action.type.label} · annulé',
                    AssistantActionStatus.pending => '${action.type.label} ?',
                  },
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: accent),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          for (final (label, value) in describeAction(action))
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Text.rich(
                TextSpan(children: [
                  TextSpan(text: '$label : ', style: const TextStyle(color: AppColors.textSecondary)),
                  TextSpan(text: value, style: const TextStyle(fontWeight: FontWeight.w600)),
                ]),
                style: TextStyle(
                  fontSize: 14,
                  height: 1.35,
                  decoration: cancelled ? TextDecoration.lineThrough : null,
                ),
              ),
            ),
          if (error != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(error!, style: const TextStyle(fontSize: 13, color: AppColors.error)),
            ),
          const SizedBox(height: 4),
          if (status == AssistantActionStatus.pending)
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(onPressed: saving ? null : onCancel, child: const Text('Annuler')),
                const SizedBox(width: 4),
                FilledButton.icon(
                  onPressed: saving ? null : onConfirm,
                  icon: saving
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.check, size: 18),
                  label: Text(error == null ? 'Confirmer' : 'Réessayer'),
                ),
              ],
            )
          else if (done)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(onPressed: () => _open(context), child: const Text('Voir')),
            ),
        ],
      ),
    );
  }
}
