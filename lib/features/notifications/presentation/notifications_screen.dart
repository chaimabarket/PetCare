import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../core/api/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/relative_time.dart';
import '../data/app_notification.dart';
import '../data/notification_service.dart';

/// Liste des notifications (maquette Stitch « Notifications »).
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final _service = NotificationService();
  final _uid = FirebaseAuth.instance.currentUser!.uid;

  /// Filtre actif ; `null` = « Toutes ».
  NotificationCategory? _filter;

  Future<void> _markAllAsRead() async {
    try {
      await _service.markAllAsRead(_uid);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Impossible de mettre à jour les notifications.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        titleSpacing: 0,
        title: const Text(
          'Notifications',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, letterSpacing: -0.3),
        ),
      ),
      body: StreamBuilder<List<AppNotification>>(
        stream: _service.watch(_uid),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            debugPrint('NotificationsScreen: ${snapshot.error}');
            final denied = (snapshot.error is FirebaseException &&
                    (snapshot.error! as FirebaseException).code == 'permission-denied') ||
                (snapshot.error is ApiException && (snapshot.error! as ApiException).statusCode == 403);
            return _Message(
              icon: denied ? Icons.lock_outline : Icons.cloud_off,
              title: 'Notifications indisponibles',
              text: denied
                  ? "Vous n'avez pas accès à ces informations pour le moment."
                  : 'Vérifiez votre connexion puis réessayez.',
            );
          }
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          final all = snapshot.data!;
          final unreadCount = all.where((n) => !n.read).length;
          final visible = _filter == null ? all : all.where((n) => n.category == _filter).toList();
          final today = visible.where((n) => isToday(n.createdAt)).toList();
          final earlier = visible.where((n) => !isToday(n.createdAt)).toList();

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            children: [
              _Header(unreadCount: unreadCount, onMarkAllAsRead: unreadCount > 0 ? _markAllAsRead : null),
              const SizedBox(height: 16),
              _FilterChips(selected: _filter, onSelected: (c) => setState(() => _filter = c)),
              const SizedBox(height: 24),
              if (visible.isEmpty)
                _Message(
                  icon: Icons.notifications_none,
                  title: _filter == null ? 'Aucune notification' : 'Aucune notification dans cette catégorie',
                  text: 'Les rappels, réponses et alertes de la communauté apparaîtront ici.',
                ),
              if (today.isNotEmpty) ...[
                _SectionTitle(title: "Aujourd'hui", trailing: '${today.length} récente${today.length > 1 ? 's' : ''}'),
                for (final n in today) _NotificationCard(notification: n, onTap: () => _open(n)),
              ],
              if (earlier.isNotEmpty) ...[
                if (today.isNotEmpty) const SizedBox(height: 16),
                const _SectionTitle(title: 'Plus tôt'),
                for (final n in earlier) _NotificationCard(notification: n, onTap: () => _open(n)),
              ],
              if (all.isNotEmpty && unreadCount == 0) ...[
                const SizedBox(height: 24),
                const _UpToDateCard(),
              ],
            ],
          );
        },
      ),
    );
  }

  void _open(AppNotification notification) {
    if (!notification.read) _service.markAsRead(_uid, notification.id);
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.unreadCount, required this.onMarkAllAsRead});

  final int unreadCount;
  final VoidCallback? onMarkAllAsRead;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (unreadCount > 0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: AppColors.coral, borderRadius: BorderRadius.circular(999)),
            child: Text(
              '$unreadCount nouvelle${unreadCount > 1 ? 's' : ''}',
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
            ),
          ),
        const Spacer(),
        TextButton.icon(
          onPressed: onMarkAllAsRead,
          style: TextButton.styleFrom(
            foregroundColor: const Color(0xFF005C55),
            textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
          icon: const Icon(Icons.done_all, size: 18),
          label: const Text('Tout marquer comme lu'),
        ),
      ],
    );
  }
}

class _FilterChips extends StatelessWidget {
  const _FilterChips({required this.selected, required this.onSelected});

  final NotificationCategory? selected;
  final ValueChanged<NotificationCategory?> onSelected;

  static const _filters = <NotificationCategory?>[
    null,
    NotificationCategory.health,
    NotificationCategory.appointment,
    NotificationCategory.adoption,
    NotificationCategory.community,
  ];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      clipBehavior: Clip.none,
      child: Row(
        children: [
          for (final filter in _filters) ...[
            _Chip(
              label: filter?.label ?? 'Toutes',
              selected: filter == selected,
              onTap: () => onSelected(filter),
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? const Color(0xFF005C55) : AppColors.surface,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 18),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: selected ? const Color(0xFF005C55) : AppColors.border),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: selected ? Colors.white : AppColors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, this.trailing});

  final String title;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
          const Spacer(),
          if (trailing != null)
            Text(trailing!, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({required this.notification, required this.onTap});

  final AppNotification notification;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final style = _CategoryStyle.of(notification.category);
    final unread = !notification.read;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        elevation: 0,
        shadowColor: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Container(
            decoration: BoxDecoration(
              border: Border(
                left: BorderSide(color: unread ? const Color(0xFF005C55) : Colors.transparent, width: 4),
              ),
            ),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: style.background,
                  child: Icon(style.icon, size: 22, color: style.foreground),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              notification.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            formatRelativeTime(notification.createdAt),
                            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        notification.body,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 14, height: 1.45, color: Color(0xFF3E4947)),
                      ),
                    ],
                  ),
                ),
                if (unread) ...[
                  const SizedBox(width: 12),
                  const Padding(
                    padding: EdgeInsets.only(top: 22),
                    child: CircleAvatar(radius: 5, backgroundColor: Color(0xFF005C55)),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Icône et couleurs associées à chaque catégorie.
class _CategoryStyle {
  const _CategoryStyle(this.icon, this.background, this.foreground);

  final IconData icon;
  final Color background;
  final Color foreground;

  static const _blue = Color(0xFFEFF4FF);
  static const _peach = Color(0xFFFFDBCF);
  static const _peachLight = Color(0xFFFFF0EB);

  static _CategoryStyle of(NotificationCategory category) => switch (category) {
        NotificationCategory.health => const _CategoryStyle(Icons.vaccines_outlined, _blue, Color(0xFF005C55)),
        NotificationCategory.appointment =>
          const _CategoryStyle(Icons.calendar_month_outlined, _peachLight, Color(0xFF8C4E38)),
        NotificationCategory.adoption => const _CategoryStyle(Icons.favorite_border, _peach, Color(0xFF8C4E38)),
        NotificationCategory.community => const _CategoryStyle(Icons.campaign_outlined, _blue, Color(0xFF005C55)),
        NotificationCategory.message => const _CategoryStyle(Icons.chat_bubble_outline, _blue, Color(0xFF005C55)),
      };
}

class _UpToDateCard extends StatelessWidget {
  const _UpToDateCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: const Color(0xFFEFF4FF), borderRadius: BorderRadius.circular(16)),
      child: const Column(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: AppColors.surface,
            child: Icon(Icons.check_circle_outline, color: Color(0xFF005C55)),
          ),
          SizedBox(height: 16),
          Text(
            'Vous êtes à jour sur vos alertes importantes ✨',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
          SizedBox(height: 8),
          Text(
            'Nous surveillons le carnet de santé et les actualités de vos compagnons en continu.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, height: 1.4, color: Color(0xFF3E4947)),
          ),
        ],
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.icon, required this.title, required this.text});

  final IconData icon;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
      child: Column(
        children: [
          Icon(icon, size: 48, color: AppColors.teal),
          const SizedBox(height: 12),
          Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}
