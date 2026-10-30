import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../core/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/coming_soon_screen.dart';
import '../../community/presentation/community_screen.dart';
import '../../notifications/data/notification_service.dart';
import '../../profile/data/profile_repository.dart';
import '../../profile/data/user_profile.dart';
import '../../profile/presentation/widgets/user_avatar.dart';
import 'home_screen.dart';

/// Structure principale après connexion (ou en visiteur) : en-tête + 4 onglets du cahier des charges.
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;

  static const _tabs = [
    (label: 'Accueil', icon: Icons.home_outlined, activeIcon: Icons.home),
    (label: 'Mes animaux', icon: Icons.pets_outlined, activeIcon: Icons.pets),
    (label: 'Communauté', icon: Icons.volunteer_activism_outlined, activeIcon: Icons.volunteer_activism),
    (label: 'Services', icon: Icons.medical_services_outlined, activeIcon: Icons.medical_services),
  ];

  void _selectTab(int index) => setState(() => _index = index);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _Header(title: _tabs[_index].label),
      body: IndexedStack(
        index: _index,
        children: [
          HomeScreen(onOpenTab: _selectTab),
          // Module 1 (Profils des animaux) : remplacer par l'écran « Mes animaux ».
          const ComingSoonScreen(title: 'Mes animaux', embedded: true),
          // Modules 4 et 5 : écran « Communauté » (Adoption, Perdus & trouvés, Happy Tails).
          const CommunityScreen(),
          // Module 6 (Services) : remplacer par l'annuaire des prestataires.
          const ComingSoonScreen(title: 'Services', embedded: true),
        ],
      ),
      // Assistant IA, sur l'Accueil (maquette Stitch M1).
      floatingActionButton: _index == 0
          ? FloatingActionButton(
              tooltip: 'Assistant PetCare',
              onPressed: () => Navigator.of(context).pushNamed(AppRoutes.assistant),
              backgroundColor: AppColors.teal,
              foregroundColor: Colors.white,
              child: const Icon(Icons.chat_bubble_outline),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: _selectTab,
        backgroundColor: AppColors.surface,
        indicatorColor: AppColors.teal.withValues(alpha: 0.12),
        surfaceTintColor: Colors.transparent,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontSize: 12,
            fontWeight: states.contains(WidgetState.selected) ? FontWeight.w600 : FontWeight.w500,
            color: states.contains(WidgetState.selected) ? AppColors.teal : const Color(0xFF3E4947),
          ),
        ),
        destinations: [
          for (final tab in _tabs)
            NavigationDestination(
              icon: Icon(tab.icon, color: const Color(0xFF3E4947)),
              selectedIcon: Icon(tab.activeIcon, color: AppColors.teal),
              label: tab.label,
            ),
        ],
      ),
    );
  }
}

/// En-tête commun : logo, titre de l'onglet, cloche des notifications et avatar vers le profil.
class _Header extends StatelessWidget implements PreferredSizeWidget {
  const _Header({required this.title});

  final String title;

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return AppBar(
      toolbarHeight: 64,
      backgroundColor: AppColors.background,
      surfaceTintColor: Colors.transparent,
      automaticallyImplyLeading: false,
      titleSpacing: 16,
      title: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.teal.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.pets, color: AppColors.teal, size: 22),
          ),
          const SizedBox(width: 12),
          Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600, letterSpacing: -0.3)),
        ],
      ),
      actions: [
        if (user != null) _NotificationBell(uid: user.uid),
        Padding(
          padding: const EdgeInsets.only(right: 12, left: 4),
          child: user == null
              ? TextButton(
                  onPressed: () => Navigator.of(context).pushNamed(AppRoutes.login),
                  style: TextButton.styleFrom(foregroundColor: AppColors.teal),
                  child: const Text('Se connecter', style: TextStyle(fontWeight: FontWeight.w600)),
                )
              : _ProfileButton(uid: user.uid),
        ),
      ],
    );
  }
}

class _NotificationBell extends StatefulWidget {
  const _NotificationBell({required this.uid});

  final String uid;

  @override
  State<_NotificationBell> createState() => _NotificationBellState();
}

class _NotificationBellState extends State<_NotificationBell> {
  late final _unreadStream = NotificationService().watchUnreadCount(widget.uid);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<int>(
      stream: _unreadStream,
      builder: (context, snapshot) {
        final unread = snapshot.data ?? 0;
        return IconButton(
          tooltip: unread > 0 ? 'Notifications ($unread non lues)' : 'Notifications',
          onPressed: () => Navigator.of(context).pushNamed(AppRoutes.notifications),
          icon: Badge(
            isLabelVisible: unread > 0,
            backgroundColor: AppColors.coralText,
            smallSize: 9,
            child: const Icon(Icons.notifications_none, color: Color(0xFF3E4947)),
          ),
        );
      },
    );
  }
}

class _ProfileButton extends StatefulWidget {
  const _ProfileButton({required this.uid});

  final String uid;

  @override
  State<_ProfileButton> createState() => _ProfileButtonState();
}

class _ProfileButtonState extends State<_ProfileButton> {
  late final _profileStream = ProfileRepository().watch(widget.uid);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<UserProfile?>(
      stream: _profileStream,
      builder: (context, snapshot) {
        final initials = snapshot.data?.initials ?? '';
        return InkResponse(
          onTap: () => Navigator.of(context).pushNamed(AppRoutes.profile),
          radius: 24,
          child: Semantics(
            button: true,
            label: 'Mon profil',
            child: initials.isEmpty
                ? const CircleAvatar(
                    radius: 18,
                    backgroundColor: Color(0xFF005C55),
                    child: Icon(Icons.person_outline, color: Colors.white, size: 20),
                  )
                : UserAvatar(initials: initials, radius: 18),
          ),
        );
      },
    );
  }
}
