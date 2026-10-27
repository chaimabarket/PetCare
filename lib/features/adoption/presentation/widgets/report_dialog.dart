import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../data/adoption_repository.dart';
import 'adoption_widgets.dart';

const _reasons = ['Contenu inapproprié', 'Arnaque ou demande d\'argent', 'Doublon', 'Informations fausses', 'Autre'];

/// Signalement d'une annonce ou d'une Happy Tail, transmis à l'administrateur.
Future<void> showReportDialog(
  BuildContext context, {
  required String reporterId,
  required String targetType,
  required String targetId,
}) async {
  final reason = await showModalBottomSheet<String>(
    context: context,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (context) => const _ReportSheet(),
  );
  if (reason == null || !context.mounted) return;
  try {
    await AdoptionRepository().report(
      reporterId: reporterId,
      targetType: targetType,
      targetId: targetId,
      reason: reason,
    );
    if (context.mounted) showAdoptionMessage(context, 'Merci, votre signalement a été transmis à l\'équipe.');
  } catch (_) {
    if (context.mounted) showAdoptionMessage(context, 'Impossible d\'envoyer le signalement. Réessayez.');
  }
}

class _ReportSheet extends StatefulWidget {
  const _ReportSheet();

  @override
  State<_ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends State<_ReportSheet> {
  String? _reason;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Signaler le contenu', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            const Text('Un administrateur examinera votre signalement.',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
            const SizedBox(height: 8),
            RadioGroup<String>(
              groupValue: _reason,
              onChanged: (v) => setState(() => _reason = v),
              child: Column(
                children: [
                  for (final r in _reasons)
                    RadioListTile<String>(contentPadding: EdgeInsets.zero, value: r, title: Text(r)),
                ],
              ),
            ),
            const SizedBox(height: 8),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.error),
              onPressed: _reason == null ? null : () => Navigator.pop(context, _reason),
              child: const Text('Signaler'),
            ),
          ],
        ),
      ),
    );
  }
}
