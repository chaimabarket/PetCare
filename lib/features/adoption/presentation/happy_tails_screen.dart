import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../core/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../data/happy_tail.dart';
import '../data/happy_tail_repository.dart';
import 'widgets/adoption_widgets.dart';
import 'widgets/happy_tail_card.dart';
import 'widgets/report_dialog.dart';

/// Les belles histoires d'adoption (maquette « Happy Tails ») : likes seulement, pas de commentaires.
class HappyTailsScreen extends StatefulWidget {
  const HappyTailsScreen({super.key});

  @override
  State<HappyTailsScreen> createState() => _HappyTailsScreenState();
}

class _HappyTailsScreenState extends State<HappyTailsScreen> {
  final _repository = HappyTailRepository();
  final _user = FirebaseAuth.instance.currentUser;
  late final _tailsStream = _repository.watchAll();
  late final _likedStream = _user == null ? null : _repository.watchLikedIds(_user.uid);
  late final _adoptedCount = _repository.countAdopted().catchError((Object _) => 0);

  Future<void> _like(HappyTail tail, bool liked) async {
    final user = _user;
    if (user == null) {
      await askToSignIn(context, 'Connectez-vous pour aimer les histoires de la communauté.');
      return;
    }
    try {
      await _repository.setLiked(uid: user.uid, tailId: tail.id, liked: liked);
    } catch (_) {
      if (mounted) showAdoptionMessage(context, 'Impossible d\'enregistrer votre coup de cœur.');
    }
  }

  /// Le partage se fait depuis « Mes candidatures », sur la candidature adoptée.
  void _share() {
    if (_user == null) {
      askToSignIn(context, 'Connectez-vous pour partager l\'histoire de votre compagnon.');
      return;
    }
    Navigator.of(context).pushNamed(AppRoutes.myApplications);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        titleSpacing: 0,
        title: const Text('Happy Tails', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
      ),
      body: StreamBuilder<List<HappyTail>>(
        stream: _tailsStream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            debugPrint('HappyTailsScreen: ${snapshot.error}');
            return const EmptyState(icon: Icons.cloud_off, title: 'Histoires indisponibles', text: 'Réessayez plus tard.');
          }
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final tails = snapshot.data!;

          return StreamBuilder<Set<String>>(
            stream: _likedStream,
            builder: (context, likedSnap) {
              final liked = likedSnap.data ?? const <String>{};
              return LayoutBuilder(
                builder: (context, constraints) {
                  final columns = (constraints.maxWidth / 420).floor().clamp(1, 3);
                  final cards = [
                    for (final t in tails)
                      HappyTailCard(
                        authorName: t.authorName,
                        animalName: t.animalName,
                        species: t.species,
                        breed: t.breed,
                        publisherName: t.publisherName,
                        title: t.title,
                        story: t.story,
                        likeCount: t.likeCount,
                        liked: liked.contains(t.id),
                        before: t.before,
                        after: t.after,
                        onLike: () => _like(t, !liked.contains(t.id)),
                        onReport: _user == null || _user.uid == t.authorId
                            ? null
                            : () => showReportDialog(context, reporterId: _user.uid, targetType: 'happyTail', targetId: t.id),
                      ),
                  ];
                  return ListView(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                    children: [
                      FutureBuilder<int>(future: _adoptedCount, builder: (context, s) => _Header(adopted: s.data)),
                      const SizedBox(height: 16),
                      _TellCard(onTap: _share),
                      const SizedBox(height: 20),
                      if (tails.isEmpty)
                        const EmptyState(
                          icon: Icons.auto_stories_outlined,
                          title: 'Les premières histoires arrivent',
                          text: 'Après une adoption, l\'adoptant peut partager l\'évolution de son compagnon ici.',
                        )
                      else
                        for (var i = 0; i < cards.length; i += columns)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                for (var j = i; j < i + columns; j++) ...[
                                  if (j > i) const SizedBox(width: 16),
                                  Expanded(child: j < cards.length ? cards[j] : const SizedBox()),
                                ],
                              ],
                            ),
                          ),
                      const SizedBox(height: 8),
                      _ShareCta(onTap: _share),
                    ],
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.adopted});

  final int? adopted;

  @override
  Widget build(BuildContext context) {
    final n = adopted ?? 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (n > 0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(color: AdoptionColors.blueSurface, borderRadius: BorderRadius.circular(999)),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.auto_awesome, size: 14, color: AdoptionColors.tealDeep),
                const SizedBox(width: 6),
                Text(
                  '$n animal${n > 1 ? 'aux' : ''} adopté${n > 1 ? 's' : ''} grâce à la communauté',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AdoptionColors.tealDeep),
                ),
              ],
            ),
          ),
        const SizedBox(height: 12),
        const Text(
          "Les belles histoires d'adoption",
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, letterSpacing: -0.5, height: 1.2),
        ),
        const SizedBox(height: 8),
        const Text(
          'Chaque rencontre est une seconde chance. Découvrez les métamorphoses et le bonheur partagé '
          'de nos petits protégés dans leur nouveau foyer.',
          style: TextStyle(fontSize: 14, height: 1.5, color: AdoptionColors.textMuted),
        ),
      ],
    );
  }
}

class _TellCard extends StatelessWidget {
  const _TellCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AdoptionColors.blueSurface, borderRadius: BorderRadius.circular(16)),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 22,
            backgroundColor: AdoptionColors.peach,
            child: Icon(Icons.volunteer_activism_outlined, color: AdoptionColors.brown),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Vous avez adopté ?', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                Text('Inspirez la communauté', style: TextStyle(fontSize: 12, color: AdoptionColors.textMuted)),
              ],
            ),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.coral,
              foregroundColor: AdoptionColors.brown,
              minimumSize: const Size(0, 36),
              padding: const EdgeInsets.symmetric(horizontal: 14),
            ),
            onPressed: onTap,
            iconAlignment: IconAlignment.end,
            icon: const Icon(Icons.chevron_right, size: 18),
            label: const Text('Raconter'),
          ),
        ],
      ),
    );
  }
}

class _ShareCta extends StatelessWidget {
  const _ShareCta({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: AdoptionColors.blueSurface, borderRadius: BorderRadius.circular(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(color: AppColors.coral, borderRadius: BorderRadius.circular(16)),
              child: const Icon(Icons.pets, color: AdoptionColors.brown, size: 28),
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'Vous aussi, vous avez adopté via PetCare ?',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          const Text(
            "Votre témoignage redonne espoir à des centaines d'animaux en attente d'une famille aimante.",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, height: 1.4, color: AdoptionColors.textMuted),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: AppColors.coral, foregroundColor: AdoptionColors.brown),
            onPressed: onTap,
            icon: const Icon(Icons.favorite_border),
            label: const Text('Partager votre histoire'),
          ),
        ],
      ),
    );
  }
}
