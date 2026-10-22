import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../core/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../data/adoption_application.dart';
import '../data/adoption_enums.dart';
import '../data/adoption_listing.dart';
import '../data/adoption_repository.dart';
import 'widgets/adoption_widgets.dart';

/// Annonces d'adoption de l'annonceur, rangées par statut (maquette « Mes annonces d'adoption »).
class MyListingsScreen extends StatefulWidget {
  const MyListingsScreen({super.key});

  @override
  State<MyListingsScreen> createState() => _MyListingsScreenState();
}

class _MyListingsScreenState extends State<MyListingsScreen> {
  final _repository = AdoptionRepository();
  final _uid = FirebaseAuth.instance.currentUser!.uid;
  late final _listingsStream = _repository.watchMyListings(_uid);
  late final _applicationsStream = _repository.watchReceivedApplications(_uid);
  var _status = ListingStatus.available;

  static const _tabs = [
    (ListingStatus.available, 'Disponibles'),
    (ListingStatus.reserved, 'Réservées'),
    (ListingStatus.adopted, 'Adoptées'),
    (ListingStatus.draft, 'Brouillons'),
    (ListingStatus.archived, 'Archivées'),
  ];

  void _publish() => Navigator.of(context).pushNamed(AppRoutes.adoptionPublish);

  Future<void> _archive(AdoptionListing listing) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Archiver ${listing.name} ?'),
        content: const Text(
          "L'annonce ne sera plus visible. Les candidatures en attente seront refusées et les candidats informés.",
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Archiver')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await _repository.archive(listing);
      if (mounted) showAdoptionMessage(context, 'Annonce archivée.');
    } on AdoptionException catch (e) {
      if (mounted) showAdoptionMessage(context, e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        titleSpacing: 0,
        title: const Text("Mes annonces d'adoption", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton.icon(
              style: FilledButton.styleFrom(minimumSize: const Size(0, 38), padding: const EdgeInsets.symmetric(horizontal: 14)),
              onPressed: _publish,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Publier'),
            ),
          ),
        ],
      ),
      body: StreamBuilder<List<AdoptionListing>>(
        stream: _listingsStream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            debugPrint('MyListingsScreen: ${snapshot.error}');
            return const EmptyState(icon: Icons.cloud_off, title: 'Annonces indisponibles', text: 'Réessayez plus tard.');
          }
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final all = snapshot.data!;
          final visible = all.where((l) => l.status == _status).toList();

          return StreamBuilder<List<AdoptionApplication>>(
            stream: _applicationsStream,
            builder: (context, appSnap) {
              final apps = appSnap.data ?? const <AdoptionApplication>[];
              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                children: [
                  _SummaryCard(listings: all, applications: apps, onPublish: _publish),
                  const SizedBox(height: 16),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (final (status, label) in _tabs) ...[
                          _CountTab(
                            label: label,
                            count: all.where((l) => l.status == status).length,
                            selected: _status == status,
                            onTap: () => setState(() => _status = status),
                          ),
                          const SizedBox(width: 8),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (visible.isEmpty)
                    EmptyState(
                      icon: Icons.campaign_outlined,
                      title: all.isEmpty ? 'Aucune annonce publiée' : 'Aucune annonce dans cette catégorie',
                      text: 'Présentez un animal à adopter : photos, caractère, besoins et conditions.',
                    )
                  else
                    for (final listing in visible)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: _ListingCard(
                          listing: listing,
                          applications: apps.where((a) => a.listingId == listing.id).toList(),
                          onArchive: () => _archive(listing),
                        ),
                      ),
                  const SizedBox(height: 4),
                  const _AdviceCard(),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

/// Bandeau du haut : nombre d'animaux, candidatures actives et répartition par statut.
class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.listings, required this.applications, required this.onPublish});

  final List<AdoptionListing> listings;
  final List<AdoptionApplication> applications;
  final VoidCallback onPublish;

  @override
  Widget build(BuildContext context) {
    final inCare = listings.where((l) => l.status == ListingStatus.available || l.status == ListingStatus.reserved).length;
    final active = applications.where((a) => a.status.isOpen).length;
    final counts = [
      (listings.where((l) => l.status == ListingStatus.available).length, AdoptionColors.tealDeep),
      (listings.where((l) => l.status == ListingStatus.reserved).length, AppColors.coral),
      (listings.where((l) => l.status == ListingStatus.adopted).length, AdoptionColors.peach),
    ];
    final publisherName = listings.isEmpty ? null : listings.first.publisherName;

    return AdoptionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.verified_outlined, size: 16, color: AdoptionColors.tealDeep),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  publisherName ?? 'Mon espace annonceur',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13, color: AdoptionColors.textMuted),
                ),
              ),
              const StatusPill(label: 'Actif', tone: PillTone.inactive),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('$inCare animal${inCare > 1 ? 'aux' : ''}',
                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, letterSpacing: -0.4)),
                    Text.rich(
                      TextSpan(children: [
                        const TextSpan(text: 'pris en charge • '),
                        TextSpan(
                          text: '$active candidature${active > 1 ? 's' : ''} active${active > 1 ? 's' : ''}',
                          style: const TextStyle(fontWeight: FontWeight.w700, color: AdoptionColors.tealDeep),
                        ),
                      ]),
                      style: const TextStyle(fontSize: 13, color: AdoptionColors.textMuted),
                    ),
                  ],
                ),
              ),
              FilledButton.icon(
                style: FilledButton.styleFrom(minimumSize: const Size(0, 40), padding: const EdgeInsets.symmetric(horizontal: 14)),
                onPressed: onPublish,
                icon: const Icon(Icons.pets, size: 16),
                label: const Text('+ Nouvelle'),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Barre de répartition : disponibles (teal), réservées (corail), adoptées (pêche).
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: SizedBox(
              height: 6,
              child: counts.every((c) => c.$1 == 0)
                  ? const ColoredBox(color: AdoptionColors.blueSurface)
                  : Row(
                      children: [
                        for (final (count, color) in counts)
                          if (count > 0) Expanded(flex: count, child: ColoredBox(color: color)),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CountTab extends StatelessWidget {
  const _CountTab({required this.label, required this.count, required this.selected, required this.onTap});

  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AdoptionColors.tealDeep : AppColors.surface,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
          child: Row(
            children: [
              Text(label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: selected ? Colors.white : AppColors.textPrimary,
                  )),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: selected ? Colors.white.withValues(alpha: 0.2) : AdoptionColors.blueSurface,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text('$count',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: selected ? Colors.white : AppColors.textPrimary,
                    )),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ListingCard extends StatelessWidget {
  const _ListingCard({required this.listing, required this.applications, required this.onArchive});

  final AdoptionListing listing;
  final List<AdoptionApplication> applications;
  final VoidCallback onArchive;

  @override
  Widget build(BuildContext context) {
    final l = listing;
    final navigator = Navigator.of(context);
    final fresh = applications.where((a) => a.status == ApplicationStatus.pending).length;
    final reviewing = applications.where((a) => a.status == ApplicationStatus.reviewing).length;
    final canArchive = l.status != ListingStatus.archived && l.status != ListingStatus.adopted;

    void edit() => navigator.pushNamed(AppRoutes.adoptionPublish, arguments: l);

    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => navigator.pushNamed(AppRoutes.adoptionListing, arguments: l.id),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AspectRatio(
              aspectRatio: 1.6,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  PetPhoto(bytes: l.cover, species: l.species, emojiSize: 64),
                  Positioned(left: 10, top: 10, child: _Overlay(text: '${l.species.label} • ${l.ageLabel}')),
                  Positioned(right: 10, top: 10, child: StatusPill.listing(l.status)),
                  if (l.status != ListingStatus.draft && l.status != ListingStatus.adopted)
                    Positioned(right: 10, bottom: 10, child: _Overlay(text: '${l.daysOnline}j en ligne')),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(l.name,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                      ),
                      const SizedBox(width: 6),
                      Text(l.sex.symbol, style: const TextStyle(fontSize: 16, color: AdoptionColors.textMuted)),
                      const Spacer(),
                      PopupMenuButton<String>(
                        tooltip: 'Plus d\'actions',
                        onSelected: (v) => v == 'edit' ? edit() : onArchive(),
                        itemBuilder: (_) => [
                          const PopupMenuItem(value: 'edit', child: Text('Modifier')),
                          if (canArchive) const PopupMenuItem(value: 'archive', child: Text('Archiver')),
                        ],
                      ),
                    ],
                  ),
                  Text(
                    [if (l.breed.isNotEmpty) l.breed else l.species.label, l.publisherName].join(' • '),
                    style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                  ),
                  if (l.status == ListingStatus.adopted && l.adopterName != null)
                    Text('Adopté(e) par ${l.adopterName}',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.coralText)),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(color: AdoptionColors.blueSurface, borderRadius: BorderRadius.circular(10)),
                      child: Row(
                        children: [
                          const Icon(Icons.folder_outlined, size: 18, color: AdoptionColors.textMuted),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text('${applications.length} candidature${applications.length > 1 ? 's' : ''}',
                                style: const TextStyle(fontSize: 13)),
                          ),
                          if (fresh > 0)
                            StatusPill(
                              label: '$fresh nouvelle${fresh > 1 ? 's' : ''}',
                              tone: fresh > 1 ? PillTone.teal : PillTone.adopted,
                              dot: false,
                            )
                          else if (reviewing > 0)
                            const Text('En examen', style: TextStyle(fontSize: 12, color: AdoptionColors.textMuted)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: l.status == ListingStatus.draft
                                ? null
                                : () => navigator.pushNamed(AppRoutes.receivedApplications, arguments: l),
                            icon: const Icon(Icons.visibility_outlined, size: 18),
                            label: Text('Voir les candidatures (${applications.length})'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton.filled(
                          tooltip: 'Modifier',
                          style: IconButton.styleFrom(
                            backgroundColor: AdoptionColors.blueSurface,
                            foregroundColor: AppColors.textPrimary,
                            fixedSize: const Size(52, 52),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: edit,
                          icon: const Icon(Icons.edit_outlined),
                        ),
                      ],
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

class _Overlay extends StatelessWidget {
  const _Overlay({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(999)),
      child: Text(text, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.white)),
    );
  }
}

class _AdviceCard extends StatelessWidget {
  const _AdviceCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AdoptionColors.blueSurface, borderRadius: BorderRadius.circular(16)),
      child: const Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: AdoptionColors.peach,
            child: Icon(Icons.auto_awesome_outlined, color: AdoptionColors.brown),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Conseil d'adoption", style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                SizedBox(height: 2),
                Text(
                  "Répondez sous 48 h aux candidats pour maximiser les chances de réussite de l'adoption.",
                  style: TextStyle(fontSize: 13, height: 1.4, color: AdoptionColors.textMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
