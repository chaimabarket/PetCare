import 'package:flutter/material.dart';

import '../../../core/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/coming_soon_screen.dart';
import '../../adoption/data/adoption_enums.dart';
import '../../adoption/data/adoption_listing.dart';
import '../../adoption/data/adoption_repository.dart';
import '../../adoption/presentation/widgets/adoption_widgets.dart';
import '../../adoption/presentation/widgets/listing_card.dart';

/// Onglet Communauté (maquette « Communauté ») : Adoption, Perdus & trouvés et Happy Tails.
///
/// Module 4 (Perdus & trouvés) : remplacer l'écran « Bientôt disponible » de la carte du milieu
/// et ajouter ses annonces récentes dans la rangée « Récemment ».
class CommunityScreen extends StatefulWidget {
  const CommunityScreen({super.key});

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen> {
  late final _listingsStream = AdoptionRepository().watchPublicListings();

  @override
  Widget build(BuildContext context) {
    final navigator = Navigator.of(context);

    return StreamBuilder<List<AdoptionListing>>(
      stream: _listingsStream,
      builder: (context, snapshot) {
        final listings = snapshot.data ?? const <AdoptionListing>[];
        final available = listings.where((l) => l.status == ListingStatus.available).length;

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            const Text(
              'Partagez, adoptez et entraidez-vous au quotidien avec bienveillance.',
              style: TextStyle(fontSize: 15, height: 1.4, color: AdoptionColors.textMuted),
            ),
            const SizedBox(height: 20),
            _HubCard(
              icon: Icons.volunteer_activism_outlined,
              accent: AdoptionColors.peach,
              iconColor: AdoptionColors.brown,
              title: 'Adoption',
              tagline: 'Trouvez votre futur compagnon de vie',
              text: 'Chiens, chats et petits animaux attendent une famille bienveillante.',
              badge: snapshot.hasData ? '$available compagnon${available > 1 ? 's' : ''}' : null,
              actionLabel: 'Découvrir',
              warm: true,
              onTap: () => navigator.pushNamed(AppRoutes.adoption),
            ),
            const SizedBox(height: 16),
            _HubCard(
              icon: Icons.track_changes,
              accent: AdoptionColors.mint,
              iconColor: AdoptionColors.tealDeep,
              title: 'Perdus & trouvés',
              tagline: 'Aidez un animal à rentrer chez lui',
              text: 'Signalez un animal égaré ou consultez les alertes de la communauté.',
              actionLabel: 'Voir les alertes',
              onTap: () => navigator.push(
                MaterialPageRoute<void>(builder: (_) => const ComingSoonScreen(title: 'Perdus & trouvés')),
              ),
            ),
            const SizedBox(height: 16),
            _HubCard(
              icon: Icons.sentiment_very_satisfied_outlined,
              accent: AdoptionColors.peachLight,
              iconColor: AdoptionColors.brown,
              title: 'Happy Tails',
              tagline: 'Les belles histoires de nouveaux départs',
              text: 'Des nouvelles émouvantes des animaux désormais comblés dans leur famille.',
              actionLabel: 'Lire les histoires',
              warm: true,
              onTap: () => navigator.pushNamed(AppRoutes.happyTails),
            ),
            if (listings.isNotEmpty) ...[
              const SizedBox(height: 28),
              Row(
                children: [
                  const Expanded(
                    child: Text('Récemment', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
                  ),
                  TextButton(onPressed: () => navigator.pushNamed(AppRoutes.adoption), child: const Text('Tout voir  ›')),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 180 + ListingCard.infoHeight,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: listings.length.clamp(0, 6),
                  separatorBuilder: (_, _) => const SizedBox(width: 12),
                  itemBuilder: (context, i) => SizedBox(
                    width: 180,
                    child: ListingCard(
                      listing: listings[i],
                      onTap: () => navigator.pushNamed(AppRoutes.adoptionListing, arguments: listings[i].id),
                    ),
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _HubCard extends StatelessWidget {
  const _HubCard({
    required this.icon,
    required this.accent,
    required this.iconColor,
    required this.title,
    required this.tagline,
    required this.text,
    required this.actionLabel,
    required this.onTap,
    this.badge,
    this.warm = false,
  });

  final IconData icon;
  final Color accent;
  final Color iconColor;
  final String title;
  final String tagline;
  final String text;
  final String actionLabel;
  final String? badge;
  final bool warm;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              height: 110,
              color: accent,
              alignment: Alignment.center,
              child: Stack(
                children: [
                  Center(child: Icon(icon, size: 56, color: iconColor)),
                  if (badge != null)
                    Positioned(
                      right: 12,
                      bottom: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(color: AdoptionColors.brown, borderRadius: BorderRadius.circular(999)),
                        child: Text(badge!, style: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w600)),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700)),
                  Text(
                    tagline,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: warm ? AdoptionColors.brown : AdoptionColors.tealDeep,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(text, style: const TextStyle(fontSize: 13, height: 1.4, color: AdoptionColors.textMuted)),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton.icon(
                      style: (warm ? warmButtonStyle() : FilledButton.styleFrom())
                          .copyWith(minimumSize: const WidgetStatePropertyAll(Size(0, 42))),
                      onPressed: onTap,
                      iconAlignment: IconAlignment.end,
                      icon: const Icon(Icons.arrow_forward, size: 18),
                      label: Text(actionLabel),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
