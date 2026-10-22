import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../core/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../auth/data/user_role.dart';
import '../../profile/data/profile_repository.dart';
import '../../profile/data/user_profile.dart';
import '../data/adoption_enums.dart';
import '../data/adoption_filters.dart';
import '../data/adoption_listing.dart';
import '../data/adoption_repository.dart';
import 'adoption_filters_sheet.dart';
import 'widgets/adoption_widgets.dart';
import 'widgets/listing_grid.dart';

/// Fil d'adoption (maquette « Adoption »).
class AdoptionFeedScreen extends StatefulWidget {
  const AdoptionFeedScreen({super.key});

  @override
  State<AdoptionFeedScreen> createState() => _AdoptionFeedScreenState();
}

class _AdoptionFeedScreenState extends State<AdoptionFeedScreen> {
  final _repository = AdoptionRepository();
  final _user = FirebaseAuth.instance.currentUser;
  late final _listingsStream = _repository.watchPublicListings();
  late final _favoritesStream = _user == null ? null : _repository.watchFavoriteIds(_user.uid);
  late final _profileStream = _user == null ? null : ProfileRepository().watch(_user.uid);
  final _searchController = TextEditingController();

  var _filters = const AdoptionFilters();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _openFilters(List<AdoptionListing> all) async {
    final result = await showAdoptionFiltersSheet(context, filters: _filters, listings: all);
    if (result != null) setState(() => _filters = result);
  }

  void _toggleSpecies(Species? species) {
    setState(() => _filters = _filters.copyWith(species: species == null ? {} : {species}));
  }

  Future<void> _setFavorite(AdoptionListing listing, bool favorite) async {
    final user = _user;
    if (user == null) {
      await askToSignIn(context, 'Créez un compte ou connectez-vous pour enregistrer vos coups de cœur.');
      return;
    }
    try {
      await _repository.setFavorite(user.uid, listing.id, favorite);
    } catch (_) {
      if (mounted) showAdoptionMessage(context, 'Impossible de mettre à jour vos favoris.');
    }
  }

  void _publish() {
    if (_user == null) {
      askToSignIn(context, 'Connectez-vous avec un compte propriétaire ou refuge pour publier une annonce.');
      return;
    }
    Navigator.of(context).pushNamed(AppRoutes.adoptionPublish);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<UserProfile?>(
      stream: _profileStream,
      builder: (context, profileSnap) {
        final role = profileSnap.data?.role;
        final canPublish = _user == null || (role != null && role != UserRole.provider);

        return Scaffold(
          appBar: AppBar(
            backgroundColor: AppColors.background,
            surfaceTintColor: Colors.transparent,
            titleSpacing: 0,
            title: const Text('Adoption', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            actions: [
              if (_user != null) ...[
                IconButton(
                  tooltip: 'Mes favoris',
                  onPressed: () => Navigator.of(context).pushNamed(AppRoutes.adoptionFavorites),
                  icon: const Icon(Icons.favorite_border, color: AppColors.coralText),
                ),
                IconButton(
                  tooltip: 'Mes candidatures',
                  onPressed: () => Navigator.of(context).pushNamed(AppRoutes.myApplications),
                  icon: const Icon(Icons.assignment_ind_outlined),
                ),
                if (canPublish)
                  IconButton(
                    tooltip: 'Mes annonces',
                    onPressed: () => Navigator.of(context).pushNamed(AppRoutes.myListings),
                    icon: const Icon(Icons.campaign_outlined),
                  ),
              ],
              const SizedBox(width: 4),
            ],
          ),
          floatingActionButton: canPublish
              ? FloatingActionButton.extended(
                  onPressed: _publish,
                  backgroundColor: AdoptionColors.brown,
                  foregroundColor: Colors.white,
                  icon: const Icon(Icons.add),
                  label: const Text('Publier', style: TextStyle(fontWeight: FontWeight.w600)),
                )
              : null,
          body: StreamBuilder<List<AdoptionListing>>(
            stream: _listingsStream,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                debugPrint('AdoptionFeedScreen: ${snapshot.error}');
                return const EmptyState(
                  icon: Icons.cloud_off,
                  title: 'Annonces indisponibles',
                  text: 'Vérifiez votre connexion puis réessayez.',
                );
              }
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

              final all = snapshot.data!;
              final visible = _filters.apply(all);
              final availableCount = all.where((l) => l.status == ListingStatus.available).length;

              return StreamBuilder<Set<String>>(
                stream: _favoritesStream,
                builder: (context, favSnap) => ListView(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
                  children: [
                    _Header(availableCount: availableCount),
                    const SizedBox(height: 16),
                    _SearchRow(
                      controller: _searchController,
                      activeFilters: _filters.activeCount,
                      onChanged: (q) => setState(() => _filters = _filters.copyWith(query: q)),
                      onFilters: () => _openFilters(all),
                    ),
                    const SizedBox(height: 12),
                    _SpeciesChips(selected: _filters.species, onSelected: _toggleSpecies),
                    const SizedBox(height: 16),
                    if (visible.isEmpty)
                      EmptyState(
                        icon: Icons.search_off,
                        title: all.isEmpty ? 'Aucune annonce pour le moment' : 'Aucun animal ne correspond',
                        text: all.isEmpty
                            ? 'Les refuges et propriétaires publieront bientôt leurs compagnons à adopter.'
                            : 'Essayez d\'élargir vos filtres ou votre recherche.',
                        action: all.isEmpty
                            ? null
                            : OutlinedButton(
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _filters = const AdoptionFilters());
                                },
                                child: const Text('Réinitialiser les filtres'),
                              ),
                      )
                    else
                      ListingGrid(
                        listings: visible,
                        favoriteIds: favSnap.data ?? const {},
                        onOpen: (l) => Navigator.of(context).pushNamed(AppRoutes.adoptionListing, arguments: l.id),
                        onFavorite: _setFavorite,
                      ),
                    const SizedBox(height: 20),
                    const _TrustBanner(),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.availableCount});

  final int availableCount;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Adoption',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, letterSpacing: -0.5),
              ),
            ),
            StatusPill(
              label: '$availableCount protégé${availableCount > 1 ? 's' : ''}',
              tone: PillTone.teal,
              dot: false,
            ),
          ],
        ),
        const SizedBox(height: 4),
        const Text(
          "Trouvez votre compagnon pour la vie • En attente d'un foyer chaleureux",
          style: TextStyle(fontSize: 14, height: 1.4, color: AdoptionColors.textMuted),
        ),
      ],
    );
  }
}

class _SearchRow extends StatelessWidget {
  const _SearchRow({
    required this.controller,
    required this.activeFilters,
    required this.onChanged,
    required this.onFilters,
  });

  final TextEditingController controller;
  final int activeFilters;
  final ValueChanged<String> onChanged;
  final VoidCallback onFilters;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            onChanged: onChanged,
            textInputAction: TextInputAction.search,
            decoration: const InputDecoration(
              hintText: 'Rechercher par nom, race, ville',
              prefixIcon: Icon(Icons.search),
              fillColor: AppColors.surface,
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          height: 50,
          child: OutlinedButton.icon(
            onPressed: onFilters,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(0, 50),
              backgroundColor: AppColors.surface,
              padding: const EdgeInsets.symmetric(horizontal: 14),
            ),
            icon: const Icon(Icons.tune, size: 20, color: AdoptionColors.tealDeep),
            label: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Filtres', style: TextStyle(color: AdoptionColors.tealDeep)),
                if (activeFilters > 0) ...[
                  const SizedBox(width: 6),
                  CircleAvatar(
                    radius: 10,
                    backgroundColor: AppColors.coral,
                    child: Text(
                      '$activeFilters',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AdoptionColors.brown),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SpeciesChips extends StatelessWidget {
  const _SpeciesChips({required this.selected, required this.onSelected});

  final Set<Species> selected;
  final ValueChanged<Species?> onSelected;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      clipBehavior: Clip.none,
      child: Row(
        children: [
          FilterPill(label: 'Tous', emoji: '∞', selected: selected.isEmpty, onTap: () => onSelected(null)),
          for (final s in Species.values) ...[
            const SizedBox(width: 8),
            FilterPill(
              label: s.label,
              emoji: s.emoji,
              selected: selected.length == 1 && selected.contains(s),
              onTap: () => onSelected(s),
            ),
          ],
        ],
      ),
    );
  }
}

class _TrustBanner extends StatelessWidget {
  const _TrustBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AdoptionColors.blueSurface, borderRadius: BorderRadius.circular(16)),
      child: const Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: AdoptionColors.mint,
            child: Icon(Icons.verified_user_outlined, color: AdoptionColors.tealDeep),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Adoption responsable', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                SizedBox(height: 2),
                Text(
                  'Chaque candidature est étudiée par le refuge ou le propriétaire. '
                  'Le carnet de santé n\'est jamais transmis automatiquement.',
                  style: TextStyle(fontSize: 12, height: 1.4, color: AdoptionColors.textMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
