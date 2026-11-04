import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../../l10n/app_localizations.dart';
import '../../data/health_repository.dart';
import '../../data/health_summary.dart';
import 'health_ui.dart';

/// Tableau du jour, en haut de l'onglet Santé : les prises de tous les animaux à cocher, puis les vaccins
/// en retard et ceux des 30 prochains jours.
///
/// Tout vient de la synthèse déjà chargée : aucun appel en plus. Une prise cochée est envoyée à l'API, qui
/// vide sa synthèse en cache ; [notifyApiDataChanged] relit aussitôt l'onglet.
class HealthTodayCard extends StatefulWidget {
  const HealthTodayCard({super.key, required this.summary, required this.now, required this.onOpenRecord});

  final HealthSummary summary;
  final DateTime now;
  final ValueChanged<String> onOpenRecord;

  @override
  State<HealthTodayCard> createState() => _HealthTodayCardState();
}

class _HealthTodayCardState extends State<HealthTodayCard> {
  // Créé au premier envoi seulement : l'affichage seul n'a pas besoin de Firebase.
  late final _repository = HealthRepository();

  /// Créneaux en cours d'envoi (traitement + heure), pour afficher un indicateur et éviter un double envoi.
  final _sending = <String>{};

  static String _key(DoseSlot slot) => '${slot.petId}/${slot.treatment.id}/${slot.time.toIso8601String()}';

  /// Une prise notée ne s'annule pas (les règles n'acceptent qu'un ajout) : on demande confirmation.
  Future<void> _check(DoseSlot slot) async {
    final l = AppLocalizations.of(context);
    final time = DateFormat.Hm(l.localeName).format(slot.time);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l.healthTodayConfirmTitle),
        content: Text(l.healthTodayConfirmBody(slot.petName, slot.treatment.name, time)),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(l.healthTodayCancel)),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: Text(l.healthTodayConfirm)),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final key = _key(slot);
    setState(() => _sending.add(key));
    try {
      await _repository.logDose(slot.petId, slot.treatment.id, at: slot.logTime(DateTime.now()));
      if (mounted) showHealthToast(context, l.healthTodayDoseSaved);
    } catch (e) {
      if (mounted) showHealthToast(context, friendlyHealthError(e), icon: Symbols.error);
    } finally {
      if (mounted) setState(() => _sending.remove(key));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final now = widget.now;
    final doses = widget.summary.todayDoses(now);
    final vaccines = widget.summary.vaccinesDue(now);
    final hour = DateFormat.Hm(l.localeName);
    final date = DateFormat.yMMMd(l.localeName);

    return HealthCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Symbols.today, color: HealthColors.primary),
              const SizedBox(width: 8),
              Expanded(child: Text(l.healthTodayTitle, style: HealthText.headlineSm)),
              Text(DateFormat.MMMEd(l.localeName).format(now), style: HealthText.bodySm),
            ],
          ),
          const SizedBox(height: 12),
          Text(l.healthTodayDoses, style: HealthText.labelLg),
          const SizedBox(height: 4),
          if (doses.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(l.healthTodayNoDoses, style: HealthText.bodySm),
            )
          else
            for (final slot in doses)
              _DoseRow(
                slot: slot,
                time: hour.format(slot.time),
                sending: _sending.contains(_key(slot)),
                canCheck: slot.canCheck(now),
                onCheck: () => _check(slot),
                onOpen: () => widget.onOpenRecord(slot.petId),
              ),
          const Divider(height: 24),
          Text(l.healthTodayVaccines, style: HealthText.labelLg),
          const SizedBox(height: 4),
          if (vaccines.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(l.healthTodayNoVaccines, style: HealthText.bodySm),
            )
          else
            for (final (pet, vaccine) in vaccines)
              _VaccineRow(
                petName: pet.name,
                vaccine: vaccine.title,
                overdue: vaccine.statusAt(now) == VaccineStatus.overdue,
                when: vaccine.statusAt(now) == VaccineStatus.overdue
                    ? l.healthTodayOverdueSince(date.format(vaccine.dueAt))
                    : l.healthTodayDueOn(date.format(vaccine.dueAt)),
                onTap: () => widget.onOpenRecord(pet.id),
              ),
        ],
      ),
    );
  }
}

class _DoseRow extends StatelessWidget {
  const _DoseRow({
    required this.slot,
    required this.time,
    required this.sending,
    required this.canCheck,
    required this.onCheck,
    required this.onOpen,
  });

  final DoseSlot slot;
  final String time;
  final bool sending;
  final bool canCheck;
  final VoidCallback onCheck;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final Widget trailing;
    if (sending) {
      trailing = const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2));
    } else if (slot.done) {
      trailing = Text(l.healthTodayDone, style: HealthText.labelSm.copyWith(color: HealthColors.emerald700));
    } else if (!canCheck) {
      trailing = Text(l.healthTodayUpcoming, style: HealthText.labelSm.copyWith(color: HealthColors.outline));
    } else {
      trailing = const SizedBox.shrink();
    }

    return InkWell(
      onTap: onOpen,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            Checkbox(
              value: slot.done,
              // Une prise faite ne se décoche pas ; un créneau lointain ne se coche pas encore.
              onChanged: slot.done || !canCheck || sending ? null : (_) => onCheck(),
              activeColor: HealthColors.primaryContainer,
            ),
            SizedBox(
              width: 48,
              child: Text(time, style: HealthText.labelLg.copyWith(fontFeatures: const [FontFeature.tabularFigures()])),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    slot.treatment.name,
                    style: HealthText.labelLg.copyWith(
                      decoration: slot.done ? TextDecoration.lineThrough : null,
                      color: slot.done ? HealthColors.outline : null,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(slot.petName, style: HealthText.bodySm, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            trailing,
          ],
        ),
      ),
    );
  }
}

class _VaccineRow extends StatelessWidget {
  const _VaccineRow({
    required this.petName,
    required this.vaccine,
    required this.overdue,
    required this.when,
    required this.onTap,
  });

  final String petName;
  final String vaccine;
  final bool overdue;
  final String when;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = overdue ? HealthColors.error : HealthColors.amber800;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: overdue ? HealthColors.errorContainer : HealthColors.amber100,
                shape: BoxShape.circle,
              ),
              child: Icon(overdue ? Symbols.warning : Symbols.vaccines, size: 18, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('$petName · $vaccine', style: HealthText.labelLg, overflow: TextOverflow.ellipsis),
                  Text(
                    when,
                    style: HealthText.bodySm.copyWith(color: color, fontWeight: overdue ? FontWeight.w600 : null),
                  ),
                ],
              ),
            ),
            const Icon(Symbols.chevron_right, color: HealthColors.outline),
          ],
        ),
      ),
    );
  }
}
