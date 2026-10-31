import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../appointments/presentation/widgets/rdv_ui.dart' show RdvColors, RdvProfileButton;

/// Couleurs des maquettes Stitch du module Santé (palette Material 3 de `code.html`,
/// identique à celle du module Rendez-vous, plus les couleurs Tailwind des cartes du carnet).
abstract final class HealthColors {
  static const primary = RdvColors.primary; // #005C55
  static const primaryContainer = RdvColors.primaryContainer; // #0F766E
  static const primaryFixed = RdvColors.primaryFixed;
  static const onPrimaryFixed = Color(0xFF00201D);
  static const surface = RdvColors.surface;
  static const surfaceLow = RdvColors.surfaceLow;
  static const surfaceContainer = RdvColors.surfaceContainer;
  static const surfaceHigh = RdvColors.surfaceHigh;
  static const surfaceHighest = RdvColors.surfaceHighest;
  static const onSurface = RdvColors.onSurface;
  static const onSurfaceVariant = RdvColors.onSurfaceVariant;
  static const outline = RdvColors.outline;
  static const outlineVariant = RdvColors.outlineVariant;
  static const secondary = RdvColors.secondary;
  static const secondaryFixed = RdvColors.secondaryFixed;
  static const secondaryContainer = RdvColors.secondaryContainer;
  static const onSecondaryContainer = RdvColors.onSecondaryContainer;
  static const onSecondaryFixed = Color(0xFF380D01);
  static const onSecondaryFixedVariant = Color(0xFF6F3723);
  static const tertiary = Color(0xFF7F4025);
  static const error = RdvColors.error;
  static const errorContainer = RdvColors.errorContainer;
  static const onErrorContainer = RdvColors.onErrorContainer;
  static const inverseSurface = Color(0xFF27313F);
  static const inversePrimary = Color(0xFF80D5CB);

  // Tailwind : emerald, blue et amber des pastilles du carnet.
  static const emerald50 = Color(0xFFECFDF5);
  static const emerald700 = Color(0xFF047857);
  static const blue50 = Color(0xFFEFF6FF);
  static const blue700 = Color(0xFF1D4ED8);
  static const amber50 = Color(0xFFFFFBEB);
  static const amber100 = Color(0xFFFEF3C7);
  static const amber800 = Color(0xFF92400E);

  static const cardShadow = RdvColors.cardShadow;
}

/// Styles de texte des maquettes (échelle `fontSize` de `code.html`).
abstract final class HealthText {
  static const headlineLg = TextStyle(fontSize: 26, height: 34 / 26, fontWeight: FontWeight.w700, color: HealthColors.onSurface, letterSpacing: -0.4);
  static const headlineMd = TextStyle(fontSize: 22, height: 28 / 22, fontWeight: FontWeight.w600, color: HealthColors.onSurface);
  static const headlineSm = TextStyle(fontSize: 18, height: 24 / 18, fontWeight: FontWeight.w600, color: HealthColors.onSurface);
  static const labelLg = TextStyle(fontSize: 14, height: 20 / 14, fontWeight: FontWeight.w600, color: HealthColors.onSurface);
  static const labelMd = TextStyle(fontSize: 12, height: 16 / 12, fontWeight: FontWeight.w600, color: HealthColors.onSurface);
  static const labelSm = TextStyle(fontSize: 11, height: 14 / 11, fontWeight: FontWeight.w500, color: HealthColors.onSurface);
  static const bodyMd = TextStyle(fontSize: 14, height: 20 / 14, color: HealthColors.onSurfaceVariant);
  static const bodySm = TextStyle(fontSize: 12, height: 16 / 12, color: HealthColors.onSurfaceVariant);
}

/// Carte blanche à coins arrondis de 16 px, ombre douce (`rounded-2xl shadow-sm`).
class HealthCard extends StatelessWidget {
  const HealthCard({super.key, required this.child, this.padding = const EdgeInsets.all(16), this.color, this.onTap});

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color ?? Colors.white,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      shadowColor: Colors.transparent,
      child: Ink(
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), boxShadow: HealthColors.cardShadow),
        child: InkWell(onTap: onTap, child: Padding(padding: padding, child: child)),
      ),
    );
  }
}

/// Pastille arrondie (Validé, À jour, En cours, Terminé, Arrêté, Actif…), avec icône ou point.
class HealthPill extends StatelessWidget {
  const HealthPill({
    super.key,
    required this.label,
    required this.background,
    required this.foreground,
    this.icon,
    this.dotColor,
  });

  final String label;
  final Color background;
  final Color foreground;
  final IconData? icon;
  final Color? dotColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(999)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 14, color: foreground), const SizedBox(width: 4)],
          if (dotColor != null) ...[
            Container(width: 7, height: 7, decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle)),
            const SizedBox(width: 6),
          ],
          Text(label, style: HealthText.labelSm.copyWith(color: foreground, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

/// Puce de filtre horizontale (sélectionnée : fond `primary`).
class HealthFilterChip extends StatelessWidget {
  const HealthFilterChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
    this.background,
    this.foreground,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  /// Couleurs quand la puce n'est pas sélectionnée (ex. « Urgences » en rouge pâle).
  final Color? background;
  final Color? foreground;

  @override
  Widget build(BuildContext context) {
    final fg = selected ? Colors.white : (foreground ?? HealthColors.onSurfaceVariant);
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: selected ? HealthColors.primary : (background ?? Colors.white),
        borderRadius: BorderRadius.circular(999),
        elevation: 0,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(999),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(999), boxShadow: HealthColors.cardShadow),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[Icon(icon, size: 16, color: fg, fill: 1), const SizedBox(width: 4)],
                Text(label, style: HealthText.labelMd.copyWith(color: fg)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Photo ronde de l'animal ; sans photo, l'initiale sur fond pastel.
class HealthPetPhoto extends StatelessWidget {
  const HealthPetPhoto({super.key, required this.name, required this.photo, required this.size});

  final String name;
  final Uint8List? photo;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: const BoxDecoration(shape: BoxShape.circle, color: HealthColors.surfaceHigh),
      alignment: Alignment.center,
      child: photo != null
          ? Image.memory(photo!, width: size, height: size, fit: BoxFit.cover, gaplessPlayback: true)
          : Text(
              name.isEmpty ? '?' : name.characters.first.toUpperCase(),
              style: TextStyle(fontSize: size * 0.4, fontWeight: FontWeight.w700, color: HealthColors.primary),
            ),
    );
  }
}

/// Petite pastille ronde sur la photo de l'animal (✓, patte, trousse).
class HealthPhotoBadge extends StatelessWidget {
  const HealthPhotoBadge({super.key, required this.icon, required this.size, this.color = HealthColors.primaryContainer});

  final IconData icon;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: const [BoxShadow(color: Color(0x22000000), blurRadius: 4, offset: Offset(0, 1))],
      ),
      child: Icon(icon, size: size * 0.58, color: Colors.white, fill: 1),
    );
  }
}

/// En-tête des écrans du module : flèche retour, titre, actions et avatar du profil.
class HealthAppBar extends StatelessWidget implements PreferredSizeWidget {
  const HealthAppBar({super.key, required this.title, this.actions = const [], this.leading});

  final String title;
  final List<Widget> actions;

  /// Remplace la flèche retour (ex. le logo de « Santé & Conseils »).
  final Widget? leading;

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      toolbarHeight: 64,
      backgroundColor: HealthColors.surface.withValues(alpha: 0.92),
      surfaceTintColor: Colors.transparent,
      shadowColor: const Color(0x0A000000),
      elevation: 1,
      scrolledUnderElevation: 1,
      automaticallyImplyLeading: false,
      titleSpacing: 4,
      leading: leading ??
          IconButton(
            tooltip: 'Retour',
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(Symbols.arrow_back, color: HealthColors.onSurface),
          ),
      title: Text(title, style: HealthText.headlineSm.copyWith(letterSpacing: -0.2), overflow: TextOverflow.ellipsis),
      actions: [
        ...actions,
        const Padding(padding: EdgeInsets.only(left: 4, right: 16), child: RdvProfileButton()),
      ],
    );
  }
}

/// Barre du bas commune aux 4 onglets. Toucher un autre onglet ferme l'écran et renvoie son
/// numéro, que l'écran appelant transmet jusqu'à la structure principale.
class HealthBottomBar extends StatelessWidget {
  const HealthBottomBar({super.key, required this.selectedIndex});

  final int selectedIndex;

  static const _tabs = [
    (label: 'Accueil', icon: Icons.home_outlined, activeIcon: Icons.home),
    (label: 'Mes animaux', icon: Icons.pets_outlined, activeIcon: Icons.pets),
    (label: 'Communauté', icon: Icons.volunteer_activism_outlined, activeIcon: Icons.volunteer_activism),
    (label: 'Services', icon: Icons.medical_services_outlined, activeIcon: Icons.medical_services),
  ];

  @override
  Widget build(BuildContext context) {
    return NavigationBar(
      selectedIndex: selectedIndex,
      onDestinationSelected: (index) => Navigator.of(context).pop(index),
      backgroundColor: AppColors.surface,
      indicatorColor: AppColors.teal.withValues(alpha: 0.12),
      surfaceTintColor: Colors.transparent,
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => TextStyle(
          fontSize: 12,
          fontWeight: states.contains(WidgetState.selected) ? FontWeight.w600 : FontWeight.w500,
          color: states.contains(WidgetState.selected) ? AppColors.teal : HealthColors.onSurfaceVariant,
        ),
      ),
      destinations: [
        for (final tab in _tabs)
          NavigationDestination(
            icon: Icon(tab.icon, color: HealthColors.onSurfaceVariant),
            selectedIcon: Icon(tab.activeIcon, color: AppColors.teal),
            label: tab.label,
          ),
      ],
    );
  }
}

/// Ouvre un écran du module ; s'il renvoie un numéro d'onglet, ferme aussi l'écran courant
/// pour que l'onglet s'affiche dans la structure principale.
Future<T?> pushHealthRoute<T>(BuildContext context, String routeName, {Object? arguments}) async {
  final result = await Navigator.of(context).pushNamed<Object?>(routeName, arguments: arguments);
  if (result is int && context.mounted) {
    Navigator.of(context).pop(result);
    return null;
  }
  return result is T ? result : null;
}

/// Champ de saisie des formulaires (`h-12 bg-surface-container-low rounded-xl`), icône à droite.
InputDecoration healthInputDecoration({String? hint, IconData? suffixIcon, Color? fill, Color? iconColor}) {
  final border = OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none);
  return InputDecoration(
    hintText: hint,
    hintStyle: HealthText.bodyMd.copyWith(color: HealthColors.outline),
    filled: true,
    fillColor: fill ?? HealthColors.surfaceLow,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    suffixIcon: suffixIcon == null ? null : Icon(suffixIcon, size: 20, color: iconColor ?? HealthColors.onSurfaceVariant),
    border: border,
    enabledBorder: border,
    focusedBorder: border.copyWith(borderSide: const BorderSide(color: HealthColors.primaryContainer, width: 1.5)),
    errorBorder: border.copyWith(borderSide: const BorderSide(color: AppColors.error, width: 1.5)),
    focusedErrorBorder: border.copyWith(borderSide: const BorderSide(color: AppColors.error, width: 1.5)),
  );
}

/// Libellé de champ : « Nom ou Spécialité du vaccin * » ou « … (optionnel) ».
class HealthFieldLabel extends StatelessWidget {
  const HealthFieldLabel(this.text, {super.key, this.required = false, this.optional = false});

  final String text;
  final bool required;
  final bool optional;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text.rich(
        TextSpan(
          text: text,
          style: HealthText.labelLg,
          children: [
            if (required) const TextSpan(text: ' *', style: TextStyle(color: HealthColors.error)),
            if (optional) TextSpan(text: ' (optionnel)', style: HealthText.bodySm.copyWith(fontWeight: FontWeight.w400)),
          ],
        ),
      ),
    );
  }
}

/// Message d'erreur lisible, quelle que soit l'exception.
String friendlyHealthError(Object error) {
  final text = error.toString();
  if (text.contains('permission-denied')) {
    return "Accès refusé. Seul le propriétaire de l'animal peut consulter et modifier son carnet de santé.";
  }
  if (text.contains('unavailable') || text.contains('network')) {
    return 'Connexion impossible. Vérifiez votre réseau puis réessayez.';
  }
  return text.replaceFirst('Exception: ', '');
}

/// Toast sombre des maquettes (`bg-inverse-surface`), avec icône verte.
void showHealthToast(BuildContext context, String message, {IconData icon = Symbols.check_circle}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: HealthColors.inverseSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        content: Row(
          children: [
            Icon(icon, color: HealthColors.inversePrimary, fill: 1),
            const SizedBox(width: 10),
            Expanded(child: Text(message, style: const TextStyle(fontSize: 14, color: Color(0xFFEAF1FF)))),
          ],
        ),
      ),
    );
}

/// État vide ou d'erreur, centré, dans les listes du module.
class HealthEmptyState extends StatelessWidget {
  const HealthEmptyState({super.key, required this.icon, required this.title, required this.message});

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return HealthCard(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: const BoxDecoration(color: HealthColors.surfaceLow, shape: BoxShape.circle),
            child: Icon(icon, size: 28, color: HealthColors.primary),
          ),
          const SizedBox(height: 12),
          Text(title, style: HealthText.headlineSm, textAlign: TextAlign.center),
          const SizedBox(height: 4),
          Text(message, style: HealthText.bodyMd, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}
