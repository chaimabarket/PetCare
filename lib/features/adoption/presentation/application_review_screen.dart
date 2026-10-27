import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../profile/presentation/widgets/user_avatar.dart';
import '../data/adoption_application.dart';
import '../data/adoption_enums.dart';
import '../data/adoption_listing.dart';
import '../data/adoption_repository.dart';
import '../data/compatibility.dart';
import 'adoption_celebration_screen.dart';
import 'widgets/adoption_widgets.dart';

/// Dossier d'un candidat (maquettes « Détail candidature en examen » et « acceptée / réservée »).
/// Argument de route : l'id de la candidature.
class ApplicationReviewScreen extends StatefulWidget {
  const ApplicationReviewScreen({super.key, required this.applicationId});

  final String applicationId;

  @override
  State<ApplicationReviewScreen> createState() => _ApplicationReviewScreenState();
}

class _ApplicationReviewScreenState extends State<ApplicationReviewScreen> {
  final _repository = AdoptionRepository();
  final _uid = FirebaseAuth.instance.currentUser!.uid;
  late final _appStream = _repository.watchApplication(widget.applicationId);
  Stream<AdoptionListing?>? _listingStream;
  Stream<List<AdoptionApplication>>? _othersStream;
  var _markedReviewing = false;
  var _busy = false;

  void _onApplication(AdoptionApplication app) {
    _listingStream ??= _repository.watchListing(app.listingId);
    if (app.publisherId == _uid) {
      _othersStream ??= _repository.watchReceivedApplications(_uid, listingId: app.listingId);
    }
    // Ouvrir un nouveau dossier le fait passer « En cours d'étude » côté candidat.
    if (!_markedReviewing && app.publisherId == _uid && app.status == ApplicationStatus.pending) {
      _markedReviewing = true;
      _repository.markReviewing(app).catchError((Object _) {});
    }
  }

  Future<void> _run(Future<void> Function() action, String success) async {
    setState(() => _busy = true);
    try {
      await action();
      if (mounted) showAdoptionMessage(context, success);
    } on AdoptionException catch (e) {
      if (mounted) showAdoptionMessage(context, e.message);
    } catch (e) {
      debugPrint('ApplicationReviewScreen: $e');
      if (mounted) showAdoptionMessage(context, "L'action a échoué. Vérifiez votre connexion.");
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _accept(AdoptionApplication app) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Accepter ${app.applicantName} ?'),
        content: Text(
          '${app.listingName} sera réservé(e) et ne pourra plus être accepté(e) pour un autre candidat. '
          'Les autres dossiers restent en attente jusqu\'à l\'adoption.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Accepter')),
        ],
      ),
    );
    if (ok == true) await _run(() => _repository.accept(app), 'Candidature acceptée, ${app.listingName} est réservé(e).');
  }

  Future<void> _refuse(AdoptionApplication app) async {
    final controller = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Refuser la candidature ?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('${app.applicantName} sera informé(e) avec bienveillance.'),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              maxLines: 3,
              maxLength: 200,
              decoration: const InputDecoration(labelText: 'Motif (facultatif, visible par le candidat)'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Refuser'),
          ),
        ],
      ),
    );
    final reason = controller.text;
    controller.dispose();
    if (ok == true) await _run(() => _repository.refuse(app, reason: reason), 'Candidature refusée.');
  }

  Future<void> _cancelAcceptance(AdoptionApplication app) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Annuler l'acceptation ?"),
        content: Text('Le dossier repasse en étude et ${app.listingName} redevient disponible.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Retour')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text("Annuler l'acceptation")),
        ],
      ),
    );
    if (ok == true) await _run(() => _repository.cancelAcceptance(app), 'Acceptation annulée.');
  }

  Future<void> _confirmAdoption(AdoptionListing listing, AdoptionApplication app, int otherOpen) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => _ConfirmAdoptionDialog(listing: listing, application: app, otherOpen: otherOpen),
    );
    if (ok != true || !mounted) return;
    setState(() => _busy = true);
    try {
      final refused = await _repository.confirmAdoption(listing, app);
      if (!mounted) return;
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => AdoptionCelebrationScreen(listing: listing, application: app, othersInformed: refused),
        ),
      );
    } on AdoptionException catch (e) {
      if (mounted) showAdoptionMessage(context, e.message);
    } catch (e) {
      debugPrint('ApplicationReviewScreen: $e');
      if (mounted) showAdoptionMessage(context, "La confirmation a échoué. Vérifiez votre connexion.");
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AdoptionApplication?>(
      stream: _appStream,
      builder: (context, snapshot) {
        final app = snapshot.data;
        if (snapshot.hasError || (app == null && snapshot.connectionState != ConnectionState.waiting)) {
          return Scaffold(
            appBar: AppBar(backgroundColor: AppColors.background),
            body: const EmptyState(icon: Icons.lock_outline, title: 'Dossier indisponible', text: 'Ce dossier n\'est pas accessible.'),
          );
        }
        if (app == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
        _onApplication(app);

        return StreamBuilder<AdoptionListing?>(
          stream: _listingStream,
          builder: (context, listingSnap) {
            final listing = listingSnap.data;
            return Scaffold(
              appBar: AppBar(
                backgroundColor: AppColors.background,
                surfaceTintColor: Colors.transparent,
                titleSpacing: 0,
                title: const Text('Détail de la candidature', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
              ),
              body: ListView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                children: [
                  _ForListingCard(application: app, listing: listing),
                  const SizedBox(height: 12),
                  if (app.status == ApplicationStatus.accepted) ...[
                    _AcceptedBanner(application: app),
                    const SizedBox(height: 12),
                  ],
                  _ApplicantCard(application: app),
                  const SizedBox(height: 16),
                  _ScoreCard(application: app),
                  const SizedBox(height: 24),
                  const Text('Réponses au questionnaire', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 12),
                  _MotivationCard(application: app),
                  _AnswersCard(
                    icon: Icons.apartment,
                    title: 'Logement & environnement',
                    lines: [app.answers.housingSummary, app.answers.tenureSummary, 'Ville : ${app.answers.city}'],
                  ),
                  _AnswersCard(
                    icon: Icons.groups_outlined,
                    title: 'Composition du foyer',
                    lines: [
                      app.answers.familySummary,
                      if (app.answers.kids > 0) 'Âge des enfants : ${app.answers.kidsAges.join(', ')}',
                      app.answers.petsSummary,
                      app.answers.allergies ? 'Allergies signalées' : 'Aucune allergie',
                    ],
                  ),
                  _AnswersCard(
                    icon: Icons.schedule,
                    title: 'Mode de vie',
                    lines: [
                      'Absence quotidienne : ${app.answers.hoursAloneLabel}',
                      'Ambiance : ${app.answers.lifestyle.label}',
                      'Expérience : ${app.answers.experience.label}',
                    ],
                  ),
                ],
              ),
              bottomNavigationBar: app.publisherId == _uid && listing != null ? _actions(app, listing) : null,
            );
          },
        );
      },
    );
  }

  Widget? _actions(AdoptionApplication app, AdoptionListing listing) {
    final spinner = const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white));
    switch (app.status) {
      case ApplicationStatus.pending:
      case ApplicationStatus.reviewing:
        final blocked = listing.status != ListingStatus.available;
        return BottomActions(
          children: [
            FilledButton.icon(
              style: softButtonStyle().copyWith(minimumSize: const WidgetStatePropertyAll(Size(0, 52))),
              onPressed: _busy ? null : () => _refuse(app),
              icon: const Icon(Icons.close),
              label: const Text('Refuser'),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Tooltip(
                message: blocked ? 'Une autre candidature est déjà acceptée' : '',
                child: FilledButton.icon(
                  onPressed: _busy || blocked ? null : () => _accept(app),
                  icon: _busy ? spinner : const Icon(Icons.check),
                  label: Text(blocked ? 'Animal déjà réservé' : 'Accepter le dossier'),
                ),
              ),
            ),
          ],
        );
      case ApplicationStatus.accepted:
        return StreamBuilder<List<AdoptionApplication>>(
          stream: _othersStream,
          builder: (context, snap) {
            final others = (snap.data ?? const []).where((a) => a.id != app.id && a.status.isOpen).length;
            return BottomActions(
              children: [
                FilledButton.icon(
                  style: softButtonStyle().copyWith(minimumSize: const WidgetStatePropertyAll(Size(0, 52))),
                  onPressed: _busy ? null : () => _cancelAcceptance(app),
                  icon: const Icon(Icons.undo),
                  label: const Text('Annuler'),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    style: warmButtonStyle(),
                    onPressed: _busy ? null : () => _confirmAdoption(listing, app, others),
                    icon: _busy ? spinner : const Icon(Icons.pets),
                    label: const Text("Confirmer l'adoption"),
                  ),
                ),
              ],
            );
          },
        );
      case ApplicationStatus.adopted:
      case ApplicationStatus.refused:
      case ApplicationStatus.withdrawn:
        return null;
    }
  }
}

class _ForListingCard extends StatelessWidget {
  const _ForListingCard({required this.application, required this.listing});

  final AdoptionApplication application;
  final AdoptionListing? listing;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AdoptionColors.blueSurface, borderRadius: BorderRadius.circular(16)),
      child: Row(
        children: [
          SizedBox(
            width: 56,
            height: 56,
            child: PetPhoto(
              bytes: listing?.cover,
              species: application.listingSpecies,
              emojiSize: 26,
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('CANDIDATURE POUR',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.6, color: AdoptionColors.tealDeep)),
                Text(application.listingName, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                if (listing != null)
                  Text('${listing!.species.label} · ${listing!.ageLabel} · ${listing!.publisherName}',
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              ],
            ),
          ),
          if (listing != null) StatusPill.listing(listing!.status),
        ],
      ),
    );
  }
}

class _AcceptedBanner extends StatelessWidget {
  const _AcceptedBanner({required this.application});

  final AdoptionApplication application;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: const Color(0xFFCCF5EF), borderRadius: BorderRadius.circular(16)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check_circle_outline, color: AdoptionColors.tealDeep, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Candidature acceptée – ${application.listingName} est réservé(e) 🎉',
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(
                  '${application.applicantName} a été notifié(e). Confirmez l\'adoption après la remise de l\'animal.',
                  style: const TextStyle(fontSize: 13, height: 1.4, color: AdoptionColors.textMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ApplicantCard extends StatelessWidget {
  const _ApplicantCard({required this.application});

  final AdoptionApplication application;

  @override
  Widget build(BuildContext context) {
    final app = application;
    final parts = app.applicantName.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    final initials = parts.isEmpty ? '?' : (parts.first[0] + (parts.length > 1 ? parts.last[0] : '')).toUpperCase();

    return AdoptionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              UserAvatar(initials: initials, radius: 26),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(app.applicantName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                    Row(
                      children: [
                        const Icon(Icons.location_on_outlined, size: 14, color: AppColors.textSecondary),
                        const SizedBox(width: 2),
                        Text(app.answers.city, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                      ],
                    ),
                  ],
                ),
              ),
              StatusPill.application(app.status),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(color: AdoptionColors.blueSurface, borderRadius: BorderRadius.circular(10)),
            child: Row(
              children: [
                const Icon(Icons.schedule, size: 16, color: AdoptionColors.textMuted),
                const SizedBox(width: 6),
                Text(formatShortDate(app.createdAt), style: const TextStyle(fontSize: 12)),
                const Spacer(),
                Text('Dossier #${app.reference}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ScoreCard extends StatelessWidget {
  const _ScoreCard({required this.application});

  final AdoptionApplication application;

  @override
  Widget build(BuildContext context) {
    final level = CompatibilityLevel.of(application.score);
    return AdoptionCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome_outlined, color: AdoptionColors.tealDeep),
              const SizedBox(width: 8),
              const Expanded(
                child: Text('Compatibilité foyer', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              ),
              StatusPill(
                label: level.label,
                dot: false,
                tone: switch (level) {
                  CompatibilityLevel.high => PillTone.teal,
                  CompatibilityLevel.medium => PillTone.warning,
                  CompatibilityLevel.low => PillTone.inactive,
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          Center(child: ScoreGauge(score: application.score, size: 120, showLevel: false)),
          const SizedBox(height: 8),
          Text(
            'Score calculé à partir des besoins de ${application.listingName} et des réponses du candidat.',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, color: AdoptionColors.textMuted),
          ),
          const SizedBox(height: 12),
          const TipBanner(
            icon: Icons.info_outline,
            text: 'Aide à la décision, pas un verdict. Votre appréciation humaine prime toujours sur l\'indicateur.',
          ),
          const SizedBox(height: 16),
          const Text("Points d'évaluation clés", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          for (final p in application.points)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: p.ok ? AdoptionColors.blueSurface : AdoptionColors.peachLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    p.ok ? Icons.check_circle : Icons.warning_amber_rounded,
                    size: 20,
                    color: p.ok ? AdoptionColors.tealDeep : AdoptionColors.brown,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text.rich(
                      TextSpan(children: [
                        TextSpan(text: '${p.label} : ', style: const TextStyle(fontWeight: FontWeight.w700)),
                        TextSpan(text: p.detail),
                      ]),
                      style: const TextStyle(fontSize: 13, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _MotivationCard extends StatelessWidget {
  const _MotivationCard({required this.application});

  final AdoptionApplication application;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AdoptionColors.peachLight, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Motivation pour ${application.listingName}',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AdoptionColors.brown)),
          const SizedBox(height: 8),
          Text('« ${application.answers.motivation} »',
              style: const TextStyle(fontSize: 15, height: 1.6, fontStyle: FontStyle.italic)),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: Text('Transmis par ${application.applicantName}',
                style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
          ),
        ],
      ),
    );
  }
}

class _AnswersCard extends StatelessWidget {
  const _AnswersCard({required this.icon, required this.title, required this.lines});

  final IconData icon;
  final String title;
  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: AdoptionCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            CardHeader(icon: icon, title: title),
            const SizedBox(height: 10),
            for (final line in lines)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Text('•  $line', style: const TextStyle(fontSize: 14, height: 1.4)),
              ),
          ],
        ),
      ),
    );
  }
}

/// Fenêtre « Confirmer l'adoption de Nala par Lina ? ».
class _ConfirmAdoptionDialog extends StatelessWidget {
  const _ConfirmAdoptionDialog({required this.listing, required this.application, required this.otherOpen});

  final AdoptionListing listing;
  final AdoptionApplication application;
  final int otherOpen;

  @override
  Widget build(BuildContext context) {
    final firstName = application.applicantName.split(' ').first;
    return Dialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Center(
              child: CircleAvatar(
                radius: 34,
                backgroundColor: AppColors.coral,
                child: CircleAvatar(
                  radius: 28,
                  backgroundColor: AppColors.teal,
                  child: Icon(Icons.favorite_border, color: Colors.white, size: 28),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Confirmer l\'adoption de ${listing.name} par $firstName ?',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: -0.3),
            ),
            const SizedBox(height: 8),
            Text(
              'Cette étape officialise le placement définitif de ${listing.name} dans son nouveau foyer.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, height: 1.4, color: AdoptionColors.textMuted),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: AdoptionColors.blueSurface, borderRadius: BorderRadius.circular(16)),
              child: Column(
                children: [
                  _DialogLine(
                    icon: Icons.check,
                    background: AdoptionColors.mint,
                    color: AdoptionColors.tealDeep,
                    text: "L'annonce de ${listing.name} passera « Adopté » au nom de $firstName",
                  ),
                  const _DialogLine(
                    icon: Icons.shield_outlined,
                    background: AppColors.surface,
                    color: AdoptionColors.textMuted,
                    text: 'Le carnet de santé ne sera pas transmis',
                  ),
                  _DialogLine(
                    icon: Icons.info_outline,
                    background: AdoptionColors.peach,
                    color: AdoptionColors.brown,
                    text: otherOpen == 0
                        ? 'Aucune autre candidature en attente'
                        : 'Les $otherOpen autre${otherOpen > 1 ? 's' : ''} candidature${otherOpen > 1 ? 's' : ''} '
                            'seront refusées et les candidats informés',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    style: softButtonStyle(),
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Annuler'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(backgroundColor: AppColors.coral, foregroundColor: AdoptionColors.brown),
                    onPressed: () => Navigator.pop(context, true),
                    icon: const Icon(Icons.volunteer_activism_outlined),
                    label: const Text('Confirmer'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DialogLine extends StatelessWidget {
  const _DialogLine({required this.icon, required this.background, required this.color, required this.text});

  final IconData icon;
  final Color background;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(radius: 14, backgroundColor: background, child: Icon(icon, size: 16, color: color)),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 14, height: 1.4))),
        ],
      ),
    );
  }
}
