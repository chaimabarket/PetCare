import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../../core/routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../notifications/data/notification_service.dart';
import '../../../profile/data/profile_repository.dart';
import '../../../profile/data/user_profile.dart';
import '../../../profile/presentation/widgets/user_avatar.dart';
import '../../data/appointment.dart';

/// Couleurs des maquettes Stitch du module Rendez-vous (palette Material 3 de `code.html`).
abstract final class RdvColors {
  static const primary = Color(0xFF005C55);
  static const primaryContainer = AppColors.teal; // #0F766E
  static const primaryFixed = Color(0xFF9CF2E8);
  static const onPrimaryFixedVariant = Color(0xFF00504A);
  static const surface = Color(0xFFF8F9FF);
  static const surfaceLow = Color(0xFFEFF4FF);
  static const surfaceContainer = Color(0xFFE6EEFF);
  static const surfaceHigh = Color(0xFFDEE9FC);
  static const surfaceHighest = Color(0xFFD9E3F6);
  static const onSurface = Color(0xFF121C2A);
  static const onSurfaceVariant = Color(0xFF3E4947);
  static const outline = Color(0xFF6E7977);
  static const outlineVariant = Color(0xFFBDC9C6);
  static const secondary = Color(0xFF8C4E38);
  static const secondaryFixed = Color(0xFFFFDBCF);
  static const secondaryContainer = Color(0xFFFEAE92);
  static const onSecondaryContainer = Color(0xFF793F2A);
  static const error = Color(0xFFBA1A1A);
  static const errorContainer = Color(0xFFFFDAD6);
  static const onErrorContainer = Color(0xFF93000A);

  static const cardShadow = [BoxShadow(color: Color(0x0F0F172A), blurRadius: 8, offset: Offset(0, 2))];
}

/// Carte blanche à coins arrondis de 16 px, ombre douce.
class RdvCard extends StatelessWidget {
  const RdvCard({super.key, required this.child, this.padding = const EdgeInsets.all(16), this.color});

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: color == null ? RdvColors.cardShadow : null,
      ),
      child: child,
    );
  }
}

/// Pastille de statut arrondie avec icône (Confirmé, En attente, Annulé, Terminé, Rappel).
class StatusPill extends StatelessWidget {
  const StatusPill({
    super.key,
    required this.label,
    required this.background,
    required this.foreground,
    this.icon,
  });

  factory StatusPill.forStatus(AppointmentStatus status, {String? label}) => switch (status) {
        AppointmentStatus.confirmed => StatusPill(
            label: label ?? status.label,
            icon: Icons.check_circle_outline,
            background: RdvColors.primaryFixed.withValues(alpha: 0.45),
            foreground: RdvColors.onPrimaryFixedVariant,
          ),
        AppointmentStatus.planned => StatusPill(
            label: label ?? status.label,
            icon: Icons.hourglass_top,
            background: RdvColors.secondaryFixed,
            foreground: RdvColors.onSecondaryContainer,
          ),
        AppointmentStatus.cancelled => StatusPill(
            label: label ?? status.label,
            background: RdvColors.errorContainer,
            foreground: RdvColors.onErrorContainer,
          ),
        AppointmentStatus.completed => StatusPill(
            label: label ?? status.label,
            icon: Icons.task_alt,
            background: RdvColors.surfaceHigh,
            foreground: RdvColors.onSurfaceVariant,
          ),
      };

  final String label;
  final IconData? icon;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(999)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: foreground),
            const SizedBox(width: 4),
          ],
          Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: foreground)),
        ],
      ),
    );
  }
}

/// Petite étiquette de type (Vaccin, Toilettage, Personnel…) dans les cartes.
class TypeTag extends StatelessWidget {
  const TypeTag({super.key, required this.label, required this.background, required this.foreground, this.icon});

  factory TypeTag.forType(AppointmentType type, {String? label}) {
    final (bg, fg) = switch (type) {
      AppointmentType.vaccine || AppointmentType.vet => (RdvColors.primaryContainer, Colors.white),
      AppointmentType.grooming => (RdvColors.secondaryContainer, RdvColors.onSecondaryContainer),
      _ => (RdvColors.surfaceHigh, RdvColors.onSurfaceVariant),
    };
    return TypeTag(label: label ?? type.label, icon: appointmentTypeIcon(type), background: bg, foreground: fg);
  }

  final String label;
  final IconData? icon;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(6)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: foreground),
            const SizedBox(width: 4),
          ],
          Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: foreground)),
        ],
      ),
    );
  }
}

IconData appointmentTypeIcon(AppointmentType type) => switch (type) {
      AppointmentType.vaccine => Icons.vaccines_outlined,
      AppointmentType.vet => Icons.local_hospital_outlined,
      AppointmentType.grooming => Icons.content_cut,
      AppointmentType.personalCare => Icons.content_cut,
      AppointmentType.training => Icons.school_outlined,
      AppointmentType.walk => Icons.directions_walk,
      AppointmentType.other => Icons.event_note_outlined,
    };

/// Photo ronde de l'animal, avec une pastille patte en bas à droite.
/// Sans photo : l'initiale du nom sur fond pastel.
class PetAvatar extends StatelessWidget {
  const PetAvatar({super.key, required this.name, this.photoUrl, this.size = 52, this.badge = true});

  final String name;
  final String? photoUrl;
  final double size;
  final bool badge;

  @override
  Widget build(BuildContext context) {
    final initial = name.isEmpty ? '?' : name.characters.first.toUpperCase();
    final picture = ClipRRect(
      borderRadius: BorderRadius.circular(size / 2),
      child: SizedBox(
        width: size,
        height: size,
        child: photoUrl == null || photoUrl!.isEmpty
            ? ColoredBox(
                color: RdvColors.secondaryFixed,
                child: Center(
                  child: Text(
                    initial,
                    style: TextStyle(
                      fontSize: size * 0.4,
                      fontWeight: FontWeight.w700,
                      color: RdvColors.onSecondaryContainer,
                    ),
                  ),
                ),
              )
            : Image.network(
                photoUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const ColoredBox(color: RdvColors.secondaryFixed),
              ),
      ),
    );
    if (!badge) return picture;

    final dot = size * 0.4;
    return SizedBox(
      width: size + 4,
      height: size + 4,
      child: Stack(
        children: [
          picture,
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: dot,
              height: dot,
              decoration: BoxDecoration(
                color: RdvColors.primaryFixed,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: Icon(Icons.pets, size: dot * 0.55, color: RdvColors.onPrimaryFixedVariant),
            ),
          ),
        ],
      ),
    );
  }
}

/// Bouton plat coloré des cartes (Itinéraire, Carnet santé, Modifier, Contacter le salon…).
class SoftButton extends StatelessWidget {
  const SoftButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
    this.background = RdvColors.surfaceContainer,
    this.foreground = RdvColors.onSurface,
    this.height = 40,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final Color background;
  final Color foreground;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: background,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          height: height,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: foreground),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: foreground),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Puce de filtre arrondie (sélectionnée = fond teal).
class RdvChip extends StatelessWidget {
  const RdvChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.leading,
    this.trailing,
    this.selectedColor = RdvColors.primaryContainer,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Widget? leading;
  final Widget? trailing;
  final Color selectedColor;

  @override
  Widget build(BuildContext context) {
    final fg = selected ? Colors.white : RdvColors.onSurface;
    return Material(
      color: selected ? selectedColor : Colors.white,
      shape: StadiumBorder(
        side: BorderSide(color: selected ? selectedColor : RdvColors.outlineVariant.withValues(alpha: 0.6)),
      ),
      child: InkWell(
        onTap: onTap,
        customBorder: const StadiumBorder(),
        child: Padding(
          padding: EdgeInsets.fromLTRB(leading == null ? 14 : 6, 7, 14, 7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (leading != null) ...[leading!, const SizedBox(width: 6)],
              Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: fg)),
              if (trailing != null) ...[const SizedBox(width: 6), trailing!],
            ],
          ),
        ),
      ),
    );
  }
}

/// Titre de champ avec astérisque rouge pour les champs obligatoires.
class FieldLabel extends StatelessWidget {
  const FieldLabel(this.text, {super.key, this.required = false, this.trailing});

  final String text;
  final bool required;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(
            child: Text.rich(
              TextSpan(
                text: text,
                children: [
                  if (required) const TextSpan(text: ' *', style: TextStyle(color: RdvColors.error)),
                ],
              ),
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: RdvColors.onSurface),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// En-tête et barre du bas des écrans Agenda et Rappels (onglet Accueil actif).
///
/// Toucher un autre onglet ferme l'écran et renvoie son numéro : l'Accueil ouvre alors l'onglet.
class RdvTabScaffold extends StatelessWidget {
  const RdvTabScaffold({
    super.key,
    required this.body,
    this.floatingActionButton,
    this.showLogo = true,
    this.extraAction,
  });

  final Widget body;
  final Widget? floatingActionButton;
  final bool showLogo;
  final Widget? extraAction;

  static const _tabs = [
    (label: 'Accueil', icon: Icons.home_outlined, activeIcon: Icons.home),
    (label: 'Mes animaux', icon: Icons.pets_outlined, activeIcon: Icons.pets),
    (label: 'Communauté', icon: Icons.volunteer_activism_outlined, activeIcon: Icons.volunteer_activism),
    (label: 'Services', icon: Icons.medical_services_outlined, activeIcon: Icons.medical_services),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: RdvColors.surface,
      appBar: AppBar(
        toolbarHeight: 64,
        backgroundColor: RdvColors.surface,
        surfaceTintColor: Colors.transparent,
        automaticallyImplyLeading: false,
        titleSpacing: 16,
        title: Row(
          children: [
            if (showLogo) ...[
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: RdvColors.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.pets, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 10),
            ],
            const Text(
              'Accueil',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: RdvColors.onSurface),
            ),
          ],
        ),
        actions: [
          const RdvBellButton(),
          ?extraAction,
          const Padding(padding: EdgeInsets.only(right: 12, left: 4), child: RdvProfileButton()),
        ],
      ),
      body: body,
      floatingActionButton: floatingActionButton,
      bottomNavigationBar: NavigationBar(
        selectedIndex: 0,
        onDestinationSelected: (index) => Navigator.of(context).pop(index),
        backgroundColor: AppColors.surface,
        indicatorColor: AppColors.teal.withValues(alpha: 0.12),
        surfaceTintColor: Colors.transparent,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontSize: 12,
            fontWeight: states.contains(WidgetState.selected) ? FontWeight.w600 : FontWeight.w500,
            color: states.contains(WidgetState.selected) ? AppColors.teal : RdvColors.onSurfaceVariant,
          ),
        ),
        destinations: [
          for (final tab in _tabs)
            NavigationDestination(
              icon: Icon(tab.icon, color: RdvColors.onSurfaceVariant),
              selectedIcon: Icon(tab.activeIcon, color: AppColors.teal),
              label: tab.label,
            ),
        ],
      ),
    );
  }
}

/// Ouvre un écran du module qui peut renvoyer un numéro d'onglet, et le fait suivre :
/// si l'utilisateur a touché un onglet de la barre du bas, on ferme aussi l'écran courant.
Future<void> pushRdvTabRoute(BuildContext context, String routeName, {Object? arguments, bool forward = true}) async {
  final tab = await Navigator.of(context).pushNamed<Object?>(routeName, arguments: arguments);
  if (tab is int && forward && context.mounted) Navigator.of(context).pop(tab);
}

/// Cloche avec pastille des notifications non lues (même comportement que l'en-tête principal).
class RdvBellButton extends StatefulWidget {
  const RdvBellButton({super.key});

  @override
  State<RdvBellButton> createState() => _RdvBellButtonState();
}

class _RdvBellButtonState extends State<RdvBellButton> {
  final _uid = FirebaseAuth.instance.currentUser?.uid;
  late final _unread = _uid == null ? null : NotificationService().watchUnreadCount(_uid);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<int>(
      stream: _unread,
      builder: (context, snapshot) {
        final unread = snapshot.data ?? 0;
        return IconButton(
          tooltip: unread > 0 ? 'Notifications ($unread non lues)' : 'Notifications',
          onPressed: () => Navigator.of(context).pushNamed(AppRoutes.notifications),
          icon: Badge(
            isLabelVisible: unread > 0,
            backgroundColor: AppColors.coralText,
            smallSize: 9,
            child: const Icon(Icons.notifications_none, color: RdvColors.onSurfaceVariant),
          ),
        );
      },
    );
  }
}

/// Avatar de l'utilisateur, ouvre « Mon profil ».
class RdvProfileButton extends StatefulWidget {
  const RdvProfileButton({super.key});

  @override
  State<RdvProfileButton> createState() => _RdvProfileButtonState();
}

class _RdvProfileButtonState extends State<RdvProfileButton> {
  final _uid = FirebaseAuth.instance.currentUser?.uid;
  late final _profile = _uid == null ? null : ProfileRepository().watch(_uid);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<UserProfile?>(
      stream: _profile,
      builder: (context, snapshot) {
        final initials = snapshot.data?.initials ?? '';
        return InkResponse(
          onTap: () => Navigator.of(context).pushNamed(AppRoutes.profile),
          radius: 22,
          child: Semantics(
            button: true,
            label: 'Mon profil',
            child: initials.isEmpty
                ? const CircleAvatar(
                    radius: 16,
                    backgroundColor: RdvColors.primary,
                    child: Icon(Icons.person_outline, color: Colors.white, size: 18),
                  )
                : UserAvatar(initials: initials, radius: 16),
          ),
        );
      },
    );
  }
}

/// Message d'erreur lisible pour l'utilisateur, quelle que soit l'exception.
String friendlyError(Object error) {
  final text = error.toString();
  if (text.contains('permission-denied')) {
    return "Action refusée par le serveur. Vérifiez que vous êtes connecté(e) et que le rendez-vous vous concerne.";
  }
  if (text.contains('unavailable') || text.contains('network')) {
    return 'Connexion impossible. Vérifiez votre réseau puis réessayez.';
  }
  return text.replaceFirst('Exception: ', '');
}
