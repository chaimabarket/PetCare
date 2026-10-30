import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/routes.dart';
import '../data/health_format.dart';
import '../data/health_pet.dart';
import '../data/health_repository.dart';
import '../data/treatment.dart';
import 'widgets/health_ui.dart';

enum _TreatmentFilter { all, active, completed, stopped }

/// Traitements d'un animal (maquette Stitch « Traitements – Milo »).
class TreatmentsScreen extends StatefulWidget {
  const TreatmentsScreen({super.key, required this.petId});

  final String petId;

  @override
  State<TreatmentsScreen> createState() => _TreatmentsScreenState();
}

class _TreatmentsScreenState extends State<TreatmentsScreen> {
  final _repository = HealthRepository();
  late final _petStream = _repository.watchPet(widget.petId);
  late final _treatmentsStream = _repository.watchTreatments(widget.petId);

  /// Null tant que l'utilisateur n'a pas choisi : « En cours » s'il y en a, sinon « Tous ».
  _TreatmentFilter? _filter;

  Future<void> _newTreatment() async {
    final saved = await pushHealthRoute<bool>(context, AppRoutes.treatmentForm, arguments: widget.petId);
    if (saved == true && mounted) {
      setState(() => _filter = null);
      showHealthToast(context, 'Traitement enregistré.');
    }
  }

  Future<void> _logDose(Treatment t) async {
    try {
      await _repository.logDose(widget.petId, t.id);
      if (mounted) showHealthToast(context, 'Prise notée : ${t.name}.');
    } catch (e) {
      if (mounted) showHealthToast(context, friendlyHealthError(e), icon: Symbols.error);
    }
  }

  void _openHistory(Treatment t) => showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        backgroundColor: Colors.white,
        builder: (context) => _HistorySheet(petId: widget.petId, treatment: t),
      );

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<HealthPet?>(
      stream: _petStream,
      builder: (context, petSnap) {
        final pet = petSnap.data;
        return Scaffold(
          backgroundColor: HealthColors.surface,
          appBar: HealthAppBar(
            title: 'Traitements   ${pet?.name ?? ''}',
            actions: [
              PopupMenuButton<String>(
                tooltip: 'Options du carnet',
                icon: const Icon(Symbols.more_vert, size: 22, color: HealthColors.onSurfaceVariant),
                onSelected: (value) => value == 'record'
                    ? Navigator.of(context).maybePop()
                    : pushHealthRoute<void>(context, AppRoutes.healthSheets),
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'record', child: Text('Carnet de santé')),
                  PopupMenuItem(value: 'sheets', child: Text('Fiches santé & conseils')),
                ],
              ),
            ],
          ),
          body: StreamBuilder<List<Treatment>>(
            stream: _treatmentsStream,
            builder: (context, snap) {
              final error = snap.error ?? petSnap.error;
              final treatments = snap.data ?? const <Treatment>[];
              return _buildList(pet, treatments, error, loading: !snap.hasData && error == null);
            },
          ),
        );
      },
    );
  }

  Widget _buildList(HealthPet? pet, List<Treatment> treatments, Object? error, {required bool loading}) {
    final now = DateTime.now();
    int count(TreatmentStatus s) => treatments.where((t) => t.statusAt(now) == s).length;
    final active = count(TreatmentStatus.active);
    final filter = _filter ?? (active > 0 ? _TreatmentFilter.active : _TreatmentFilter.all);
    final visible = treatments.where((t) {
      final status = t.statusAt(now);
      return switch (filter) {
        _TreatmentFilter.all => true,
        _TreatmentFilter.active => status == TreatmentStatus.active,
        _TreatmentFilter.completed => status == TreatmentStatus.completed,
        _TreatmentFilter.stopped => status == TreatmentStatus.stopped,
      };
    }).toList();

    // Le praticien le plus récent sert de « Suivi par … » dans l'en-tête.
    final followedBy = treatments.map((t) => t.practitioner).whereType<String>().firstOrNull;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        if (pet != null) _Summary(pet: pet, activeCount: active, followedBy: followedBy),
        const SizedBox(height: 16),
        SizedBox(
          height: 48,
          child: FilledButton.icon(
            onPressed: _newTreatment,
            style: FilledButton.styleFrom(
              backgroundColor: HealthColors.primary,
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            icon: const Icon(Symbols.add_circle, size: 20),
            label: const Text('Nouveau traitement'),
          ),
        ),
        const SizedBox(height: 16),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          clipBehavior: Clip.none,
          child: Row(
            children: [
              for (final (f, label) in [
                (_TreatmentFilter.all, 'Tous (${treatments.length})'),
                (_TreatmentFilter.active, 'En cours ($active)'),
                (_TreatmentFilter.completed, 'Terminés (${count(TreatmentStatus.completed)})'),
                (_TreatmentFilter.stopped, 'Arrêtés (${count(TreatmentStatus.stopped)})'),
              ]) ...[
                HealthFilterChip(label: label, selected: f == filter, onTap: () => setState(() => _filter = f)),
                const SizedBox(width: 4),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (error != null)
          HealthEmptyState(icon: Symbols.cloud_off, title: 'Chargement impossible', message: friendlyHealthError(error))
        else if (loading)
          const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()))
        else if (visible.isEmpty)
          HealthEmptyState(
            icon: Symbols.medication,
            title: treatments.isEmpty ? 'Aucun traitement' : 'Aucun traitement ici',
            message: treatments.isEmpty
                ? 'Ajoutez un traitement prescrit avec « Nouveau traitement » pour suivre les prises.'
                : 'Choisissez un autre filtre.',
          )
        else
          for (final t in visible) ...[
            _TreatmentCard(
              treatment: t,
              now: now,
              onLogDose: () => _logDose(t),
              onHistory: () => _openHistory(t),
            ),
            const SizedBox(height: 16),
          ],
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: HealthColors.surfaceLow,
            borderRadius: BorderRadius.circular(16),
            boxShadow: HealthColors.cardShadow,
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(color: HealthColors.surfaceContainer, shape: BoxShape.circle),
                child: const Icon(Symbols.lock, size: 20, color: HealthColors.primary),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Ordonnances et prises consignées synchronisées avec le carnet de santé vétérinaire officiel.',
                  style: HealthText.bodySm.copyWith(height: 1.6),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Mini-profil : photo, nom, nombre de traitements actifs, praticien qui suit l'animal.
class _Summary extends StatelessWidget {
  const _Summary({required this.pet, required this.activeCount, required this.followedBy});

  final HealthPet pet;
  final int activeCount;
  final String? followedBy;

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: HealthColors.cardShadow),
      child: Stack(
        children: [
          Positioned(
            right: -16,
            bottom: -16,
            child: Container(
              width: 112,
              height: 112,
              decoration: BoxDecoration(
                color: HealthColors.surfaceContainer.withValues(alpha: 0.4),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    HealthPetPhoto(name: pet.name, photo: pet.photo, size: 56),
                    const Positioned(
                      right: -4,
                      bottom: -4,
                      child: HealthPhotoBadge(icon: Symbols.medical_services, size: 20, color: HealthColors.primary),
                    ),
                  ],
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(child: Text(pet.name, style: HealthText.headlineSm, overflow: TextOverflow.ellipsis)),
                          if (activeCount > 0)
                            HealthPill(
                              label: activeCount == 1 ? '1 actif' : '$activeCount actifs',
                              dotColor: HealthColors.secondary,
                              background: HealthColors.secondaryFixed,
                              foreground: HealthColors.onSecondaryFixed,
                            ),
                        ],
                      ),
                      Text(pet.breedAndAge(shortAge: true), style: HealthText.bodySm, overflow: TextOverflow.ellipsis),
                      if (followedBy != null) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Symbols.verified, size: 14, color: HealthColors.primary),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                'Suivi par $followedBy',
                                style: HealthText.bodySm,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
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

/// Bouton plat des cartes (« Noter la prise », historique…).
class _SoftButton extends StatelessWidget {
  const _SoftButton({required this.onTap, this.icon, this.label, this.iconColor, this.foreground, this.tooltip});

  final VoidCallback onTap;
  final IconData? icon;
  final String? label;
  final Color? iconColor;
  final Color? foreground;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final fg = foreground ?? HealthColors.onSurface;
    final button = Material(
      color: HealthColors.surfaceLow,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          alignment: Alignment.center,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) Icon(icon, size: label == null ? 20 : 18, color: iconColor ?? fg),
              if (icon != null && label != null) const SizedBox(width: 6),
              if (label != null) Text(label!, style: HealthText.labelMd.copyWith(color: fg)),
            ],
          ),
        ),
      ),
    );
    return tooltip == null ? button : Tooltip(message: tooltip, child: button);
  }
}

class _TreatmentCard extends StatelessWidget {
  const _TreatmentCard({required this.treatment, required this.now, required this.onLogDose, required this.onHistory});

  final Treatment treatment;
  final DateTime now;
  final VoidCallback onLogDose;
  final VoidCallback onHistory;

  static const _formIcons = {
    TreatmentForm.tablet: Symbols.pill,
    TreatmentForm.drops: Symbols.visibility,
    TreatmentForm.injection: Symbols.syringe,
    TreatmentForm.spotOn: Symbols.water_drop,
    TreatmentForm.other: Symbols.medication,
  };

  @override
  Widget build(BuildContext context) {
    final t = treatment;
    final status = t.statusAt(now);

    final categoryColor = switch (status) {
      TreatmentStatus.active => HealthColors.primary,
      TreatmentStatus.completed => HealthColors.onSurfaceVariant,
      TreatmentStatus.stopped => HealthColors.outline,
    };
    final pill = switch (status) {
      TreatmentStatus.active => const HealthPill(
          label: 'En cours',
          dotColor: HealthColors.secondary,
          background: HealthColors.secondaryFixed,
          foreground: HealthColors.onSecondaryFixed,
        ),
      TreatmentStatus.completed => const HealthPill(
          label: 'Terminé',
          icon: Symbols.done,
          background: Color(0x260F766E),
          foreground: HealthColors.primaryContainer,
        ),
      TreatmentStatus.stopped => const HealthPill(
          label: 'Arrêté',
          dotColor: HealthColors.outline,
          background: HealthColors.surfaceHighest,
          foreground: HealthColors.onSurfaceVariant,
        ),
    };

    final children = <Widget>[
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t.category.toUpperCase(),
                  style: HealthText.labelSm.copyWith(color: categoryColor, fontWeight: FontWeight.w600, letterSpacing: 0.8),
                ),
                const SizedBox(height: 2),
                Text(t.name, style: HealthText.headlineSm.copyWith(height: 1.3)),
                if (t.subtitle != null) Text(t.subtitle!, style: HealthText.bodySm, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          const SizedBox(width: 8),
          pill,
        ],
      ),
    ];

    // Ligne praticien, ou note de protocole pour un traitement terminé sans praticien affiché.
    if (status == TreatmentStatus.completed && t.scheduleNote != null) {
      children.add(_iconLine(Symbols.calendar_today, t.scheduleNote!, HealthColors.outline));
    } else if (t.practitioner != null) {
      children.add(_iconLine(
        Symbols.stethoscope,
        t.practitioner!,
        status == TreatmentStatus.stopped ? HealthColors.outline : HealthColors.primary,
      ));
    }

    switch (status) {
      case TreatmentStatus.active:
        final next = t.nextDose(now);
        final day = t.currentDay(now);
        final progress = t.totalDays == 0 ? 0.0 : day / t.totalDays;
        children.addAll([
          _posologyBox(t.posology, icon: _formIcons[t.form]),
          if (next != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              decoration: BoxDecoration(
                color: HealthColors.secondaryFixed.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Symbols.alarm, size: 18, color: HealthColors.onSecondaryFixedVariant),
                  const SizedBox(width: 6),
                  Text('Prochaine prise', style: HealthText.labelMd.copyWith(color: HealthColors.onSecondaryFixedVariant, fontWeight: FontWeight.w500)),
                  const Spacer(),
                  Text(formatDoseMoment(next, now: now), style: HealthText.labelMd.copyWith(color: HealthColors.onSecondaryFixed)),
                ],
              ),
            ),
          _progress(
            left: formatHealthRange(t.startDate, t.endDate),
            right: 'Jour $day / ${t.totalDays} (${(progress * 100).round()}%)',
            value: progress,
            height: 8,
          ),
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(
              children: [
                Expanded(
                  child: _SoftButton(
                    onTap: onLogDose,
                    icon: Symbols.check,
                    iconColor: HealthColors.primary,
                    label: t.form.logLabel,
                  ),
                ),
                const SizedBox(width: 4),
                _SoftButton(
                  onTap: onHistory,
                  icon: Symbols.history,
                  foreground: HealthColors.onSurfaceVariant,
                  tooltip: 'Historique complet',
                ),
              ],
            ),
          ),
        ]);
      case TreatmentStatus.completed:
        children.addAll([
          _posologyBox(t.posology),
          _progress(
            left: t.isSingleDay ? 'Administré le ${formatHealthDate(t.startDate)}' : formatHealthRange(t.startDate, t.endDate),
            right: '100% complété',
            value: 1,
            height: 6,
          ),
          if (t.renewalAt != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              decoration: BoxDecoration(color: HealthColors.surfaceHigh, borderRadius: BorderRadius.circular(12)),
              child: Row(
                children: [
                  const Icon(Symbols.event_upcoming, size: 18, color: HealthColors.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text.rich(
                      TextSpan(
                        text: 'Prochain renouvellement : ',
                        style: HealthText.labelSm.copyWith(color: HealthColors.onSurfaceVariant),
                        children: [
                          TextSpan(text: formatApproxMonth(t.renewalAt!), style: const TextStyle(fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: _SoftButton(onTap: onHistory, icon: Symbols.history, label: "Voir l'historique de prise"),
          ),
        ]);
      case TreatmentStatus.stopped:
        children.addAll([
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: HealthColors.surfaceHigh, borderRadius: BorderRadius.circular(12)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Symbols.info, size: 16, color: HealthColors.tertiary),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Arrêt prématuré validé par le praticien',
                        style: HealthText.labelSm.copyWith(color: HealthColors.tertiary),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  [
                    t.posology,
                    'Arrêté prématurément le ${formatShortHealthDate(t.stoppedAt!)}'
                        '${t.stopReason == null ? '.' : ' : ${t.stopReason}'}',
                  ].join(' '),
                  style: HealthText.bodySm.copyWith(height: 1.6),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(
              children: [
                Expanded(child: Text(formatHealthRange(t.startDate, t.stoppedAt!), style: HealthText.bodySm)),
                Text(
                  '${t.daysDoneBeforeStop} jours sur ${t.totalDays}',
                  style: HealthText.labelSm.copyWith(color: HealthColors.outline),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: _SoftButton(
              onTap: onHistory,
              icon: Symbols.assignment_late,
              label: 'Détails et rapport clinique',
              foreground: HealthColors.onSurfaceVariant,
            ),
          ),
        ]);
    }

    return HealthCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < children.length; i++) ...[if (i > 0) const SizedBox(height: 8), children[i]],
        ],
      ),
    );
  }

  static Widget _iconLine(IconData icon, String text, Color iconColor) => Row(
        children: [
          Icon(icon, size: 16, color: iconColor),
          const SizedBox(width: 6),
          Expanded(child: Text(text, style: HealthText.bodySm, overflow: TextOverflow.ellipsis)),
        ],
      );

  static Widget _posologyBox(String posology, {IconData? icon}) => Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: HealthColors.surfaceLow, borderRadius: BorderRadius.circular(12)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (icon != null) ...[
              Row(
                children: [
                  Icon(icon, size: 16, color: HealthColors.secondary),
                  const SizedBox(width: 6),
                  const Text('Posologie prescrite', style: HealthText.labelSm),
                ],
              ),
              const SizedBox(height: 4),
            ],
            Text(posology, style: HealthText.bodySm.copyWith(height: 1.6)),
          ],
        ),
      );

  static Widget _progress({required String left, required String right, required double value, required double height}) =>
      Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(child: Text(left, style: HealthText.bodySm)),
                Text(right, style: HealthText.labelSm.copyWith(color: HealthColors.primary, fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: value.clamp(0, 1),
                minHeight: height,
                color: HealthColors.primary,
                backgroundColor: HealthColors.surfaceContainer,
              ),
            ),
          ],
        ),
      );
}

/// Historique des prises, et pour un traitement en cours : arrêt avec la raison du praticien.
class _HistorySheet extends StatefulWidget {
  const _HistorySheet({required this.petId, required this.treatment});

  final String petId;
  final Treatment treatment;

  @override
  State<_HistorySheet> createState() => _HistorySheetState();
}

class _HistorySheetState extends State<_HistorySheet> {
  final _reason = TextEditingController();
  var _stopping = false;
  var _saving = false;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _stop() async {
    setState(() => _saving = true);
    try {
      await HealthRepository().stopTreatment(widget.petId, widget.treatment.id, _reason.text);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        showHealthToast(context, friendlyHealthError(e), icon: Symbols.error);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.treatment;
    final doses = t.doses.reversed.toList();
    final status = t.status;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.viewInsetsOf(context).bottom + 20),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.75),
        child: ListView(
          shrinkWrap: true,
          children: [
            Text(t.name, style: HealthText.headlineSm),
            const SizedBox(height: 2),
            Text('${t.category} • ${status.label}', style: HealthText.bodySm),
            const SizedBox(height: 12),
            _detail('Posologie prescrite', t.posology),
            if (t.practitioner != null) _detail('Prescrit par', t.practitioner!),
            _detail('Période prévue', formatHealthRange(t.startDate, t.endDate)),
            if (t.doseTimes.isNotEmpty) _detail('Heures de prise', t.doseTimes.join(' • ')),
            if (t.stoppedAt != null)
              _detail('Arrêt', '${formatHealthDate(t.stoppedAt!)}${t.stopReason == null ? '' : ' – ${t.stopReason}'}'),
            const SizedBox(height: 8),
            Text('Prises notées (${doses.length})', style: HealthText.labelLg),
            const SizedBox(height: 6),
            if (doses.isEmpty)
              const Text('Aucune prise notée pour le moment.', style: HealthText.bodyMd)
            else
              for (final d in doses)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      const Icon(Symbols.check_circle, size: 18, color: HealthColors.primary, fill: 1),
                      const SizedBox(width: 8),
                      Text(formatDoseLog(d), style: HealthText.bodyMd.copyWith(color: HealthColors.onSurface)),
                    ],
                  ),
                ),
            if (status == TreatmentStatus.active) ...[
              const SizedBox(height: 16),
              if (!_stopping)
                OutlinedButton.icon(
                  onPressed: () => setState(() => _stopping = true),
                  style: OutlinedButton.styleFrom(foregroundColor: HealthColors.error),
                  icon: const Icon(Symbols.block, size: 18),
                  label: const Text('Arrêter le traitement'),
                )
              else ...[
                const HealthFieldLabel("Raison de l'arrêt (validée par le praticien)", required: true),
                TextField(
                  controller: _reason,
                  autofocus: true,
                  maxLength: 300,
                  minLines: 2,
                  maxLines: 4,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: healthInputDecoration(hint: 'Ex : intolérance gastrique, remplacé par un autre protocole'),
                ),
                const SizedBox(height: 8),
                FilledButton(
                  onPressed: _saving ? null : _stop,
                  style: FilledButton.styleFrom(backgroundColor: HealthColors.error),
                  child: Text(_saving ? 'Enregistrement…' : "Confirmer l'arrêt"),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  static Widget _detail(String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: HealthText.labelSm.copyWith(color: HealthColors.outline)),
            Text(value, style: HealthText.bodyMd.copyWith(color: HealthColors.onSurface)),
          ],
        ),
      );
}
