import 'package:flutter/material.dart';

import '../../data/adoption_listing.dart';
import 'listing_card.dart';

/// Grille de cartes : 2 colonnes sur téléphone, plus sur grand écran.
class ListingGrid extends StatelessWidget {
  const ListingGrid({
    super.key,
    required this.listings,
    required this.onOpen,
    this.favoriteIds = const {},
    this.onFavorite,
  });

  final List<AdoptionListing> listings;
  final ValueChanged<AdoptionListing> onOpen;
  final Set<String> favoriteIds;

  /// `null` masque le cœur sur toutes les cartes.
  final void Function(AdoptionListing listing, bool favorite)? onFavorite;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 12.0;
        final columns = (constraints.maxWidth / 220).floor().clamp(2, 5);
        final cardWidth = (constraints.maxWidth - spacing * (columns - 1)) / columns;

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          itemCount: listings.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: spacing,
            mainAxisSpacing: spacing,
            mainAxisExtent: cardWidth + ListingCard.infoHeight,
          ),
          itemBuilder: (context, i) {
            final listing = listings[i];
            final favorite = favoriteIds.contains(listing.id);
            return ListingCard(
              listing: listing,
              favorite: favorite,
              onTap: () => onOpen(listing),
              onFavorite: onFavorite == null ? null : () => onFavorite!(listing, !favorite),
            );
          },
        );
      },
    );
  }
}
