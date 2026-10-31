import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../data/health_sheet.dart';
import '../data/health_sheet_repository.dart';
import 'health_sheets_screen.dart';
import 'widgets/health_ui.dart';

/// Détail d'une fiche santé.
///
/// Pas d'écran Stitch pour cette page : elle suit la consigne 2.5 de STITCH_PROMPTS.md
/// (titre, illustration, espèces, corps avec intertitres, encadré « Information générale »,
/// ligne « Source : », bouton « Trouver un vétérinaire ») avec les composants des autres écrans.
class HealthSheetDetailScreen extends StatefulWidget {
  const HealthSheetDetailScreen({super.key, required this.sheet});

  final HealthSheet sheet;

  @override
  State<HealthSheetDetailScreen> createState() => _HealthSheetDetailScreenState();
}

class _HealthSheetDetailScreenState extends State<HealthSheetDetailScreen> {
  final _repository = HealthSheetRepository();
  final _uid = FirebaseAuth.instance.currentUser?.uid;
  late final _bookmarks = _uid == null ? Stream.value(<String>{}) : _repository.watchBookmarks(_uid);

  @override
  Widget build(BuildContext context) {
    final sheet = widget.sheet;
    return Scaffold(
      backgroundColor: HealthColors.surface,
      appBar: HealthAppBar(
        title: 'Fiche santé',
        actions: [
          StreamBuilder<Set<String>>(
            stream: _bookmarks,
            builder: (context, snap) {
              final saved = snap.data?.contains(sheet.id) ?? false;
              return IconButton(
                tooltip: saved ? 'Retirer des fiches enregistrées' : 'Enregistrer cette fiche',
                onPressed: _uid == null
                    ? () => showHealthToast(context, 'Connectez-vous pour enregistrer des fiches.', icon: Symbols.info)
                    : () => _repository.setBookmarked(_uid, sheet.id, bookmarked: !saved),
                icon: Icon(Symbols.bookmark, fill: saved ? 1 : 0, color: saved ? HealthColors.secondary : HealthColors.onSurfaceVariant),
              );
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: AspectRatio(aspectRatio: 16 / 9, child: HealthSheetImage(sheet: sheet)),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              if (sheet.category == HealthSheetCategory.emergency)
                const HealthPill(
                  label: 'Urgence vitale',
                  background: HealthColors.errorContainer,
                  foreground: HealthColors.onErrorContainer,
                ),
              for (final s in sheet.species)
                HealthPill(label: s, background: HealthColors.surfaceHigh, foreground: HealthColors.primary),
              HealthPill(
                label: '${sheet.readMinutes} min de lecture',
                icon: Symbols.schedule,
                background: HealthColors.surfaceLow,
                foreground: HealthColors.onSurfaceVariant,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(sheet.title, style: HealthText.headlineMd),
          const SizedBox(height: 8),
          Text(sheet.summary, style: HealthText.bodyMd.copyWith(height: 1.6)),
          const SizedBox(height: 4),
          Text(
            sheet.organization.isEmpty ? sheet.author : '${sheet.author} • ${sheet.organization}',
            style: HealthText.bodySm.copyWith(color: HealthColors.outline),
          ),
          const SizedBox(height: 16),
          HealthCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < sheet.sections.length; i++) ...[
                  if (i > 0) const SizedBox(height: 16),
                  Text(sheet.sections[i].heading, style: HealthText.headlineSm),
                  const SizedBox(height: 6),
                  Text(
                    sheet.sections[i].body,
                    style: const TextStyle(fontSize: 15, height: 1.6, color: HealthColors.onSurface),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: HealthColors.surfaceLow, borderRadius: BorderRadius.circular(12)),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Symbols.info, size: 20, color: HealthColors.primary),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    "Information générale – ne remplace pas l'avis d'un vétérinaire",
                    style: HealthText.labelLg,
                  ),
                ),
              ],
            ),
          ),
          if (sheet.source.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text.rich(
              TextSpan(
                text: 'Source : ',
                style: HealthText.labelSm.copyWith(color: HealthColors.onSurfaceVariant, fontWeight: FontWeight.w600),
                children: [
                  TextSpan(text: sheet.source, style: const TextStyle(fontWeight: FontWeight.w400)),
                ],
              ),
            ),
          ],
          const SizedBox(height: 24),
          FilledButton.icon(
            // Annuaire des services (module 6) : l'onglet « Services » de la structure principale.
            onPressed: () => Navigator.of(context).pop(3),
            style: FilledButton.styleFrom(
              backgroundColor: HealthColors.primary,
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            icon: const Icon(Symbols.stethoscope, size: 20),
            label: const Text('Trouver un vétérinaire'),
          ),
        ],
      ),
    );
  }
}
