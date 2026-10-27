import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../core/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../data/adoption_application.dart';
import '../data/adoption_enums.dart';
import '../data/adoption_listing.dart';
import '../data/adoption_repository.dart';
import 'widgets/adoption_widgets.dart';
import 'widgets/report_dialog.dart';

/// Fiche d'adoption (maquette « Fiche adoption Nala »). Argument de route : l'id de l'annonce.
class ListingDetailScreen extends StatefulWidget {
  const ListingDetailScreen({super.key, required this.listingId});

  final String listingId;

  @override
  State<ListingDetailScreen> createState() => _ListingDetailScreenState();
}

class _ListingDetailScreenState extends State<ListingDetailScreen> {
  final _repository = AdoptionRepository();
  final _user = FirebaseAuth.instance.currentUser;
  late final _listingStream = _repository.watchListing(widget.listingId);
  late final _photosFuture = _repository.fetchPhotos(widget.listingId);
  late final _favoritesStream = _user == null ? null : _repository.watchFavoriteIds(_user.uid);
  late Future<AdoptionApplication?> _myApplication = _loadMyApplication();

  Future<AdoptionApplication?> _loadMyApplication() async {
    final user = _user;
    if (user == null) return null;
    try {
      return await _repository.findMyApplication(widget.listingId, user.uid);
    } catch (_) {
      return null;
    }
  }

  Future<void> _apply(AdoptionListing listing) async {
    if (_user == null) {
      await askToSignIn(context, "Créez un compte ou connectez-vous pour envoyer une demande d'adoption.");
      return;
    }
    await Navigator.of(context).pushNamed(AppRoutes.adoptionApply, arguments: listing);
    if (mounted) setState(() => _myApplication = _loadMyApplication());
  }

  Future<void> _setFavorite(bool favorite) async {
    final user = _user;
    if (user == null) {
      await askToSignIn(context, 'Connectez-vous pour enregistrer vos coups de cœur.');
      return;
    }
    await _repository.setFavorite(user.uid, widget.listingId, favorite);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AdoptionListing?>(
      stream: _listingStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const _Shell(
            child: EmptyState(
              icon: Icons.lock_outline,
              title: 'Annonce indisponible',
              text: "Cette annonce a été retirée ou n'est plus accessible.",
            ),
          );
        }
        if (!snapshot.hasData && snapshot.connectionState == ConnectionState.waiting) {
          return const _Shell(child: Center(child: CircularProgressIndicator()));
        }
        final listing = snapshot.data;
        if (listing == null) {
          return const _Shell(
            child: EmptyState(icon: Icons.search_off, title: 'Annonce introuvable', text: 'Elle a peut-être été supprimée.'),
          );
        }
        final isMine = _user?.uid == listing.publisherId;

        return Scaffold(
          body: StreamBuilder<Set<String>>(
            stream: _favoritesStream,
            builder: (context, favSnap) {
              final favorite = favSnap.data?.contains(listing.id) ?? false;
              return CustomScrollView(
                slivers: [
                  SliverAppBar(
                    pinned: true,
                    expandedHeight: 340,
                    backgroundColor: AppColors.background,
                    surfaceTintColor: Colors.transparent,
                    leading: const _CircleBack(),
                    actions: [
                      if (!isMine)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: IconButton.filled(
                            tooltip: favorite ? 'Retirer des favoris' : 'Ajouter aux favoris',
                            style: IconButton.styleFrom(backgroundColor: AppColors.surface),
                            onPressed: () => _setFavorite(!favorite),
                            icon: Icon(favorite ? Icons.favorite : Icons.favorite_border, color: AppColors.coralText),
                          ),
                        ),
                    ],
                    flexibleSpace: FlexibleSpaceBar(
                      background: FutureBuilder<List<Uint8List>>(
                        future: _photosFuture,
                        builder: (context, photosSnap) => _Gallery(
                          listing: listing,
                          photos: photosSnap.data ?? [?listing.cover],
                        ),
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                    sliver: SliverList.list(
                      children: [
                        _IdentityCard(listing: listing),
                        const SizedBox(height: 20),
                        if (listing.badges.isNotEmpty) ...[
                          const Row(
                            children: [
                              Icon(Icons.psychology_alt_outlined, size: 20, color: AdoptionColors.brown),
                              SizedBox(width: 6),
                              Text('Caractère & Tempérament', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [for (final b in listing.badges) BadgeChip(badge: b)],
                          ),
                          const SizedBox(height: 20),
                        ],
                        if (listing.story.isNotEmpty)
                          _TextCard(icon: Icons.menu_book_outlined, title: 'Son histoire', text: listing.story),
                        _CompatibilityCard(listing: listing),
                        if (listing.needs.isNotEmpty)
                          _TextCard(icon: Icons.pets, title: 'Besoins au quotidien', text: listing.needs),
                        if (listing.conditions.isNotEmpty)
                          _TextCard(icon: Icons.fact_check_outlined, title: "Conditions d'adoption", text: listing.conditions),
                        _PublisherCard(listing: listing),
                        const SizedBox(height: 12),
                        if (!isMine)
                          Center(
                            child: TextButton.icon(
                              onPressed: () => _user == null
                                  ? askToSignIn(context, 'Connectez-vous pour signaler une annonce.')
                                  : showReportDialog(
                                      context,
                                      reporterId: _user.uid,
                                      targetType: 'adoption',
                                      targetId: listing.id,
                                    ),
                              style: TextButton.styleFrom(foregroundColor: AppColors.textSecondary),
                              icon: const Icon(Icons.flag_outlined, size: 16),
                              label: const Text('Signaler une anomalie sur cette fiche', style: TextStyle(fontSize: 12)),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
          bottomNavigationBar: isMine
              ? BottomActions(
                  children: [
                    IconButton.filledTonal(
                      tooltip: 'Modifier',
                      onPressed: () => Navigator.of(context).pushNamed(AppRoutes.adoptionPublish, arguments: listing),
                      icon: const Icon(Icons.edit_outlined),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () => Navigator.of(context).pushNamed(AppRoutes.receivedApplications, arguments: listing),
                        icon: const Icon(Icons.folder_open_outlined),
                        label: const Text('Voir les candidatures'),
                      ),
                    ),
                  ],
                )
              : FutureBuilder<AdoptionApplication?>(
                  future: _myApplication,
                  builder: (context, appSnap) => _ApplyBar(
                    listing: listing,
                    application: appSnap.data,
                    onApply: () => _apply(listing),
                  ),
                ),
        );
      },
    );
  }
}

class _Shell extends StatelessWidget {
  const _Shell({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(appBar: AppBar(backgroundColor: AppColors.background), body: child);
  }
}

class _CircleBack extends StatelessWidget {
  const _CircleBack();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: IconButton.filled(
        tooltip: 'Retour',
        style: IconButton.styleFrom(backgroundColor: AppColors.surface, foregroundColor: AppColors.textPrimary),
        onPressed: () => Navigator.of(context).maybePop(),
        icon: const Icon(Icons.arrow_back),
      ),
    );
  }
}

class _Gallery extends StatefulWidget {
  const _Gallery({required this.listing, required this.photos});

  final AdoptionListing listing;
  final List<Uint8List> photos;

  @override
  State<_Gallery> createState() => _GalleryState();
}

class _GalleryState extends State<_Gallery> {
  var _page = 0;

  @override
  Widget build(BuildContext context) {
    final photos = widget.photos;
    if (photos.isEmpty) {
      return Hero(
        tag: 'listing-${widget.listing.id}',
        child: PetPhoto(bytes: null, species: widget.listing.species, emojiSize: 96),
      );
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        PageView.builder(
          itemCount: photos.length,
          onPageChanged: (i) => setState(() => _page = i),
          itemBuilder: (context, i) => i == 0
              ? Hero(
                  tag: 'listing-${widget.listing.id}',
                  child: PetPhoto(bytes: photos[i], species: widget.listing.species),
                )
              : PetPhoto(bytes: photos[i], species: widget.listing.species),
        ),
        if (photos.length > 1)
          Positioned(
            right: 12,
            bottom: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(999)),
              child: Row(
                children: [
                  const Icon(Icons.photo_camera_outlined, size: 14, color: Colors.white),
                  const SizedBox(width: 4),
                  Text('${_page + 1} / ${photos.length}', style: const TextStyle(fontSize: 12, color: Colors.white)),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _IdentityCard extends StatelessWidget {
  const _IdentityCard({required this.listing});

  final AdoptionListing listing;

  @override
  Widget build(BuildContext context) {
    final l = listing;
    return AdoptionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              if (l.isUrgent) const StatusPill(label: 'Adopte-moi', tone: PillTone.adopted, icon: Icons.favorite_border),
              StatusPill.listing(l.status),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Flexible(
                child: Text(l.name, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700, letterSpacing: -0.5)),
              ),
              const SizedBox(width: 8),
              CircleAvatar(
                radius: 14,
                backgroundColor: AdoptionColors.peachLight,
                child: Text(l.sex.symbol, style: const TextStyle(color: AppColors.coralText, fontWeight: FontWeight.w700)),
              ),
              const Spacer(),
              const Icon(Icons.location_on_outlined, size: 16, color: AppColors.textSecondary),
              const SizedBox(width: 2),
              Flexible(
                child: Text(
                  l.city,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            [l.species.label, if (l.breed.isNotEmpty) l.breed, l.sex.label, l.ageLabel].join(' · '),
            style: const TextStyle(fontSize: 14, color: AdoptionColors.textMuted),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: _InfoTile(icon: Icons.cake_outlined, label: 'Âge', value: '${l.ageLabel} (${l.ageGroup.label})')),
              const SizedBox(width: 8),
              Expanded(child: _InfoTile(icon: Icons.straighten, label: 'Gabarit', value: '${l.size.label} · ${l.size.hint}')),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _InfoTile(icon: Icons.bolt_outlined, label: 'Énergie', value: l.energy.label)),
              const SizedBox(width: 8),
              Expanded(
                child: _InfoTile(icon: Icons.schedule, label: 'Peut rester seul', value: '${l.okAloneHours} h / jour'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: AdoptionColors.blueSurface, borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AdoptionColors.tealDeep),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AdoptionColors.tealDeep)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TextCard extends StatelessWidget {
  const _TextCard({required this.icon, required this.title, required this.text});

  final IconData icon;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: AdoptionCard(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CardHeader(icon: icon, title: title),
            const SizedBox(height: 12),
            Text(text, style: const TextStyle(fontSize: 14, height: 1.6, color: AppColors.textPrimary)),
          ],
        ),
      ),
    );
  }
}

class _CompatibilityCard extends StatelessWidget {
  const _CompatibilityCard({required this.listing});

  final AdoptionListing listing;

  @override
  Widget build(BuildContext context) {
    final items = [
      ('Enfants', listing.goodWithKids),
      ('Chats', listing.goodWithCats),
      ('Chiens', listing.goodWithDogs),
    ];
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: AdoptionCard(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const CardHeader(icon: Icons.home_outlined, title: 'Compatibilités du foyer'),
            const SizedBox(height: 12),
            for (final (label, ok) in items)
              _CheckLine(ok: ok, text: ok ? 'S\'entend avec les ${label.toLowerCase()}' : 'Pas avec les ${label.toLowerCase()}'),
            _CheckLine(
              ok: !listing.needsGarden,
              neutral: true,
              text: listing.needsGarden ? "A besoin d'un jardin ou d'un extérieur" : 'Peut vivre sans jardin',
            ),
          ],
        ),
      ),
    );
  }
}

class _CheckLine extends StatelessWidget {
  const _CheckLine({required this.ok, required this.text, this.neutral = false});

  final bool ok;
  final bool neutral;
  final String text;

  @override
  Widget build(BuildContext context) {
    final icon = ok ? Icons.check_circle_outline : (neutral ? Icons.info_outline : Icons.remove_circle_outline);
    final color = ok ? AdoptionColors.tealDeep : (neutral ? AdoptionColors.warningText : AppColors.textSecondary);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 14))),
        ],
      ),
    );
  }
}

class _PublisherCard extends StatelessWidget {
  const _PublisherCard({required this.listing});

  final AdoptionListing listing;

  @override
  Widget build(BuildContext context) {
    return AdoptionCard(
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(color: AdoptionColors.mint, borderRadius: BorderRadius.circular(12)),
            child: Icon(listing.publisherIsShelter ? Icons.home_work_outlined : Icons.person_outline,
                color: AdoptionColors.tealDeep),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(listing.publisherName, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                Text(
                  '${listing.publisherIsShelter ? 'Refuge' : 'Particulier'} · ${listing.city}',
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          Text('En ligne depuis ${formatShortDate(listing.createdAt)}',
              style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}

class _ApplyBar extends StatelessWidget {
  const _ApplyBar({required this.listing, required this.application, required this.onApply});

  final AdoptionListing listing;
  final AdoptionApplication? application;
  final VoidCallback onApply;

  @override
  Widget build(BuildContext context) {
    if (application != null) {
      return BottomActions(
        children: [
          Expanded(
            child: FilledButton.icon(
              onPressed: () => Navigator.of(context).pushNamed(AppRoutes.myApplications),
              icon: const Icon(Icons.track_changes),
              label: Text('Suivre ma candidature · ${application!.status.label}'),
            ),
          ),
        ],
      );
    }
    if (listing.status == ListingStatus.adopted || listing.status == ListingStatus.archived) {
      return BottomActions(
        children: [
          Expanded(
            child: FilledButton(
              onPressed: null,
              child: Text(listing.status == ListingStatus.adopted ? '${listing.name} a trouvé sa famille 🎉' : 'Annonce retirée'),
            ),
          ),
        ],
      );
    }
    return BottomActions(
      children: [
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (listing.status == ListingStatus.reserved)
                const Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: Text(
                    'Déjà réservé(e) : votre candidature sera étudiée si la réservation n\'aboutit pas.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: AdoptionColors.warningText),
                  ),
                ),
              FilledButton.icon(
                style: warmButtonStyle(),
                onPressed: onApply,
                icon: const Icon(Icons.pets),
                label: const Text("Je veux l'adopter"),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
