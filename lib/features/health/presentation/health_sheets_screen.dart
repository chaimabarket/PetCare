import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/routes.dart';
import '../../appointments/presentation/widgets/rdv_ui.dart' show RdvBellButton;
import '../data/health_format.dart';
import '../data/health_sheet.dart';
import '../data/health_sheet_repository.dart';
import 'widgets/health_ui.dart';

/// Fiches santé publiques (maquette Stitch « Fiches Santé & Prévention »).
class HealthSheetsScreen extends StatefulWidget {
  const HealthSheetsScreen({super.key});

  @override
  State<HealthSheetsScreen> createState() => _HealthSheetsScreenState();
}

class _HealthSheetsScreenState extends State<HealthSheetsScreen> {
  final _repository = HealthSheetRepository();
  final _uid = FirebaseAuth.instance.currentUser?.uid;
  late final _sheetsStream = _repository.watchSheets();
  late final _bookmarksStream = _uid == null ? Stream.value(<String>{}) : _repository.watchBookmarks(_uid);

  final _search = TextEditingController();
  final _searchFocus = FocusNode();

  /// Null = « Tous ».
  HealthSheetCategory? _category;

  @override
  void initState() {
    super.initState();
    _search.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _search.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  void _open(HealthSheet sheet) => pushHealthRoute<void>(context, AppRoutes.healthSheetDetail, arguments: sheet);

  Future<void> _toggleBookmark(HealthSheet sheet, bool bookmarked) async {
    if (_uid == null) {
      showHealthToast(context, 'Connectez-vous pour enregistrer des fiches.', icon: Symbols.info);
      return;
    }
    try {
      await _repository.setBookmarked(_uid, sheet.id, bookmarked: !bookmarked);
    } catch (e) {
      if (mounted) showHealthToast(context, friendlyHealthError(e), icon: Symbols.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HealthColors.surface,
      appBar: HealthAppBar(
        title: 'Santé & Conseils',
        leading: Padding(
          padding: const EdgeInsets.only(left: 16),
          child: Center(
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: HealthColors.primaryContainer.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Symbols.pets, size: 24, color: HealthColors.primary),
            ),
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Rechercher',
            onPressed: () => _searchFocus.requestFocus(),
            icon: const Icon(Symbols.search, color: HealthColors.onSurfaceVariant),
          ),
          if (_uid != null) const RdvBellButton(),
        ],
      ),
      bottomNavigationBar: const HealthBottomBar(selectedIndex: 0),
      body: StreamBuilder<List<HealthSheet>>(
        stream: _sheetsStream,
        builder: (context, sheetsSnap) => StreamBuilder<Set<String>>(
          stream: _bookmarksStream,
          builder: (context, bookmarksSnap) =>
              _buildContent(sheetsSnap.data ?? const [], bookmarksSnap.data ?? const {}),
        ),
      ),
    );
  }

  Widget _buildContent(List<HealthSheet> sheets, Set<String> bookmarks) {
    final query = _search.text.trim().toLowerCase();
    final matching = sheets
        .where((s) => _category == null || s.category == _category)
        .where((s) => query.isEmpty || s.searchText.contains(query))
        .toList();
    final featured = matching.where((s) => s.featured).firstOrNull;
    final others = matching.where((s) => s != featured).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(color: HealthColors.surfaceHigh, borderRadius: BorderRadius.circular(999)),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Symbols.verified, size: 16, color: HealthColors.primary, fill: 1),
                const SizedBox(width: 4),
                Text(
                  'Validé par des docteurs vétérinaires',
                  style: HealthText.labelSm.copyWith(color: HealthColors.primary, letterSpacing: 0.3),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        const Text('Fiches Santé & Conseils', style: HealthText.headlineLg),
        const SizedBox(height: 4),
        Text(
          'Guides pratiques, posologies et réflexes préventifs rédigés avec le conseil scientifique de cliniques partenaires.',
          style: HealthText.bodyMd.copyWith(height: 1.6),
        ),
        const SizedBox(height: 24),
        Container(
          height: 52,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: HealthColors.cardShadow),
          child: Row(
            children: [
              const Icon(Symbols.search, size: 22, color: HealthColors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _search,
                  focusNode: _searchFocus,
                  textInputAction: TextInputAction.search,
                  style: const TextStyle(fontSize: 14, color: HealthColors.onSurface),
                  decoration: InputDecoration(
                    hintText: 'Rechercher un problème ou un produit...',
                    hintStyle: HealthText.bodyMd.copyWith(color: HealthColors.outline),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    filled: false,
                    isDense: true,
                  ),
                ),
              ),
              IconButton(
                tooltip: _search.text.isEmpty && _category == null ? 'Filtrer' : 'Effacer la recherche et les filtres',
                onPressed: () => setState(() {
                  _search.clear();
                  _category = null;
                }),
                icon: Icon(
                  _search.text.isEmpty && _category == null ? Symbols.tune : Symbols.close,
                  size: 20,
                  color: HealthColors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          clipBehavior: Clip.none,
          child: Row(
            children: [
              HealthFilterChip(
                label: 'Tous',
                selected: _category == null,
                foreground: HealthColors.onSurface,
                onTap: () => setState(() => _category = null),
              ),
              for (final c in HealthSheetCategory.values) ...[
                const SizedBox(width: 8),
                HealthFilterChip(
                  label: c.label,
                  selected: _category == c,
                  icon: switch (c) {
                    HealthSheetCategory.parasites => Symbols.bug_report,
                    HealthSheetCategory.emergency => Symbols.emergency,
                    _ => null,
                  },
                  background: c == HealthSheetCategory.emergency ? HealthColors.errorContainer : null,
                  foreground: c == HealthSheetCategory.emergency ? HealthColors.onErrorContainer : HealthColors.onSurface,
                  onTap: () => setState(() => _category = c),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 24),
        if (featured != null) ...[
          Row(
            children: [
              Expanded(
                child: Text(
                  'À la une ${seasonLabel(DateTime.now())}'.toUpperCase(),
                  style: HealthText.labelSm.copyWith(
                    color: HealthColors.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              Text('Sélection vétérinaire', style: HealthText.labelSm.copyWith(color: HealthColors.primary)),
              const SizedBox(width: 2),
              const Icon(Symbols.auto_awesome, size: 14, color: HealthColors.primary),
            ],
          ),
          const SizedBox(height: 4),
          _FeaturedCard(
            sheet: featured,
            bookmarked: bookmarks.contains(featured.id),
            onTap: () => _open(featured),
            onBookmark: () => _toggleBookmark(featured, bookmarks.contains(featured.id)),
          ),
          const SizedBox(height: 24),
        ],
        Row(
          children: [
            const Expanded(child: Text('Guides de prévention récents', style: HealthText.headlineSm)),
            Text(
              others.length <= 1 ? '${others.length} fiche' : '${others.length} fiches',
              style: HealthText.labelSm.copyWith(color: HealthColors.onSurfaceVariant),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (others.isEmpty)
          HealthEmptyState(
            icon: Symbols.menu_book,
            title: 'Aucune fiche trouvée',
            message: query.isEmpty
                ? 'Aucune fiche dans cette catégorie pour le moment.'
                : 'Essayez un autre mot-clé ou une autre catégorie.',
          )
        else
          for (final sheet in others) ...[
            _SheetRow(
              sheet: sheet,
              bookmarked: bookmarks.contains(sheet.id),
              onTap: () => _open(sheet),
              onBookmark: () => _toggleBookmark(sheet, bookmarks.contains(sheet.id)),
            ),
            const SizedBox(height: 16),
          ],
        const SizedBox(height: 8),
        const HealthHelpCard(),
      ],
    );
  }
}

/// Image d'une fiche : asset de départ ou URL Firestore.
class HealthSheetImage extends StatelessWidget {
  const HealthSheetImage({super.key, required this.sheet, this.width, this.height});

  final HealthSheet sheet;
  final double? width;
  final double? height;

  @override
  Widget build(BuildContext context) {
    const placeholder = ColoredBox(
      color: HealthColors.surfaceContainer,
      child: Center(child: Icon(Symbols.health_and_safety, color: HealthColors.primary)),
    );
    if (sheet.imageAsset != null) {
      return Image.asset(sheet.imageAsset!, width: width, height: height, fit: BoxFit.cover);
    }
    if (sheet.imageUrl != null) {
      return Image.network(
        sheet.imageUrl!,
        width: width,
        height: height,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => SizedBox(width: width, height: height, child: placeholder),
      );
    }
    return SizedBox(width: width, height: height, child: placeholder);
  }
}

/// Initiales de l'auteur dans la pastille ronde.
String _initials(String name) {
  final words = name.split(RegExp(r'\s+')).where((w) => w.isNotEmpty && w[0].toUpperCase() != w[0].toLowerCase());
  return words.take(2).map((w) => w[0].toUpperCase()).join();
}

class _FeaturedCard extends StatelessWidget {
  const _FeaturedCard({required this.sheet, required this.bookmarked, required this.onTap, required this.onBookmark});

  final HealthSheet sheet;
  final bool bookmarked;
  final VoidCallback onTap;
  final VoidCallback onBookmark;

  @override
  Widget build(BuildContext context) {
    return HealthCard(
      padding: EdgeInsets.zero,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 176,
            child: Stack(
              fit: StackFit.expand,
              children: [
                HealthSheetImage(sheet: sheet),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [Color(0x80000000), Color(0x00000000)],
                      stops: [0, 0.6],
                    ),
                  ),
                ),
                Positioned(
                  top: 12,
                  left: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.9), borderRadius: BorderRadius.circular(999)),
                    child: Text(sheet.species.join(' • '), style: HealthText.labelSm.copyWith(color: HealthColors.primary)),
                  ),
                ),
                Positioned(
                  left: 12,
                  right: 12,
                  bottom: 12,
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(6)),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Symbols.schedule, size: 14, color: Colors.white),
                            const SizedBox(width: 4),
                            Text('${sheet.readMinutes} min de lecture', style: HealthText.labelSm.copyWith(color: Colors.white)),
                          ],
                        ),
                      ),
                      const Spacer(),
                      _BookmarkButton(bookmarked: bookmarked, onTap: onBookmark, filledBackground: true),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(sheet.title, style: HealthText.headlineSm.copyWith(height: 1.3)),
                const SizedBox(height: 8),
                Text(sheet.summary, style: HealthText.bodyMd, maxLines: 2, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: HealthColors.primaryContainer.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        _initials(sheet.author),
                        style: HealthText.labelSm.copyWith(color: HealthColors.primary, fontWeight: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(sheet.author, style: HealthText.labelSm),
                          Text(sheet.organization, style: HealthText.bodySm.copyWith(color: HealthColors.outline)),
                        ],
                      ),
                    ),
                    Container(
                      width: 36,
                      height: 36,
                      decoration: const BoxDecoration(color: HealthColors.surfaceContainer, shape: BoxShape.circle),
                      child: const Icon(Symbols.arrow_forward, size: 18, color: HealthColors.primary),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SheetRow extends StatelessWidget {
  const _SheetRow({required this.sheet, required this.bookmarked, required this.onTap, required this.onBookmark});

  final HealthSheet sheet;
  final bool bookmarked;
  final VoidCallback onTap;
  final VoidCallback onBookmark;

  @override
  Widget build(BuildContext context) {
    final urgent = sheet.category == HealthSheetCategory.emergency;
    return HealthCard(
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: 88,
              height: 88,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  HealthSheetImage(sheet: sheet),
                  if (urgent)
                    Positioned(
                      right: 4,
                      bottom: 4,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: HealthColors.error.withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Icon(Symbols.warning, size: 14, color: Colors.white),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: SizedBox(
              height: 88,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: urgent
                              ? [
                                  const HealthPill(
                                    label: 'Urgence vitale',
                                    background: HealthColors.errorContainer,
                                    foreground: HealthColors.onErrorContainer,
                                  ),
                                ]
                              : [
                                  for (final s in sheet.species.take(2))
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: HealthColors.surfaceHigh,
                                        borderRadius: BorderRadius.circular(999),
                                      ),
                                      child: Text(s, style: HealthText.labelSm.copyWith(color: HealthColors.primary)),
                                    ),
                                ],
                        ),
                      ),
                      _BookmarkButton(bookmarked: bookmarked, onTap: onBookmark),
                    ],
                  ),
                  Expanded(
                    child: Text(
                      sheet.title,
                      style: HealthText.labelLg.copyWith(height: 1.3),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          sheet.organization.isEmpty ? sheet.author : '${sheet.author} • ${sheet.organization}',
                          style: HealthText.bodySm,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const Icon(Symbols.schedule, size: 13, color: HealthColors.outline),
                      const SizedBox(width: 2),
                      Text('${sheet.readMinutes} min', style: HealthText.labelSm.copyWith(color: HealthColors.outline)),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BookmarkButton extends StatelessWidget {
  const _BookmarkButton({required this.bookmarked, required this.onTap, this.filledBackground = false});

  final bool bookmarked;
  final VoidCallback onTap;
  final bool filledBackground;

  @override
  Widget build(BuildContext context) {
    final color = bookmarked ? HealthColors.secondary : (filledBackground ? HealthColors.onSurfaceVariant : HealthColors.outline);
    return Material(
      color: filledBackground ? Colors.white.withValues(alpha: 0.8) : Colors.transparent,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Tooltip(
          message: bookmarked ? 'Retirer des fiches enregistrées' : 'Enregistrer cette fiche',
          child: SizedBox(
            width: 32,
            height: 32,
            child: Icon(Symbols.bookmark, size: filledBackground ? 18 : 20, color: color, fill: bookmarked ? 1 : 0),
          ),
        ),
      ),
    );
  }
}

/// Encart « Un doute sur l'état de votre animal ? » : vétérinaire de garde et annuaire.
class HealthHelpCard extends StatelessWidget {
  const HealthHelpCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: HealthColors.surfaceHigh,
        borderRadius: BorderRadius.circular(16),
        boxShadow: HealthColors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(color: HealthColors.errorContainer, borderRadius: BorderRadius.circular(12)),
                child: const Icon(Symbols.call_quality, size: 24, color: HealthColors.onErrorContainer),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Un doute sur l'état de votre animal ?", style: HealthText.labelLg),
                    const SizedBox(height: 2),
                    Text(
                      "Les conseils numériques ne remplacent jamais un examen clinique approfondi. En cas de détresse respiratoire ou d'abattement soudain, agissez sans attendre.",
                      style: HealthText.bodySm.copyWith(height: 1.6),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () => launchUrl(Uri(scheme: 'tel', path: '3115')),
            style: FilledButton.styleFrom(
              backgroundColor: HealthColors.primary,
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            icon: const Icon(Symbols.phone_in_talk, size: 20),
            label: const Text('Appeler un vétérinaire de garde'),
          ),
          const SizedBox(height: 4),
          TextButton(
            // Annuaire des services (module 6) : l'onglet « Services » de la structure principale.
            onPressed: () => Navigator.of(context).pop(3),
            style: TextButton.styleFrom(
              foregroundColor: HealthColors.primary,
              minimumSize: const Size.fromHeight(40),
              textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text("Consulter l'annuaire vétérinaire certifié"),
                SizedBox(width: 4),
                Icon(Symbols.chevron_right, size: 16),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
