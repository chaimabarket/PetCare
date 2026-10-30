import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../core/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../data/adoption_enums.dart';
import '../data/adoption_listing.dart';
import '../data/adoption_repository.dart';
import 'widgets/adoption_widgets.dart';

/// Coups de cœur enregistrés depuis le fil (maquette « Mes favoris »).
class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  final _repository = AdoptionRepository();
  final _uid = FirebaseAuth.instance.currentUser!.uid;
  late final _idsStream = _repository.watchFavoriteIds(_uid);

  // Les annonces sont relues seulement quand la liste des favoris change.
  Set<String>? _loadedIds;
  Future<List<AdoptionListing>>? _listings;

  Future<List<AdoptionListing>> _listingsFor(Set<String> ids) {
    if (_loadedIds == null || !_sameIds(_loadedIds!, ids)) {
      _loadedIds = ids;
      _listings = _repository.fetchListings(ids);
    }
    return _listings!;
  }

  static bool _sameIds(Set<String> a, Set<String> b) => a.length == b.length && a.containsAll(b);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        titleSpacing: 0,
        toolbarHeight: 72,
        title: StreamBuilder<Set<String>>(
          stream: _idsStream,
          builder: (context, snap) {
            final n = snap.data?.length ?? 0;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Mes coups de cœur',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, letterSpacing: -0.4),
                ),
                Text(
                  '$n animal${n > 1 ? 'aux' : ''} sauvegardé${n > 1 ? 's' : ''}',
                  style: const TextStyle(fontSize: 13, color: AdoptionColors.textMuted),
                ),
              ],
            );
          },
        ),
      ),
      body: StreamBuilder<Set<String>>(
        stream: _idsStream,
        builder: (context, idsSnap) {
          if (!idsSnap.hasData) return const Center(child: CircularProgressIndicator());
          final ids = idsSnap.data!;
          if (ids.isEmpty) {
            return EmptyState(
              icon: Icons.favorite_border,
              title: 'Aucun favori pour l\'instant',
              text: 'Touchez le cœur d\'une annonce pour la retrouver ici.',
              action: FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Découvrir les animaux'),
              ),
            );
          }
          return FutureBuilder<List<AdoptionListing>>(
            future: _listingsFor(ids),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
              // Les annonces archivées ne sont plus lisibles : elles disparaissent d'elles-mêmes.
              final listings = snapshot.data!.where((l) => ids.contains(l.id)).toList();
              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                children: [
                  const TipBanner(
                    icon: Icons.notifications_active_outlined,
                    text: 'Le statut de vos coups de cœur est mis à jour en direct : disponible, réservé ou adopté.',
                  ),
                  const SizedBox(height: 16),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      const spacing = 12.0;
                      final columns = (constraints.maxWidth / 220).floor().clamp(2, 5);
                      final width = (constraints.maxWidth - spacing * (columns - 1)) / columns;
                      return GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: listings.length,
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: columns,
                          crossAxisSpacing: spacing,
                          mainAxisSpacing: spacing,
                          mainAxisExtent: width + _FavoriteCard.infoHeight,
                        ),
                        itemBuilder: (context, i) => _FavoriteCard(
                          listing: listings[i],
                          onUnfavorite: () => _repository.setFavorite(_uid, listings[i].id, false),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 20),
                  const TipBanner(
                    icon: Icons.diversity_1_outlined,
                    title: "Un doute sur l'accueil ?",
                    text:
                        'Envoyez votre candidature : le refuge ou le propriétaire vous accompagne pour organiser '
                        'une première rencontre sans engagement.',
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _FavoriteCard extends StatelessWidget {
  const _FavoriteCard({required this.listing, required this.onUnfavorite});

  /// Hauteur sous la photo carrée.
  static const infoHeight = 128.0;

  final AdoptionListing listing;
  final VoidCallback onUnfavorite;

  @override
  Widget build(BuildContext context) {
    final l = listing;
    final adopted = l.status == ListingStatus.adopted;
    final navigator = Navigator.of(context);

    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => navigator.pushNamed(AppRoutes.adoptionListing, arguments: l.id),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AspectRatio(
              aspectRatio: 1,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ColorFiltered(
                    // Animal adopté : photo désaturée comme dans la maquette.
                    colorFilter: adopted
                        ? const ColorFilter.matrix([
                            0.33,
                            0.33,
                            0.33,
                            0,
                            0,
                            0.33,
                            0.33,
                            0.33,
                            0,
                            0,
                            0.33,
                            0.33,
                            0.33,
                            0,
                            0,
                            0,
                            0,
                            0,
                            0.7,
                            0,
                          ])
                        : const ColorFilter.mode(Colors.transparent, BlendMode.dst),
                    child: PetPhoto(bytes: l.cover, species: l.species),
                  ),
                  Positioned(
                    left: 8,
                    top: 8,
                    child: adopted
                        ? const StatusPill(label: 'Adoptée', tone: PillTone.inactive, icon: Icons.check_circle_outline)
                        : StatusPill.listing(l.status),
                  ),
                  Positioned(
                    right: 6,
                    top: 6,
                    child: IconButton.filled(
                      tooltip: 'Retirer des favoris',
                      style: IconButton.styleFrom(backgroundColor: adopted ? AppColors.surface : AppColors.coral),
                      onPressed: onUnfavorite,
                      icon: Icon(
                        adopted ? Icons.favorite_border : Icons.favorite,
                        size: 20,
                        color: adopted ? AppColors.coralText : AdoptionColors.brown,
                      ),
                    ),
                  ),
                  if (adopted)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: Container(
                        color: Colors.black45,
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: const Text(
                          'Heureuse adoption ❤️',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            l.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w700,
                              color: adopted ? AppColors.textSecondary : AppColors.textPrimary,
                              decoration: adopted ? TextDecoration.lineThrough : null,
                            ),
                          ),
                        ),
                        Text(
                          l.sex.symbol,
                          style: TextStyle(
                            fontSize: 16,
                            color: l.sex == Sex.male ? AdoptionColors.tealDeep : AdoptionColors.brown,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      '${l.breed.isEmpty ? l.species.label : l.breed} • ${l.ageLabel}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                    ),
                    const Spacer(),
                    if (adopted) ...[
                      Text(
                        '${l.name} a trouvé sa famille pour la vie.',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 4),
                      SizedBox(
                        height: 30,
                        child: FilledButton(
                          style: softButtonStyle().copyWith(
                            minimumSize: const WidgetStatePropertyAll(Size.fromHeight(30)),
                            padding: const WidgetStatePropertyAll(EdgeInsets.zero),
                            foregroundColor: const WidgetStatePropertyAll(AdoptionColors.tealDeep),
                          ),
                          onPressed: () => navigator.pushNamed(AppRoutes.happyTails),
                          child: const Text('Voir son histoire', style: TextStyle(fontSize: 13)),
                        ),
                      ),
                    ] else
                      Row(
                        children: [
                          const Icon(Icons.location_on_outlined, size: 15, color: AppColors.textSecondary),
                          const SizedBox(width: 2),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  l.publisherName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 13),
                                ),
                                Text(
                                  l.city,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 12, color: AdoptionColors.tealDeep),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
