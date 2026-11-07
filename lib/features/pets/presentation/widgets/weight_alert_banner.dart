import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/routes.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../appointments/data/appointment.dart';
import '../../../appointments/data/appointment_repository.dart';
import '../../../appointments/presentation/appointment_form_screen.dart';
import '../../../services/presentation/service_directory_screen.dart';
import '../../data/pet.dart';
import '../../data/weight_alert.dart';
import '../../data/weight_alert_dismissals.dart';
import '../pet_format.dart';
import '../pet_style.dart';

/// Phrase de l'alerte : « Milo a perdu 12 % en 7 jours (10 kg → 8,8 kg) ».
String weightAlertSummary(AppLocalizations l, Pet pet, WeightAlert alert) {
  final percent = formatKg(l, alert.percent);
  final sentence = switch (alert.kind) {
    WeightAlertKind.loss => l.petsWeightAlertLoss(pet.name, percent, alert.days),
    WeightAlertKind.gain => l.petsWeightAlertGain(pet.name, percent, alert.days),
    WeightAlertKind.check => l.petsWeightAlertCheck(pet.name, percent, alert.days),
  };
  return '$sentence (${l.petsWeightAlertValues(formatKg(l, alert.reference.weightKg), formatKg(l, alert.latest.weightKg))}).';
}

/// Bandeau de la carte Poids : variation anormale, invitation à consulter, et actions.
///
/// Si un rendez-vous vétérinaire est pris pour l'animal après la pesée qui a déclenché l'alerte, le bandeau
/// l'indique à la place des boutons.
class WeightAlertBanner extends StatefulWidget {
  const WeightAlertBanner({super.key, required this.pet, required this.alert});

  final Pet pet;
  final WeightAlert alert;

  @override
  State<WeightAlertBanner> createState() => _WeightAlertBannerState();
}

class _WeightAlertBannerState extends State<WeightAlertBanner> {
  Set<String>? _dismissed;
  late Future<Appointment?> _vetVisit = _findVetVisit();

  @override
  void initState() {
    super.initState();
    _loadDismissals();
    WeightAlertDismissals.changes.addListener(_loadDismissals);
  }

  @override
  void didUpdateWidget(WeightAlertBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.alert.id != widget.alert.id) _vetVisit = _findVetVisit();
  }

  @override
  void dispose() {
    WeightAlertDismissals.changes.removeListener(_loadDismissals);
    super.dispose();
  }

  Future<void> _loadDismissals() async {
    final dismissed = await WeightAlertDismissals.load();
    if (mounted) setState(() => _dismissed = dismissed);
  }

  /// Rendez-vous vétérinaire (prévu ou passé, non annulé) pris pour cet animal depuis la pesée de l'alerte.
  Future<Appointment?> _findVetVisit() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;
    final latest = widget.alert.latest.measuredOn;
    final since = DateTime(latest.year, latest.month, latest.day);
    try {
      final agenda = await AppointmentRepository().watchAgenda(uid).first;
      return agenda.where((a) {
        return a.petId == widget.pet.id &&
            a.type == AppointmentType.vet &&
            a.status != AppointmentStatus.cancelled &&
            !a.startsAt.isBefore(since);
      }).firstOrNull;
    } on Exception {
      return null;
    }
  }

  Future<void> _book() async {
    await Navigator.of(context).pushNamed(AppRoutes.appointmentForm, arguments: AppointmentFormArgs(initialPet: widget.pet.name));
    if (mounted) setState(() => _vetVisit = _findVetVisit());
  }

  void _openVets() {
    final title = AppLocalizations.of(context).navServices;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          appBar: AppBar(title: Text(title)),
          body: const ServicesScreen(initialCategory: 'Vétérinaires'),
        ),
      ),
    );
  }

  void _showSources() {
    final l = AppLocalizations.of(context);
    final threshold = switch (widget.alert.source) {
      WeightAlertSource.vca => l.petsWeightAlertSourceVca,
      WeightAlertSource.aaha => l.petsWeightAlertSourceAaha,
      WeightAlertSource.petcare => l.petsWeightAlertSourcePetcare,
    };
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l.petsWeightAlertSourcesTitle, style: PetText.headlineSm),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l.petsWeightAlertSourcesIntro, style: PetText.bodyMd),
              const SizedBox(height: 12),
              Text(threshold, style: PetText.bodyMd.copyWith(color: PetColors.onSurface)),
              const SizedBox(height: 12),
              for (final source in weightAlertSources)
                InkWell(
                  onTap: () => launchUrl(Uri.parse(source.url), mode: LaunchMode.externalApplication),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        const Icon(Icons.open_in_new, size: 16, color: PetColors.primary),
                        const SizedBox(width: 8),
                        Expanded(child: Text(source.title, style: PetText.labelMd.copyWith(color: PetColors.primary))),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(MaterialLocalizations.of(context).closeButtonLabel),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dismissed = _dismissed;
    if (dismissed == null || dismissed.contains(WeightAlertDismissals.keyFor(widget.pet.id, widget.alert))) {
      return const SizedBox.shrink();
    }
    return FutureBuilder<Appointment?>(
      future: _vetVisit,
      builder: (context, snapshot) {
        final l = AppLocalizations.of(context);
        final visit = snapshot.data;
        if (visit != null) return _booked(l, visit);
        return _warning(l);
      },
    );
  }

  Widget _booked(AppLocalizations l, Appointment visit) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: PetColors.emerald100, borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          const Icon(Icons.event_available, size: 20, color: PetColors.emerald800),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              l.petsWeightAlertBooked(formatLongDate(l, visit.startsAt)),
              style: PetText.labelMd.copyWith(color: PetColors.emerald800),
            ),
          ),
          TextButton(onPressed: _showSources, child: Text(l.petsWeightAlertSources)),
        ],
      ),
    );
  }

  Widget _warning(AppLocalizations l) {
    final consult = widget.alert.level == WeightAlertLevel.consult;
    final background = consult ? PetColors.errorContainer : PetColors.tertiaryFixed;
    final foreground = consult ? PetColors.onErrorContainer : PetColors.onTertiaryFixed;
    final accent = consult ? PetColors.error : PetColors.tertiary;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(consult ? Icons.warning_amber_rounded : Icons.info_outline, size: 20, color: accent),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  consult ? l.petsWeightAlertConsult : l.petsWeightAlertWatch,
                  style: PetText.labelLg.copyWith(color: foreground),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(weightAlertSummary(l, widget.pet, widget.alert), style: PetText.bodyMd.copyWith(color: foreground)),
          const SizedBox(height: 2),
          Text(
            consult ? l.petsWeightAlertAdviceConsult : l.petsWeightAlertAdviceWatch,
            style: PetText.bodyMd.copyWith(color: foreground),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                onPressed: _book,
                style: FilledButton.styleFrom(backgroundColor: accent, minimumSize: const Size(0, 40)),
                icon: const Icon(Icons.event_outlined, size: 18),
                label: Text(l.petsWeightAlertBook),
              ),
              OutlinedButton.icon(
                onPressed: _openVets,
                style: OutlinedButton.styleFrom(
                  foregroundColor: accent,
                  side: BorderSide(color: accent),
                  minimumSize: const Size(0, 40),
                ),
                icon: const Icon(Icons.medical_services_outlined, size: 18),
                label: Text(l.petsWeightAlertVets),
              ),
            ],
          ),
          Row(
            children: [
              Expanded(
                child: Text(l.petsWeightAlertDisclaimer, style: PetText.labelSm.copyWith(color: foreground)),
              ),
              TextButton(
                onPressed: _showSources,
                style: TextButton.styleFrom(foregroundColor: foreground),
                child: Text(l.petsWeightAlertSources),
              ),
              TextButton(
                onPressed: () => WeightAlertDismissals.dismiss(widget.pet.id, widget.alert),
                style: TextButton.styleFrom(foregroundColor: foreground),
                child: Text(l.petsWeightAlertIgnore),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
