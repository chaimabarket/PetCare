import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../core/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../auth/data/auth_service.dart';
import '../../notifications/data/notification_service.dart';
import '../data/profile_repository.dart';
import '../data/user_profile.dart';
import 'widgets/user_avatar.dart';

/// Écran « Mon Profil » (maquette Stitch du même nom).
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _uid = FirebaseAuth.instance.currentUser!.uid;
  final _repository = ProfileRepository();
  final _authService = AuthService();
  late final _profileStream = _repository.watch(_uid);
  late final _unreadStream = NotificationService().watchUnreadCount(_uid);

  void _editProfile(UserProfile profile) =>
      Navigator.of(context).pushNamed(AppRoutes.editProfile, arguments: profile);

  Future<void> _changePassword(UserProfile profile) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Changer le mot de passe'),
        content: Text(
          'Nous allons envoyer un lien sécurisé à ${profile.email} pour choisir un nouveau mot de passe.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Envoyer')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      await _authService.sendPasswordReset(profile.email);
      messenger.showSnackBar(SnackBar(content: Text('Lien envoyé à ${profile.email}.')));
    } on AuthException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _signOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Se déconnecter ?'),
        content: const Text('Vous devrez saisir à nouveau votre e-mail et votre mot de passe.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Se déconnecter'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    await _authService.signOut();
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil(AppRoutes.login, (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: StreamBuilder<UserProfile?>(
          stream: _profileStream,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              debugPrint('ProfileScreen: ${snapshot.error}');
              return const _StateWithBack(child: Text('Impossible de charger votre profil.'));
            }
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const _StateWithBack(child: CircularProgressIndicator());
            }
            final profile = snapshot.data;
            if (profile == null) {
              return _StateWithBack(child: _MissingProfile(onSignOut: _signOut));
            }

            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
                _TopBar(onEdit: () => _editProfile(profile)),
                const SizedBox(height: 24),
                _IdentityCard(profile: profile, onEdit: () => _editProfile(profile)),
                const SizedBox(height: 24),
                _PersonalInfoCard(profile: profile, onEdit: () => _editProfile(profile)),
                const SizedBox(height: 24),
                const Padding(
                  padding: EdgeInsets.only(left: 4, bottom: 12),
                  child: Text(
                    'Activité & Gestion',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, letterSpacing: -0.3),
                  ),
                ),
                _Card(
                  child: Column(
                    children: [
                      // Module 4 : ajouter ici « Mes annonces perdus / trouvés ».
                      _MenuTile(
                        icon: Icons.campaign_outlined,
                        iconBackground: const Color(0xFFD9F5F1),
                        iconColor: AppColors.teal,
                        title: 'Mes annonces',
                        subtitle: "Gérer les fiches d'adoption et leurs candidatures",
                        onTap: () => Navigator.of(context).pushNamed(AppRoutes.myListings),
                      ),
                      _MenuTile(
                        icon: Icons.assignment_ind_outlined,
                        iconBackground: const Color(0xFFFFF0EB),
                        iconColor: const Color(0xFF8C4E38),
                        title: 'Mes candidatures',
                        subtitle: "Suivi de vos demandes d'adoption",
                        onTap: () => Navigator.of(context).pushNamed(AppRoutes.myApplications),
                      ),
                      _MenuTile(
                        icon: Icons.favorite_border,
                        iconBackground: const Color(0xFFFFF0EB),
                        iconColor: AppColors.coralText,
                        title: 'Mes favoris',
                        subtitle: 'Les animaux que vous avez enregistrés',
                        onTap: () => Navigator.of(context).pushNamed(AppRoutes.adoptionFavorites),
                      ),
                      StreamBuilder<int>(
                        stream: _unreadStream,
                        builder: (context, snap) => _MenuTile(
                          icon: Icons.notifications_active_outlined,
                          iconBackground: const Color(0xFFE6EEFF),
                          iconColor: const Color(0xFF3E4947),
                          title: 'Notifications',
                          subtitle: 'Alertes, rappels et messages communautaires',
                          showDot: (snap.data ?? 0) > 0,
                          onTap: () => Navigator.of(context).pushNamed(AppRoutes.notifications),
                        ),
                      ),
                      _MenuTile(
                        icon: Icons.lock_reset,
                        iconBackground: const Color(0xFFE6EEFF),
                        iconColor: const Color(0xFF3E4947),
                        title: 'Sécurité du compte',
                        subtitle: 'Changer le mot de passe',
                        onTap: () => _changePassword(profile),
                      ),
                      _MenuTile(
                        icon: Icons.logout,
                        iconBackground: const Color(0xFFFFDAD6),
                        iconColor: AppColors.error,
                        title: 'Se déconnecter',
                        subtitle: 'Fermer votre session sur cet appareil',
                        destructive: true,
                        onTap: _signOut,
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
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
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: Color(0x0F0F172A), blurRadius: 3, offset: Offset(0, 1))],
      ),
      child: child,
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.onEdit});

  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _RoundIconButton(
          icon: Icons.arrow_back,
          tooltip: 'Retour',
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Mon Profil',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, letterSpacing: -0.4),
              ),
              Text(
                'Gérez vos coordonnées et préférences',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
        _RoundIconButton(icon: Icons.settings_outlined, tooltip: 'Modifier le profil', onPressed: onEdit),
      ],
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({required this.icon, required this.tooltip, required this.onPressed});

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      tooltip: tooltip,
      style: IconButton.styleFrom(
        backgroundColor: const Color(0xFFEFF4FF),
        foregroundColor: AppColors.textPrimary,
        fixedSize: const Size(44, 44),
      ),
      icon: Icon(icon, size: 20),
    );
  }
}

class _IdentityCard extends StatelessWidget {
  const _IdentityCard({required this.profile, required this.onEdit});

  final UserProfile profile;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return _Card(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          UserAvatar(initials: profile.initials, radius: 56, online: true),
          const SizedBox(height: 16),
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 6,
            children: [
              Text(
                profile.fullName,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600, letterSpacing: -0.3),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF9CF2E8),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.pets, size: 13, color: Color(0xFF00201D)),
                    const SizedBox(width: 4),
                    Text(
                      profile.role.label,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Color(0xFF00201D)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _IconLine(icon: Icons.location_on_outlined, text: profile.city),
          const SizedBox(height: 4),
          _IconLine(icon: Icons.mail_outline, text: profile.email),
          const SizedBox(height: 16),
          FilledButton.tonalIcon(
            onPressed: onEdit,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFEFF4FF),
              foregroundColor: const Color(0xFF005C55),
              minimumSize: const Size(0, 44),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            icon: const Icon(Icons.edit_outlined, size: 18),
            label: const Text('Modifier le profil'),
          ),
        ],
      ),
    );
  }
}

class _IconLine extends StatelessWidget {
  const _IconLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 16, color: AppColors.teal),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            text,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13, color: Color(0xFF3E4947)),
          ),
        ),
      ],
    );
  }
}

class _PersonalInfoCard extends StatelessWidget {
  const _PersonalInfoCard({required this.profile, required this.onEdit});

  final UserProfile profile;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return _Card(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.badge_outlined, size: 22, color: AppColors.teal),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Informations personnelles',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, letterSpacing: -0.2),
                ),
              ),
              TextButton(
                onPressed: onEdit,
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF005C55),
                  textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
                child: const Text('Modifier'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _InfoField(label: 'Nom complet', value: profile.fullName, icon: Icons.verified_user_outlined),
          _InfoField(label: 'Adresse e-mail', value: profile.email, icon: Icons.check_circle_outline),
          _InfoField(
            label: 'Numéro de téléphone',
            value: profile.phone ?? 'Non renseigné',
            icon: Icons.smartphone,
            muted: profile.phone == null,
          ),
          _InfoField(label: 'Ville de résidence', value: profile.city, icon: Icons.location_on_outlined),
        ],
      ),
    );
  }
}

class _InfoField extends StatelessWidget {
  const _InfoField({required this.label, required this.value, required this.icon, this.muted = false});

  final String label;
  final String value;
  final IconData icon;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(color: const Color(0xFFEFF4FF), borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF3E4947))),
                const SizedBox(height: 2),
                Text(
                  value,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15,
                    color: muted ? AppColors.textSecondary : AppColors.textPrimary,
                    fontStyle: muted ? FontStyle.italic : FontStyle.normal,
                  ),
                ),
              ],
            ),
          ),
          Icon(icon, size: 20, color: const Color(0xFF3E4947)),
        ],
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({
    required this.icon,
    required this.iconBackground,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.showDot = false,
    this.destructive = false,
  });

  final IconData icon;
  final Color iconBackground;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool showDot;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final titleColor = destructive ? const Color(0xFFBA1A1A) : AppColors.textPrimary;
    final subtitleColor = destructive ? const Color(0xFFBA1A1A) : AppColors.textSecondary;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(color: iconBackground, borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, size: 24, color: iconColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: titleColor)),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 13, color: subtitleColor),
                  ),
                ],
              ),
            ),
            if (showDot) ...[
              const SizedBox(width: 8),
              const CircleAvatar(radius: 5, backgroundColor: AppColors.teal),
            ],
            const SizedBox(width: 8),
            Icon(Icons.chevron_right, color: destructive ? const Color(0xFFBA1A1A) : const Color(0xFF3E4947)),
          ],
        ),
      ),
    );
  }
}

/// Chargement, erreur ou profil absent : garde le bouton retour visible.
class _StateWithBack extends StatelessWidget {
  const _StateWithBack({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Align(
            alignment: Alignment.centerLeft,
            child: _RoundIconButton(
              icon: Icons.arrow_back,
              tooltip: 'Retour',
              onPressed: () => Navigator.of(context).maybePop(),
            ),
          ),
        ),
        Expanded(child: Center(child: child)),
      ],
    );
  }
}

/// Compte Firebase sans document `users/{uid}` (ex. créé à la main dans la console).
class _MissingProfile extends StatelessWidget {
  const _MissingProfile({required this.onSignOut});

  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.person_off_outlined, size: 48, color: AppColors.teal),
            const SizedBox(height: 12),
            const Text(
              'Profil introuvable',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            const Text(
              "Ce compte n'a pas de profil enregistré. Créez un compte depuis l'écran d'inscription.",
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 20),
            OutlinedButton(onPressed: onSignOut, child: const Text('Se déconnecter')),
          ],
        ),
      ),
    );
  }
}
