import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../../l10n/app_localizations.dart';
import '../../data/prescription_parser.dart';
import '../../data/text_scanner.dart';
import 'health_ui.dart';

/// « Scanner une vignette ou une ordonnance » : photo (appareil ou galerie), texte lu par ML Kit sur le
/// téléphone, puis [onResult] pré-remplit le formulaire. Rien n'est enregistré automatiquement.
///
/// Masqué là où ML Kit n'existe pas (web, Windows, macOS, Linux).
class ScanPrescriptionButton extends StatefulWidget {
  const ScanPrescriptionButton({super.key, required this.onResult});

  final ValueChanged<ScanResult> onResult;

  @override
  State<ScanPrescriptionButton> createState() => _ScanPrescriptionButtonState();
}

class _ScanPrescriptionButtonState extends State<ScanPrescriptionButton> {
  var _reading = false;

  Future<void> _scan() async {
    final l = AppLocalizations.of(context);
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Symbols.photo_camera, color: HealthColors.primary),
              title: Text(l.healthScanFromCamera),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Symbols.image, color: HealthColors.primary),
              title: Text(l.healthScanFromGallery),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;

    // Image assez grande pour lire les petits caractères d'une vignette.
    final photo = await ImagePicker().pickImage(source: source, maxWidth: 2400, imageQuality: 90);
    if (photo == null || !mounted) return;

    setState(() => _reading = true);
    try {
      final result = parsePrescriptionText(await recognizeTextFromImage(photo.path));
      if (!mounted) return;
      if (result.isEmpty) {
        showHealthToast(context, l.healthScanNothing, icon: Symbols.info);
      } else {
        widget.onResult(result);
      }
    } catch (_) {
      if (mounted) showHealthToast(context, l.healthScanError, icon: Symbols.error);
    } finally {
      if (mounted) setState(() => _reading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!isTextScanSupported) return const SizedBox.shrink();
    final l = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OutlinedButton.icon(
          onPressed: _reading ? null : _scan,
          style: OutlinedButton.styleFrom(
            foregroundColor: HealthColors.primary,
            side: const BorderSide(color: HealthColors.primaryContainer),
            minimumSize: const Size.fromHeight(48),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          icon: _reading
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Symbols.document_scanner, size: 20),
          label: Text(_reading ? l.healthScanReading : l.healthScanButton),
        ),
        const SizedBox(height: 4),
        Text(l.healthScanHint, style: HealthText.bodySm, textAlign: TextAlign.center),
      ],
    );
  }
}

/// Bandeau après un scan : quels champs ont été pré-remplis, à vérifier ; et un conseil éventuel
/// (un vaccin scanné depuis « Nouveau traitement », un médicament depuis « Ajouter un soin »).
class ScanReviewBanner extends StatelessWidget {
  const ScanReviewBanner({super.key, required this.fields, this.hint});

  final List<String> fields;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: HealthColors.amber50, borderRadius: BorderRadius.circular(12)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Symbols.fact_check, size: 20, color: HealthColors.amber800),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (fields.isNotEmpty)
                  Text(
                    l.healthScanReview(fields.join(', ')),
                    style: HealthText.bodySm.copyWith(color: HealthColors.amber800, fontWeight: FontWeight.w600),
                  ),
                if (hint != null) ...[
                  if (fields.isNotEmpty) const SizedBox(height: 4),
                  Text(hint!, style: HealthText.bodySm.copyWith(color: HealthColors.amber800)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
