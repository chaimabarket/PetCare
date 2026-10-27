import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../core/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/relative_time.dart';
import '../../profile/presentation/widgets/user_avatar.dart';
import '../data/adoption_application.dart';
import '../data/adoption_enums.dart';
import '../data/adoption_listing.dart';
import '../data/adoption_repository.dart';
import '../data/compatibility.dart';
import 'widgets/adoption_widgets.dart';

/// Candidatures reçues pour une annonce (maquette « Candidatures reçues »), triées par compatibilité.
class ReceivedApplicationsScreen extends StatefulWidget {
  const ReceivedApplicationsScreen({super.key, required this.listing});

  final AdoptionListing listing;

  @override
  State<ReceivedApplicationsScreen> createState() => _ReceivedApplicationsScreenState();
}

enum _Filter { all, fresh, reviewing, accepted, closed }

class _ReceivedApplicationsScreenState extends State<ReceivedApplicationsScreen> {
  final _repository = AdoptionRepository();
  late final _listingStream = _repository.watchListing(widget.listing.id);
  late final _appsStream = _repository.watchReceivedApplications(
    FirebaseAuth.instance.currentUser!.uid,
    listingId: widget.listing.id,
  );
  var _filter = _Filter.all;
  var _byScore = true;

  bool _matches(AdoptionApplication a) => switch (_filter) {
        _Filter.all => true,
        _Filter.fresh => a.status == ApplicationStatus.pending,
        _Filter.reviewing => a.status == ApplicationStatus.reviewing,
        _Filter.accepted => a.status == ApplicationStatus.accepted || a.status == ApplicationStatus.adopted,
        _Filter.closed => a.status == ApplicationStatus.refused || a.status == ApplicationStatus.withdrawn,
      };

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AdoptionListing?>(
      stream: _listingStream,
      initialData: widget.listing,
      builder: (context, listingSnap) {
        final listing = listingSnap.data ?? widget.listing;
        return Scaffold(
          appBar: AppBar(
            backgroundColor: AppColors.background,
            surfaceTintColor: Colors.transparent,
            titleSpacing: 0,
            title: const Text('Candidatures reçues', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
          ),
          body: StreamBuilder<List<AdoptionApplication>>(
            stream: _appsStream,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                debugPrint('ReceivedApplicationsScreen: ${snapshot.error}');
                return const EmptyState(icon: Icons.cloud_off, title: 'Dossiers indisponibles', text: 'Réessayez plus tard.');
              }
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

              final all = snapshot.data!;
              final visible = all.where(_matches).toList();
              if (!_byScore) visible.sort((a, b) => (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)));
              final fresh = all.where((a) => a.status == ApplicationStatus.pending).length;

              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                children: [
                  _ListingSummary(listing: listing, total: all.length, fresh: fresh),
                  const SizedBox(height: 12),
                  if (listing.status == ListingStatus.reserved)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 12),
                      child: TipBanner(
                        tone: TipTone.green,
                        icon: Icons.lock_clock_outlined,
                        text: "Une candidature est acceptée : l'animal est réservé. Confirmez l'adoption après la remise, "
                            'ou annulez l\'acceptation pour choisir un autre dossier.',
                      ),
                    ),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<bool>(
                          initialValue: _byScore,
                          decoration: const InputDecoration(prefixIcon: Icon(Icons.swap_vert), fillColor: AppColors.surface),
                          items: const [
                            DropdownMenuItem(value: true, child: Text('Tri : compatibilité décroissante')),
                            DropdownMenuItem(value: false, child: Text('Tri : plus récentes')),
                          ],
                          onChanged: (v) => setState(() => _byScore = v ?? true),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (final (f, label) in [
                          (_Filter.all, 'Toutes  ${all.length}'),
                          (_Filter.fresh, 'Nouvelles  $fresh'),
                          (_Filter.reviewing, 'En étude'),
                          (_Filter.accepted, 'Acceptée'),
                          (_Filter.closed, 'Clôturées'),
                        ]) ...[
                          FilterPill(label: label, selected: _filter == f, onTap: () => setState(() => _filter = f)),
                          const SizedBox(width: 8),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (visible.isEmpty)
                    EmptyState(
                      icon: Icons.inbox_outlined,
                      title: all.isEmpty ? 'Aucune candidature pour le moment' : 'Aucun dossier ici',
                      text: 'Vous serez notifié(e) dès qu\'une personne souhaitera adopter ${listing.name}.',
                    )
                  else
                    for (final app in visible)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _ApplicantCard(
                          application: app,
                          onOpen: () => Navigator.of(context).pushNamed(AppRoutes.applicationReview, arguments: app.id),
                        ),
                      ),
                  const SizedBox(height: 8),
                  const TipBanner(
                    icon: Icons.shield_outlined,
                    title: 'Conseil PetCare',
                    text: 'Le score met en balance les besoins de l\'animal et le foyer déclaré. '
                        'C\'est une aide : votre échange avec le candidat reste décisif.',
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }
}

class _ListingSummary extends StatelessWidget {
  const _ListingSummary({required this.listing, required this.total, required this.fresh});

  final AdoptionListing listing;
  final int total;
  final int fresh;

  @override
  Widget build(BuildContext context) {
    final needs = [
      listing.energy == EnergyLevel.low ? 'Environnement calme' : 'Énergie ${listing.energy.label.toLowerCase()}',
      if (listing.goodWithKids) 'OK enfants',
      if (!listing.goodWithCats) 'Sans autre chat',
      if (!listing.goodWithDogs) 'Sans chien',
      if (listing.needsGarden) 'Jardin nécessaire',
    ];
    return AdoptionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              SizedBox(
                width: 64,
                height: 64,
                child: PetPhoto(
                  bytes: listing.cover,
                  species: listing.species,
                  emojiSize: 28,
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(listing.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                        ),
                        StatusPill.listing(listing.status),
                      ],
                    ),
                    Text('${listing.species.label} · ${listing.ageLabel}',
                        style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                    const SizedBox(height: 2),
                    Text.rich(
                      TextSpan(children: [
                        TextSpan(
                          text: '$total dossier${total > 1 ? 's' : ''} reçu${total > 1 ? 's' : ''}',
                          style: const TextStyle(color: AppColors.teal, fontWeight: FontWeight.w600),
                        ),
                        if (fresh > 0)
                          TextSpan(
                            text: '  ·  $fresh nouveau${fresh > 1 ? 'x' : ''}',
                            style: const TextStyle(color: AdoptionColors.brown, fontWeight: FontWeight.w600),
                          ),
                      ]),
                      style: const TextStyle(fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: AdoptionColors.blueSurface, borderRadius: BorderRadius.circular(12)),
            child: Text.rich(
              TextSpan(children: [
                TextSpan(text: 'Besoins essentiels de ${listing.name}\n', style: const TextStyle(fontWeight: FontWeight.w600)),
                TextSpan(text: needs.join(' · ')),
              ]),
              style: const TextStyle(fontSize: 12, height: 1.4, color: AdoptionColors.textMuted),
            ),
          ),
        ],
      ),
    );
  }
}

class _ApplicantCard extends StatelessWidget {
  const _ApplicantCard({required this.application, required this.onOpen});

  final AdoptionApplication application;
  final VoidCallback onOpen;

  String get _initials {
    final parts = application.applicantName.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    return (parts.first[0] + (parts.length > 1 ? parts.last[0] : '')).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final app = application;
    final level = CompatibilityLevel.of(app.score);
    final closed = !app.status.isOpen && app.status != ApplicationStatus.adopted;

    return Opacity(
      opacity: closed ? 0.65 : 1,
      child: AdoptionCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                UserAvatar(initials: _initials, radius: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(app.applicantName, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                          StatusPill.application(app.status),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(Icons.location_on_outlined, size: 14, color: AppColors.textSecondary),
                          const SizedBox(width: 2),
                          Flexible(
                            child: Text(
                              '${app.answers.city} · ${app.createdAt == null ? '' : formatRelativeTime(app.createdAt!)}',
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                ScoreGauge(score: app.score),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final p in app.points.where((p) => level == CompatibilityLevel.high ? p.ok : !p.ok).take(3))
                  StatusPill(
                    label: p.label,
                    tone: p.ok ? PillTone.success : PillTone.warning,
                    icon: p.ok ? Icons.check_circle_outline : Icons.warning_amber_rounded,
                  ),
              ],
            ),
            if (app.answers.motivation.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: AdoptionColors.blueSurface, borderRadius: BorderRadius.circular(12)),
                child: Text(
                  '« ${app.answers.motivation} »',
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 14, height: 1.5),
                ),
              ),
            ],
            const SizedBox(height: 12),
            FilledButton.icon(
              style: closed ? softButtonStyle() : null,
              onPressed: onOpen,
              iconAlignment: IconAlignment.end,
              icon: const Icon(Icons.arrow_forward),
              label: const Text('Consulter le dossier'),
            ),
          ],
        ),
      ),
    );
  }
}
