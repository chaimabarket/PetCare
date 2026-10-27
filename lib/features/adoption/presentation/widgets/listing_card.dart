import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../data/adoption_enums.dart';
import '../../data/adoption_listing.dart';
import 'adoption_widgets.dart';

/// Carte d'un animal dans le fil, les favoris et « Mes annonces ».
class ListingCard extends StatelessWidget {
  const ListingCard({
    super.key,
    required this.listing,
    required this.onTap,
    this.favorite = false,
    this.onFavorite,
  });

  static const badgeRowHeight = 24.0;

  /// Hauteur sous la photo carrée, pour `mainAxisExtent` des grilles.
  static const infoHeight = 134.0;

  final AdoptionListing listing;
  final VoidCallback onTap;
  final bool favorite;

  /// `null` masque le cœur (ex. l'annonceur sur sa propre annonce).
  final VoidCallback? onFavorite;

  @override
  Widget build(BuildContext context) {
    final faded = listing.status == ListingStatus.adopted || listing.status == ListingStatus.archived;

    return Opacity(
      opacity: faded ? 0.6 : 1,
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AspectRatio(
                aspectRatio: 1,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Hero(
                      tag: 'listing-${listing.id}',
                      child: PetPhoto(bytes: listing.cover, species: listing.species),
                    ),
                    if (onFavorite != null)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: _FavoriteButton(favorite: favorite, onTap: onFavorite!),
                      ),
                    if (listing.status == ListingStatus.reserved)
                      const Positioned(
                        left: 8,
                        bottom: 8,
                        child: _Ribbon(icon: Icons.schedule, label: 'Réservé', color: AdoptionColors.warningText),
                      )
                    else if (listing.isUrgent)
                      const Positioned(
                        left: 8,
                        bottom: 8,
                        child: _Ribbon(icon: Icons.pets, label: 'ADOPTE-MOI', color: AppColors.coralText),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${listing.name} • ${listing.ageLabel}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Icon(Icons.location_on_outlined, size: 14, color: AppColors.textSecondary),
                        const SizedBox(width: 2),
                        Expanded(
                          child: Text(
                            listing.city,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Une seule ligne de badges pour garder des cartes de même hauteur dans la grille.
                    SizedBox(
                      height: ListingCard.badgeRowHeight,
                      child: ClipRect(
                        child: Wrap(
                          spacing: 4,
                          children: [for (final b in listing.badges.take(3)) BadgeChip(badge: b, compact: true)],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        StatusPill.listing(listing.status),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            listing.publisherName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.teal),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FavoriteButton extends StatelessWidget {
  const _FavoriteButton({required this.favorite, required this.onTap});

  final bool favorite;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface.withValues(alpha: 0.92),
      shape: const CircleBorder(),
      child: IconButton(
        tooltip: favorite ? 'Retirer des favoris' : 'Ajouter aux favoris',
        visualDensity: VisualDensity.compact,
        onPressed: onTap,
        icon: Icon(
          favorite ? Icons.favorite : Icons.favorite_border,
          size: 20,
          color: AppColors.coralText,
        ),
      ),
    );
  }
}

class _Ribbon extends StatelessWidget {
  const _Ribbon({required this.icon, required this.label, required this.color});

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color == AppColors.coralText ? AdoptionColors.peach : AdoptionColors.warningBg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color, letterSpacing: 0.3)),
        ],
      ),
    );
  }
}
