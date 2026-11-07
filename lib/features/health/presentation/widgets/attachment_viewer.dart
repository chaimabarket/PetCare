import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../data/health_entry.dart';
import '../../data/health_repository.dart';
import 'health_ui.dart';

/// Ouvre une pièce jointe du carnet : une image s'affiche en plein écran,
/// un PDF est enregistré sur le téléphone (« Téléchargement de : … »).
Future<void> openHealthAttachment(
  BuildContext context, {
  required String petId,
  required String entryId,
  required int index,
  required HealthAttachment attachment,
}) async {
  try {
    final bytes = await HealthRepository().loadAttachment(petId, entryId, index);
    if (!context.mounted) return;
    if (attachment.isImage) {
      await showDialog<void>(
        context: context,
        builder: (context) => _ImageDialog(attachment: attachment, bytes: bytes),
      );
    } else {
      await saveHealthFile(context, attachment.name, bytes, attachment.mimeType);
    }
  } catch (e) {
    if (context.mounted) showHealthToast(context, friendlyHealthError(e), icon: Symbols.error);
  }
}

/// Enregistre un fichier sur le téléphone via le sélecteur du système.
Future<void> saveHealthFile(BuildContext context, String name, Uint8List bytes, String mimeType) async {
  final uri = await FilePicker.saveFile(fileName: name, bytes: bytes, mimeType: mimeType);
  if (uri != null && context.mounted) showHealthToast(context, 'Téléchargement de : $name');
}

class _ImageDialog extends StatelessWidget {
  const _ImageDialog({required this.attachment, required this.bytes});

  final HealthAttachment attachment;
  final Uint8List bytes;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 4, 8),
            child: Row(
              children: [
                Expanded(child: Text(attachment.name, style: HealthText.labelLg, overflow: TextOverflow.ellipsis)),
                IconButton(
                  tooltip: 'Enregistrer sur le téléphone',
                  onPressed: () => saveHealthFile(context, attachment.name, bytes, attachment.mimeType),
                  icon: const Icon(Symbols.download, color: HealthColors.primary),
                ),
                IconButton(
                  tooltip: 'Fermer',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Symbols.close),
                ),
              ],
            ),
          ),
          Flexible(child: InteractiveViewer(child: Image.memory(bytes, fit: BoxFit.contain))),
        ],
      ),
    );
  }
}
