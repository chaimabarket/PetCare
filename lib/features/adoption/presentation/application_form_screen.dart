import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../core/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../auth/presentation/widgets/auth_feedback.dart';
import '../../profile/data/profile_repository.dart';
import '../data/adoption_application.dart';
import '../data/adoption_enums.dart';
import '../data/adoption_listing.dart';
import '../data/adoption_repository.dart';
import 'widgets/adoption_widgets.dart';

/// Demande d'adoption en 4 étapes (maquettes « Demande d'adoption étape 1 à 4 » et « Candidature envoyée »).
///
/// Un seul formulaire, découpé en étapes pour rester lisible sur téléphone : tout est envoyé à la fin.
class ApplicationFormScreen extends StatefulWidget {
  const ApplicationFormScreen({super.key, required this.listing});

  final AdoptionListing listing;

  @override
  State<ApplicationFormScreen> createState() => _ApplicationFormScreenState();
}

class _ApplicationFormScreenState extends State<ApplicationFormScreen> {
  static const _steps = ['Logement', 'Foyer', 'Mode de vie', 'Récap'];
  static const motivationMin = 30;
  static const motivationMax = 500;

  final _repository = AdoptionRepository();
  final _answers = ApplicationAnswers();
  final _cityController = TextEditingController();
  final _motivationController = TextEditingController();
  final _scroll = ScrollController();

  var _step = 0;
  var _sending = false;
  String? _error;
  AdoptionApplication? _sent;

  AdoptionListing get _listing => widget.listing;

  @override
  void initState() {
    super.initState();
    _prefillCity();
  }

  Future<void> _prefillCity() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final profile = await ProfileRepository().watch(uid).first;
    if (!mounted || profile == null || _cityController.text.isNotEmpty) return;
    _cityController.text = profile.city;
  }

  @override
  void dispose() {
    _cityController.dispose();
    _motivationController.dispose();
    _scroll.dispose();
    super.dispose();
  }

  /// Vérifie l'étape courante ; renvoie le message d'erreur à afficher.
  String? _validate(int step) {
    switch (step) {
      case 0:
        if (_cityController.text.trim().isEmpty) return 'Indiquez votre ville de résidence.';
      case 1:
        if (_answers.adults < 1) return 'Le foyer doit compter au moins un adulte.';
        if (_answers.kids > 0 && _answers.kidsAges.isEmpty) return "Choisissez la tranche d'âge des enfants.";
      case 2:
        final length = _motivationController.text.trim().length;
        if (length < motivationMin) {
          return 'Expliquez votre motivation en quelques phrases ($motivationMin caractères minimum).';
        }
    }
    return null;
  }

  void _goTo(int step) {
    setState(() {
      _error = null;
      _step = step;
    });
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  void _next() {
    _answers
      ..city = _cityController.text
      ..motivation = _motivationController.text;
    final error = _validate(_step);
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    if (_step < _steps.length - 1) {
      _goTo(_step + 1);
    } else {
      _submit();
    }
  }

  Future<void> _submit() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      final profile = await ProfileRepository().watch(uid).first;
      if (profile == null) throw const AdoptionException('Complétez votre profil avant de candidater.');
      final sent = await _repository.apply(listing: _listing, answers: _answers, applicant: profile);
      if (mounted) setState(() => _sent = sent);
    } on AdoptionException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      debugPrint('ApplicationFormScreen: $e');
      if (mounted) setState(() => _error = "L'envoi a échoué. Vérifiez votre connexion puis réessayez.");
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<bool> _confirmLeave() async {
    if (_sent != null) return true;
    final leave = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Quitter la demande ?'),
        content: const Text('Vos réponses ne seront pas enregistrées.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Continuer')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Quitter')),
        ],
      ),
    );
    return leave == true;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _sent != null,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final navigator = Navigator.of(context);
        if (await _confirmLeave()) navigator.pop();
      },
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: AppColors.background,
          surfaceTintColor: Colors.transparent,
          centerTitle: true,
          title: Column(
            children: [
              const Text(
                "DEMANDE D'ADOPTION",
                style: TextStyle(fontSize: 11, letterSpacing: 1, fontWeight: FontWeight.w600, color: AdoptionColors.tealDeep),
              ),
              Text(_listing.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            ],
          ),
        ),
        body: _sent != null ? _SentView(listing: _listing, application: _sent!) : _form(),
        bottomNavigationBar: _sent != null ? null : _actions(),
      ),
    );
  }

  Widget _form() {
    return ListView(
      controller: _scroll,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      children: [
        _ListingHeader(listing: _listing),
        const SizedBox(height: 12),
        _Progress(step: _step, labels: _steps),
        const SizedBox(height: 20),
        switch (_step) {
          0 => _HousingStep(answers: _answers, cityController: _cityController, listing: _listing, onChanged: _refresh),
          1 => _HouseholdStep(answers: _answers, listing: _listing, onChanged: _refresh),
          2 => _LifestyleStep(answers: _answers, listing: _listing, motivation: _motivationController, onChanged: _refresh),
          _ => _RecapStep(answers: _answers, listing: _listing, onEdit: _goTo),
        },
        if (_error != null) ...[const SizedBox(height: 16), ErrorBanner(_error!)],
      ],
    );
  }

  void _refresh() => setState(() => _error = null);

  Widget _actions() {
    final last = _step == _steps.length - 1;
    return BottomActions(
      children: [
        if (_step > 0) ...[
          FilledButton.icon(
            style: softButtonStyle().copyWith(minimumSize: const WidgetStatePropertyAll(Size(0, 52))),
            onPressed: _sending ? null : () => _goTo(_step - 1),
            icon: const Icon(Icons.arrow_back),
            label: const Text('Précédent'),
          ),
          const SizedBox(width: 12),
        ],
        Expanded(
          child: FilledButton.icon(
            style: last ? warmButtonStyle() : null,
            onPressed: _sending ? null : _next,
            iconAlignment: last ? IconAlignment.start : IconAlignment.end,
            icon: _sending
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : Icon(last ? Icons.pets : Icons.arrow_forward),
            label: Text(last ? 'Envoyer ma candidature' : 'Continuer (${_step + 2}/${_steps.length})'),
          ),
        ),
      ],
    );
  }
}

class _ListingHeader extends StatelessWidget {
  const _ListingHeader({required this.listing});

  final AdoptionListing listing;

  @override
  Widget build(BuildContext context) {
    return AdoptionCard(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          SizedBox(
            width: 56,
            height: 56,
            child: PetPhoto(
              bytes: listing.cover,
              species: listing.species,
              emojiSize: 26,
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(listing.name, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                Text(
                  '${listing.species.label} · ${listing.ageLabel} · ${listing.city}',
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          Flexible(
            child: StatusPill(label: listing.publisherName, tone: PillTone.adopted, icon: Icons.location_on_outlined),
          ),
        ],
      ),
    );
  }
}

class _Progress extends StatelessWidget {
  const _Progress({required this.step, required this.labels});

  final int step;
  final List<String> labels;

  @override
  Widget build(BuildContext context) {
    final percent = ((step + 1) / labels.length * 100).round();
    return AdoptionCard(
      child: Column(
        children: [
          Row(
            children: [
              Text(
                'ÉTAPE ${step + 1} SUR ${labels.length}',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.5, color: AdoptionColors.tealDeep),
              ),
              const Spacer(),
              Text('$percent% complété', style: const TextStyle(fontSize: 12, color: AdoptionColors.textMuted)),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: (step + 1) / labels.length,
              minHeight: 8,
              backgroundColor: AdoptionColors.blueSurface,
              color: AdoptionColors.tealDeep,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              for (var i = 0; i < labels.length; i++)
                Expanded(
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 14,
                        backgroundColor: i <= step ? AdoptionColors.tealDeep : AdoptionColors.blueSurface,
                        child: i < step
                            ? const Icon(Icons.check, size: 16, color: Colors.white)
                            : Text(
                                '${i + 1}',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: i == step ? Colors.white : AppColors.textSecondary,
                                ),
                              ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        labels[i],
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: i == step ? FontWeight.w700 : FontWeight.w500,
                          color: i == step ? AdoptionColors.tealDeep : AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StepTitle extends StatelessWidget {
  const _StepTitle({required this.title, required this.text});

  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700, letterSpacing: -0.5)),
          const SizedBox(height: 6),
          Text(text, style: const TextStyle(fontSize: 14, height: 1.5, color: AdoptionColors.textMuted)),
        ],
      ),
    );
  }
}

/// Deux cartes à choix côte à côte.
class _Choice<T> extends StatelessWidget {
  const _Choice({required this.options, required this.value, required this.onChanged});

  final List<({T value, String title, String subtitle, IconData icon})> options;
  final T value;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < options.length; i++) ...[
            if (i > 0) const SizedBox(width: 10),
            Expanded(
              child: SelectableCard(
                title: options[i].title,
                subtitle: options[i].subtitle,
                icon: options[i].icon,
                selected: options[i].value == value,
                onTap: () => onChanged(options[i].value),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _HousingStep extends StatelessWidget {
  const _HousingStep({
    required this.answers,
    required this.cityController,
    required this.listing,
    required this.onChanged,
  });

  final ApplicationAnswers answers;
  final TextEditingController cityController;
  final AdoptionListing listing;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final a = answers;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _StepTitle(
          title: 'Votre logement',
          text: 'Ces informations permettent de s\'assurer avec bienveillance que le futur cadre de vie '
              'correspond aux besoins de ${listing.name}.',
        ),
        const BarTitle('Type de logement'),
        _Choice<HousingType>(
          value: a.housing,
          onChanged: (v) {
            a.housing = v;
            onChanged();
          },
          options: [
            for (final h in HousingType.values)
              (
                value: h,
                title: h.label,
                subtitle: h.hint,
                icon: h == HousingType.apartment ? Icons.apartment : Icons.house_outlined,
              ),
          ],
        ),
        const SizedBox(height: 20),
        const BarTitle('Jardin ou extérieur accessible'),
        _Choice<bool>(
          value: a.hasGarden,
          onChanged: (v) {
            a.hasGarden = v;
            onChanged();
          },
          options: const [
            (value: true, title: 'Oui', subtitle: 'Cour ou jardin clos', icon: Icons.yard_outlined),
            (value: false, title: 'Non', subtitle: 'Intérieur exclusif', icon: Icons.weekend_outlined),
          ],
        ),
        if (listing.needsGarden && !a.hasGarden) ...[
          const SizedBox(height: 10),
          TipBanner(
            icon: Icons.tips_and_updates_outlined,
            text: "${listing.name} a besoin d'un extérieur : précisez dans votre motivation comment vous comptez y répondre.",
          ),
        ],
        const SizedBox(height: 20),
        const BarTitle('Vous êtes'),
        _Choice<Tenure>(
          value: a.tenure,
          onChanged: (v) {
            a.tenure = v;
            onChanged();
          },
          options: [
            for (final t in Tenure.values)
              (
                value: t,
                title: t.label,
                subtitle: t.hint,
                icon: t == Tenure.owner ? Icons.key_outlined : Icons.description_outlined,
              ),
          ],
        ),
        if (a.tenure == Tenure.tenant) ...[
          const SizedBox(height: 12),
          AdoptionCard(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: SwitchListTile(
              value: a.landlordAgrees,
              onChanged: (v) {
                a.landlordAgrees = v;
                onChanged();
              },
              secondary: const CircleAvatar(
                backgroundColor: AdoptionColors.peachLight,
                child: Icon(Icons.verified_user_outlined, color: AdoptionColors.brown),
              ),
              title: const Text('Accord du propriétaire', style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: const Text('Les animaux sont acceptés dans les lieux'),
            ),
          ),
        ],
        const SizedBox(height: 20),
        const BarTitle('Ville de résidence'),
        TextField(
          controller: cityController,
          textCapitalization: TextCapitalization.words,
          onChanged: (_) => onChanged(),
          decoration: const InputDecoration(
            hintText: 'Ex. Tunis, La Marsa',
            prefixIcon: Icon(Icons.location_on_outlined),
            fillColor: AppColors.surface,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'À titre indicatif pour organiser la rencontre avec le refuge ou le propriétaire.',
          style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
      ],
    );
  }
}

class _HouseholdStep extends StatelessWidget {
  const _HouseholdStep({required this.answers, required this.listing, required this.onChanged});

  final ApplicationAnswers answers;
  final AdoptionListing listing;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final a = answers;
    void set(void Function() change) {
      change();
      onChanged();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _StepTitle(
          title: 'Votre foyer',
          text: 'Mieux connaître les membres de votre famille et vos compagnons actuels permet de '
              's\'assurer d\'une cohabitation sereine.',
        ),
        AdoptionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const BarTitle('Composition de la famille'),
              CounterRow(
                title: 'Adultes',
                subtitle: '18 ans et plus au foyer',
                value: a.adults,
                min: 1,
                onChanged: (v) => set(() => a.adults = v),
              ),
              CounterRow(
                title: 'Enfants',
                subtitle: 'Mineurs présents au quotidien',
                value: a.kids,
                onChanged: (v) => set(() => a.kids = v),
              ),
              if (a.kids > 0) ...[
                const SizedBox(height: 4),
                const Text("Tranche d'âge des enfants", style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final range in kidsAgeRanges)
                      FilterChip(
                        label: Text(range),
                        selected: a.kidsAges.contains(range),
                        onSelected: (v) => set(() => v ? a.kidsAges.add(range) : a.kidsAges.remove(range)),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                TipBanner(
                  tone: listing.goodWithKids ? TipTone.green : TipTone.coral,
                  title: 'Bon à savoir',
                  text: listing.goodWithKids
                      ? '${listing.name} s\'entend bien avec les enfants calmes et respectueux de son espace.'
                      : '${listing.name} n\'est pas indiqué(e) comme à l\'aise avec les enfants.',
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        AdoptionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const BarTitle('Animaux actuels'),
              CounterRow(
                emoji: '🐱',
                title: 'Chats',
                subtitle: 'Félins résidents',
                value: a.cats,
                onChanged: (v) => set(() => a.cats = v),
              ),
              CounterRow(
                emoji: '🐶',
                title: 'Chiens',
                subtitle: 'Canidés au domicile',
                value: a.dogs,
                onChanged: (v) => set(() => a.dogs = v),
              ),
              CounterRow(
                emoji: '🐰',
                title: 'Autres animaux',
                subtitle: 'NAC, oiseaux, etc.',
                value: a.otherPets,
                onChanged: (v) => set(() => a.otherPets = v),
              ),
              if (a.cats > 0 && listing.goodWithCats)
                TipBanner(
                  tone: TipTone.green,
                  icon: Icons.check_circle_outline,
                  text: 'Entente avec les chats indiquée pour ${listing.name}.',
                ),
              if (a.dogs > 0 && !listing.goodWithDogs)
                TipBanner(
                  tone: TipTone.coral,
                  icon: Icons.warning_amber_rounded,
                  text: '${listing.name} n\'est pas indiqué(e) comme compatible avec les chiens.',
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        AdoptionCard(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: SwitchListTile(
            value: a.allergies,
            onChanged: (v) => set(() => a.allergies = v),
            secondary: const CircleAvatar(
              backgroundColor: AdoptionColors.blueSurface,
              child: Icon(Icons.health_and_safety_outlined, color: AdoptionColors.tealDeep),
            ),
            title: const Text('Allergies connues', style: TextStyle(fontWeight: FontWeight.w600)),
            subtitle: const Text('Y a-t-il des personnes allergiques aux poils d\'animaux ?'),
          ),
        ),
      ],
    );
  }
}

class _LifestyleStep extends StatelessWidget {
  const _LifestyleStep({
    required this.answers,
    required this.listing,
    required this.motivation,
    required this.onChanged,
  });

  final ApplicationAnswers answers;
  final AdoptionListing listing;
  final TextEditingController motivation;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final a = answers;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _StepTitle(
          title: 'Votre rythme de vie',
          text: 'Comprendre vos habitudes au quotidien aide à confirmer l\'harmonie entre votre foyer '
              'et le caractère de ${listing.name}.',
        ),
        AdoptionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const CardHeader(icon: Icons.schedule, title: "Heures d'absence par jour"),
              const SizedBox(height: 12),
              Center(child: StatusPill(label: a.hoursAloneLabel, tone: PillTone.teal, icon: Icons.timelapse)),
              Slider(
                value: a.hoursAlone.toDouble(),
                max: 10,
                divisions: 10,
                label: a.hoursAloneLabel,
                onChanged: (v) {
                  a.hoursAlone = v.round();
                  onChanged();
                },
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [Text('0h'), Text('5h'), Text('10h+')],
                ),
              ),
              if (a.hoursAlone > listing.okAloneHours) ...[
                const SizedBox(height: 12),
                TipBanner(
                  tone: TipTone.coral,
                  title: 'Bon à savoir',
                  text: '${listing.name} supporte environ ${listing.okAloneHours} h seul(e) par jour.',
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        AdoptionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const CardHeader(icon: Icons.home_outlined, title: 'Ambiance générale du foyer'),
              const SizedBox(height: 12),
              RadioGroup<Lifestyle>(
                groupValue: a.lifestyle,
                onChanged: (v) {
                  if (v == null) return;
                  a.lifestyle = v;
                  onChanged();
                },
                child: Column(
                  children: [
                    for (final l in Lifestyle.values)
                      RadioListTile<Lifestyle>(
                        value: l,
                        contentPadding: EdgeInsets.zero,
                        controlAffinity: ListTileControlAffinity.trailing,
                        title: Text(l.label, style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text(l.hint),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        AdoptionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              CardHeader(
                icon: Icons.workspace_premium_outlined,
                title: 'Expérience avec les ${listing.species.label.toLowerCase()}s',
                subtitle: 'Tous les niveaux sont bienvenus.',
              ),
              const SizedBox(height: 12),
              SegmentedButton<Experience>(
                showSelectedIcon: false,
                segments: [
                  for (final e in Experience.values) ButtonSegment(value: e, label: Text(e.label, textAlign: TextAlign.center)),
                ],
                selected: {a.experience},
                onSelectionChanged: (v) {
                  a.experience = v.first;
                  onChanged();
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        AdoptionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(Icons.favorite_border, color: AdoptionColors.brown),
                  const SizedBox(width: 8),
                  Text('Pourquoi ${listing.name} ?', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                ],
              ),
              const SizedBox(height: 4),
              const Text(
                'Racontez ce qui vous a touché et la vie que vous envisagez ensemble.',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: motivation,
                minLines: 5,
                maxLines: 8,
                maxLength: _ApplicationFormScreenState.motivationMax,
                textCapitalization: TextCapitalization.sentences,
                onChanged: (_) => onChanged(),
                decoration: const InputDecoration(hintText: 'Son regard doux et son histoire m\'ont touché…'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _RecapStep extends StatelessWidget {
  const _RecapStep({required this.answers, required this.listing, required this.onEdit});

  final ApplicationAnswers answers;
  final AdoptionListing listing;
  final ValueChanged<int> onEdit;

  @override
  Widget build(BuildContext context) {
    final a = answers;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _StepTitle(
          title: 'Récapitulatif de votre demande',
          text: 'Prenez un instant pour vérifier vos informations avant l\'envoi.',
        ),
        _RecapCard(
          icon: Icons.apartment,
          title: 'Logement',
          onEdit: () => onEdit(0),
          lines: [
            (Icons.home_outlined, a.housingSummary),
            (Icons.verified_outlined, a.tenureSummary),
            (Icons.location_on_outlined, a.city),
          ],
        ),
        _RecapCard(
          icon: Icons.groups_outlined,
          title: 'Foyer',
          onEdit: () => onEdit(1),
          lines: [
            (Icons.people_outline, a.familySummary),
            if (a.kids > 0) (Icons.child_care, 'Âge des enfants : ${a.kidsAges.join(', ')}'),
            (Icons.pets, a.petsSummary),
            (Icons.health_and_safety_outlined, a.allergies ? 'Allergies dans le foyer' : 'Aucune allergie connue'),
          ],
        ),
        _RecapCard(
          icon: Icons.hourglass_bottom,
          title: 'Mode de vie',
          onEdit: () => onEdit(2),
          lines: [
            (Icons.schedule, 'Absence quotidienne : ${a.hoursAloneLabel}'),
            (Icons.volume_down_outlined, 'Rythme : ${a.lifestyle.label}'),
            (Icons.workspace_premium_outlined, 'Expérience : ${a.experience.label}'),
          ],
        ),
        AdoptionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(Icons.favorite_border, color: AdoptionColors.brown),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('Motivation pour ${listing.name}',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  ),
                  TextButton(
                    onPressed: () => onEdit(2),
                    style: TextButton.styleFrom(foregroundColor: AdoptionColors.brown),
                    child: const Text('Modifier'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: AdoptionColors.peachLight, borderRadius: BorderRadius.circular(14)),
                child: Text(
                  '« ${a.motivation.trim()} »',
                  style: const TextStyle(fontSize: 15, height: 1.6, fontStyle: FontStyle.italic),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const TipBanner(
          icon: Icons.info_outline,
          title: 'Note importante',
          text: 'Le carnet de santé n\'est pas transmis automatiquement. Il vous sera remis lors de l\'adoption définitive.',
        ),
      ],
    );
  }
}

class _RecapCard extends StatelessWidget {
  const _RecapCard({required this.icon, required this.title, required this.onEdit, required this.lines});

  final IconData icon;
  final String title;
  final VoidCallback onEdit;
  final List<(IconData, String)> lines;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: AdoptionCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(icon, color: AdoptionColors.tealDeep),
                const SizedBox(width: 8),
                Expanded(child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600))),
                TextButton.icon(
                  onPressed: onEdit,
                  iconAlignment: IconAlignment.end,
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  label: const Text('Modifier'),
                ),
              ],
            ),
            for (final (lineIcon, text) in lines)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Icon(lineIcon, size: 18, color: AdoptionColors.textMuted),
                    const SizedBox(width: 8),
                    Expanded(child: Text(text, style: const TextStyle(fontSize: 14))),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SentView extends StatelessWidget {
  const _SentView({required this.listing, required this.application});

  final AdoptionListing listing;
  final AdoptionApplication application;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      children: [
        AspectRatio(
          aspectRatio: 1.5,
          child: PetPhoto(
            bytes: listing.cover,
            species: listing.species,
            emojiSize: 72,
            borderRadius: BorderRadius.circular(24),
          ),
        ),
        const SizedBox(height: 20),
        const Center(child: StatusPill(label: 'Demande transmise avec succès', tone: PillTone.teal, icon: Icons.check_circle_outline)),
        const SizedBox(height: 12),
        const Text(
          'Candidature envoyée !',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, letterSpacing: -0.5),
        ),
        const SizedBox(height: 8),
        Text(
          '${listing.publisherName} va l\'étudier avec soin. Vous serez notifié(e) dès qu\'une décision sera prise.',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 15, height: 1.5, color: AdoptionColors.textMuted),
        ),
        const SizedBox(height: 20),
        AdoptionCard(
          child: Column(
            children: [
              _SentLine(icon: Icons.home_work_outlined, label: 'Annonceur', value: listing.publisherName),
              _SentLine(icon: Icons.tag, label: 'Dossier n°', value: '#${application.reference}'),
              const _SentLine(icon: Icons.schedule, label: 'Statut', value: 'En attente'),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const AdoptionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CardHeader(icon: Icons.checklist, title: 'Prochaines étapes'),
              SizedBox(height: 12),
              _NextStep(number: 1, text: "Examen bienveillant de votre dossier par l'annonceur."),
              _NextStep(number: 2, text: 'Réponse dans vos notifications : acceptée ou non retenue.'),
              _NextStep(number: 3, text: 'Rencontre et remise de l\'animal pour concrétiser le coup de cœur !'),
            ],
          ),
        ),
        const SizedBox(height: 24),
        FilledButton.icon(
          onPressed: () => Navigator.of(context).pushReplacementNamed(AppRoutes.myApplications),
          icon: const Icon(Icons.pets),
          label: const Text('Suivre ma candidature'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text("Retour à l'annonce"),
        ),
      ],
    );
  }
}

class _SentLine extends StatelessWidget {
  const _SentLine({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AdoptionColors.tealDeep),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(color: AdoptionColors.textMuted)),
          const Spacer(),
          Flexible(child: Text(value, textAlign: TextAlign.end, style: const TextStyle(fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }
}

class _NextStep extends StatelessWidget {
  const _NextStep({required this.number, required this.text});

  final int number;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 13,
            backgroundColor: number == 1 ? AdoptionColors.mint : AdoptionColors.blueSurface,
            child: Text('$number', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 14, height: 1.4))),
        ],
      ),
    );
  }
}
