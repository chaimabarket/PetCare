import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../core/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../appointments/presentation/widgets/upcoming_appointments_card.dart';
import '../../profile/data/profile_repository.dart';
import '../../profile/data/user_profile.dart';
import '../../profile/presentation/widgets/user_avatar.dart';

/// Onglet Accueil (maquette Stitch « Accueil »).
///
/// Les sections Mes animaux, Prochains rendez-vous et Rappels de soins affichent pour l'instant
/// un état vide : les modules 1, 2 et 3 y brancheront leurs données.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.onOpenTab});

  /// Ouvre un onglet de la barre du bas (1 = Mes animaux, 2 = Communauté, 3 = Services).
  final ValueChanged<int> onOpenTab;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _user = FirebaseAuth.instance.currentUser;
  late final _profileStream = _user == null ? null : ProfileRepository().watch(_user.uid);

  /// Ouvre un écran du module Rendez-vous ; s'il renvoie un onglet, on l'affiche.
  Future<void> _openRoute(String route) async {
    final tab = await Navigator.of(context).pushNamed<Object?>(route);
    if (tab is int) widget.onOpenTab(tab);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<UserProfile?>(
      stream: _profileStream,
      builder: (context, snapshot) {
        final profile = snapshot.data;
        final signedIn = _user != null;

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            _Greeting(profile: profile),
            const SizedBox(height: 24),
            if (!signedIn) ...[
              const _VisitorCard(),
              const SizedBox(height: 24),
            ] else ...[
              _SectionHeader(
                title: 'Mes animaux',
                actionLabel: 'Gérer',
                onAction: () => widget.onOpenTab(1),
              ),
              const SizedBox(height: 12),
              // Module 1 (Profils des animaux) : afficher ici les animaux de l'utilisateur.
              _AddPetButton(onTap: () => widget.onOpenTab(1)),
              const SizedBox(height: 24),
              // Module 3 (Rendez-vous) : les 2 prochains rendez-vous et l'agenda.
              UpcomingAppointmentsCard(onOpenTab: widget.onOpenTab),
              const SizedBox(height: 24),
              // Module 2 (Santé) : afficher ici les vaccins et traitements à venir.
              _SectionCard(
                icon: Icons.notifications_active_outlined,
                title: 'Rappels de soins',
                // Module 3 : la liste complète des rappels (soins et rendez-vous).
                actionLabel: 'Voir tout',
                onAction: () => _openRoute(AppRoutes.reminders),
                emptyText: 'Aucun rappel actif. Les prochains vaccins et traitements apparaîtront ici.',
              ),
              const SizedBox(height: 24),
            ],
            const Text(
              'Raccourcis rapides',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, letterSpacing: -0.3),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _ShortcutCard(
                    icon: Icons.volunteer_activism_outlined,
                    iconBackground: const Color(0xFFFFDBCF),
                    iconColor: const Color(0xFF8C4E38),
                    title: 'Adoption',
                    subtitle: 'Trouver un compagnon',
                    onTap: () => widget.onOpenTab(2),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _ShortcutCard(
                    icon: Icons.track_changes,
                    iconBackground: const Color(0xFF9CF2E8),
                    iconColor: const Color(0xFF00504A),
                    title: 'Perdus & Trouvés',
                    subtitle: 'Signaler ou aider',
                    onTap: () => widget.onOpenTab(2),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _Greeting extends StatelessWidget {
  const _Greeting({required this.profile});

  final UserProfile? profile;

  @override
  Widget build(BuildContext context) {
    final name = profile?.firstName;

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name == null || name.isEmpty ? 'Bonjour 👋' : 'Bonjour $name 👋',
                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700, letterSpacing: -0.5),
              ),
              const SizedBox(height: 2),
              const Text(
                "Prenez soin de vos compagnons aujourd'hui",
                style: TextStyle(fontSize: 15, color: Color(0xFF3E4947)),
              ),
            ],
          ),
        ),
        if (profile != null) UserAvatar(initials: profile!.initials, radius: 30),
      ],
    );
  }
}

class _VisitorCard extends StatelessWidget {
  const _VisitorCard();

  @override
  Widget build(BuildContext context) {
    return _Card(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Row(
            children: [
              Icon(Icons.explore_outlined, color: AppColors.teal),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Vous naviguez en visiteur',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Consultez librement les annonces, les services et les fiches santé. '
            'Créez un compte pour suivre vos animaux, réserver ou publier une annonce.',
            style: TextStyle(fontSize: 14, height: 1.5, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () => Navigator.of(context).pushNamed(AppRoutes.register),
            child: const Text('Créer un compte'),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: () => Navigator.of(context).pushNamed(AppRoutes.login),
            child: const Text('Se connecter'),
          ),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child, this.padding = EdgeInsets.zero});

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: Color(0x0F0F172A), blurRadius: 3, offset: Offset(0, 1))],
      ),
      child: child,
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.actionLabel, required this.onAction});

  final String title;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600, letterSpacing: -0.3)),
        const Spacer(),
        TextButton(
          onPressed: onAction,
          style: TextButton.styleFrom(
            foregroundColor: const Color(0xFF005C55),
            textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          child: Text(actionLabel),
        ),
      ],
    );
  }
}

class _AddPetButton extends StatelessWidget {
  const _AddPetButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: const Padding(
          padding: EdgeInsets.all(4),
          child: Column(
            children: [
              CircleAvatar(
                radius: 40,
                backgroundColor: Color(0xFFE6EEFF),
                child: Icon(Icons.add, size: 32, color: AppColors.teal),
              ),
              SizedBox(height: 8),
              Text(
                'Ajouter',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.teal),
              ),
              Text('Nouveau', style: TextStyle(fontSize: 12, color: Color(0xFF3E4947))),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.icon,
    required this.title,
    required this.emptyText,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String emptyText;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return _Card(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF4FF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 22, color: AppColors.teal),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w600, letterSpacing: -0.3),
                ),
              ),
              if (actionLabel != null)
                TextButton.icon(
                  onPressed: onAction,
                  iconAlignment: IconAlignment.end,
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF005C55),
                    textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  icon: const Icon(Icons.chevron_right, size: 18),
                  label: Text(actionLabel!),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF4FF),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              emptyText,
              style: const TextStyle(fontSize: 14, height: 1.4, color: Color(0xFF3E4947)),
            ),
          ),
        ],
      ),
    );
  }
}

class _ShortcutCard extends StatelessWidget {
  const _ShortcutCard({
    required this.icon,
    required this.iconBackground,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color iconBackground;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(color: iconBackground, borderRadius: BorderRadius.circular(12)),
                child: Icon(icon, size: 28, color: iconColor),
              ),
              const SizedBox(height: 40),
              Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
              Text(subtitle, style: const TextStyle(fontSize: 13, color: Color(0xFF3E4947))),
            ],
          ),
        ),
      ),
    );
  }
}
