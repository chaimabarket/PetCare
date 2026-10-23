import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../core/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../data/adoption_application.dart';
import '../data/adoption_enums.dart';
import '../data/adoption_listing.dart';
import '../data/adoption_repository.dart';
import 'widgets/adoption_widgets.dart';

/// Suivi des demandes de l'adoptant (maquette « Mes candidatures »).
class MyApplicationsScreen extends StatefulWidget {
  const MyApplicationsScreen({super.key});

  @override
  State<MyApplicationsScreen> createState() => _MyApplicationsScreenState();
}

enum _Tab { all, open, closed }

class _MyApplicationsScreenState extends State<MyApplicationsScreen> {
  final _repository = AdoptionRepository();
  late final _stream = _repository.watchMyApplications(FirebaseAuth.instance.currentUser!.uid);
  var _tab = _Tab.all;

  Future<void> _withdraw(AdoptionApplication app) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Retirer ma candidature ?'),
        content: Text(
          'Votre demande pour ${app.listingName} sera retirée définitivement'
          '${app.status == ApplicationStatus.accepted ? ' et l\'animal sera de nouveau proposé aux autres candidats' : ''}.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Retirer'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await _repository.withdraw(app);
      if (mounted) showAdoptionMessage(context, 'Candidature retirée.');
    } catch (_) {
      if (mounted) showAdoptionMessage(context, 'Impossible de retirer la candidature. Réessayez.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        titleSpacing: 0,
        title: const Text('Mes candidatures', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
      ),
      body: StreamBuilder<List<AdoptionApplication>>(
        stream: _stream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            debugPrint('MyApplicationsScreen: ${snapshot.error}');
            return EmptyState.loadError(title: 'Candidatures indisponibles', error: snapshot.error);
          }
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          final all = snapshot.data!;
          final open = all.where((a) => a.status.isOpen).toList();
          final closed = all.where((a) => !a.status.isOpen).toList();
          final visible = switch (_tab) {
            _Tab.all => all,
            _Tab.open => open,
            _Tab.closed => closed,
          };

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
            children: [
              const _IntroCard(),
              const SizedBox(height: 16),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    FilterPill(label: 'Toutes  ${all.length}', selected: _tab == _Tab.all, onTap: () => setState(() => _tab = _Tab.all)),
                    const SizedBox(width: 8),
                    FilterPill(label: 'En cours  ${open.length}', selected: _tab == _Tab.open, onTap: () => setState(() => _tab = _Tab.open)),
                    const SizedBox(width: 8),
                    FilterPill(
                        label: 'Terminées  ${closed.length}', selected: _tab == _Tab.closed, onTap: () => setState(() => _tab = _Tab.closed)),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              if (visible.isEmpty)
                EmptyState(
                  icon: Icons.volunteer_activism_outlined,
                  title: all.isEmpty ? 'Aucune candidature' : 'Rien dans cette catégorie',
                  text: 'Trouvez un compagnon dans le fil d\'adoption et envoyez votre demande.',
                  action: all.isEmpty
                      ? FilledButton(
                          onPressed: () => Navigator.of(context).pushReplacementNamed(AppRoutes.adoption),
                          child: const Text('Découvrir les animaux'),
                        )
                      : null,
                )
              else
                for (final app in visible)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: _ApplicationCard(application: app, onWithdraw: () => _withdraw(app)),
                  ),
            ],
          );
        },
      ),
    );
  }
}

class _IntroCard extends StatelessWidget {
  const _IntroCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AdoptionColors.blueSurface, borderRadius: BorderRadius.circular(16)),
      child: const Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: AdoptionColors.mint,
            child: Icon(Icons.volunteer_activism_outlined, color: AdoptionColors.tealDeep),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Mes démarches d'amour", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                SizedBox(height: 2),
                Text(
                  "Suivez l'avancement de vos demandes d'adoption en toute sérénité.",
                  style: TextStyle(fontSize: 13, color: AdoptionColors.textMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ApplicationCard extends StatefulWidget {
  const _ApplicationCard({required this.application, required this.onWithdraw});

  final AdoptionApplication application;
  final VoidCallback onWithdraw;

  @override
  State<_ApplicationCard> createState() => _ApplicationCardState();
}

class _ApplicationCardState extends State<_ApplicationCard> {
  // L'annonce peut être archivée et donc illisible : la carte s'affiche quand même.
  late final _listingStream = AdoptionRepository()
      .watchListing(widget.application.listingId)
      .handleError((Object _) {});

  @override
  Widget build(BuildContext context) {
    final app = widget.application;
    return StreamBuilder<AdoptionListing?>(
      stream: _listingStream,
      builder: (context, snapshot) {
        final listing = snapshot.data;
        return AdoptionCard(
          color: app.status == ApplicationStatus.refused || app.status == ApplicationStatus.withdrawn
              ? const Color(0xFFF9FAFB)
              : null,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 72,
                    height: 72,
                    child: PetPhoto(
                      bytes: listing?.cover,
                      species: app.listingSpecies,
                      emojiSize: 30,
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(app.listingName,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700)),
                            ),
                            const SizedBox(width: 6),
                            StatusPill(label: app.listingSpecies.label, tone: PillTone.inactive, dot: false),
                          ],
                        ),
                        if (listing != null)
                          Text('${listing.breed.isEmpty ? listing.species.label : listing.breed} • ${listing.ageLabel}',
                              style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.location_on_outlined, size: 14, color: AppColors.teal),
                            const SizedBox(width: 2),
                            Flexible(
                              child: Text(app.publisherName,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 12, color: AppColors.teal, fontWeight: FontWeight.w500)),
                            ),
                          ],
                        ),
                        Text('Envoyée le ${formatShortDate(app.createdAt)}',
                            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                      ],
                    ),
                  ),
                  StatusPill.application(app.status),
                ],
              ),
              const SizedBox(height: 16),
              ApplicationTimeline(status: app.status),
              const SizedBox(height: 14),
              ..._footer(context, app, listing),
            ],
          ),
        );
      },
    );
  }

  List<Widget> _footer(BuildContext context, AdoptionApplication app, AdoptionListing? listing) {
    void openListing() => Navigator.of(context).pushNamed(AppRoutes.adoptionListing, arguments: app.listingId);

    switch (app.status) {
      case ApplicationStatus.adopted:
        return [
          FilledButton.icon(
            style: warmButtonStyle(),
            onPressed: listing == null
                ? null
                : () => Navigator.of(context).pushNamed(AppRoutes.shareHappyTail, arguments: listing),
            icon: const Icon(Icons.auto_stories_outlined),
            label: const Text('🐾 Partager mon Happy Tail'),
          ),
        ];
      case ApplicationStatus.accepted:
        return [
          TipBanner(
            tone: TipTone.green,
            icon: Icons.event_available_outlined,
            title: 'Prochaine étape',
            text: '${app.publisherName} va vous contacter pour organiser la rencontre et la remise de ${app.listingName}.',
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              TextButton.icon(
                onPressed: widget.onWithdraw,
                style: TextButton.styleFrom(foregroundColor: AppColors.textSecondary),
                icon: const Icon(Icons.cancel_outlined, size: 18),
                label: const Text('Retirer'),
              ),
              const Spacer(),
              TextButton(onPressed: openListing, child: const Text('Consulter la fiche  ›')),
            ],
          ),
        ];
      case ApplicationStatus.pending:
      case ApplicationStatus.reviewing:
        return [
          if (app.status == ApplicationStatus.reviewing)
            const TipBanner(
              tone: TipTone.coral,
              icon: Icons.info_outline,
              text: "Votre dossier est en cours d'étude par l'annonceur.",
            ),
          Row(
            children: [
              TextButton.icon(
                onPressed: widget.onWithdraw,
                style: TextButton.styleFrom(foregroundColor: AppColors.textPrimary),
                icon: const Icon(Icons.cancel_outlined, size: 18),
                label: const Text('Retirer ma candidature'),
              ),
              const Spacer(),
              TextButton(onPressed: openListing, child: const Text('Consulter la fiche  ›')),
            ],
          ),
        ];
      case ApplicationStatus.refused:
      case ApplicationStatus.withdrawn:
        return [
          if (app.refusalReason != null)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12)),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.sentiment_neutral, size: 18, color: AppColors.textSecondary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text.rich(
                      TextSpan(children: [
                        const TextSpan(text: 'Motif : ', style: TextStyle(fontWeight: FontWeight.w700)),
                        TextSpan(text: app.refusalReason),
                      ]),
                      style: const TextStyle(fontSize: 13, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => Navigator.of(context).pushNamed(AppRoutes.adoption),
              icon: const Icon(Icons.search, size: 18),
              label: const Text("Voir d'autres animaux"),
            ),
          ),
        ];
    }
  }
}
