import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/routes.dart';
import '../../appointments/presentation/appointment_form_screen.dart';
import '../data/health_entry.dart';
import '../data/health_format.dart';
import '../data/health_pet.dart';
import '../data/health_repository.dart';
import '../data/treatment.dart';
import 'widgets/attachment_viewer.dart';
import 'widgets/health_ui.dart';

/// Filtres de l'historique médical (puces horizontales de la maquette).
enum _RecordFilter {
  all('Tous'),
  visit('Visites'),
  vaccine('Vaccins'),
  treatment('Traitements'),
  allergy('Allergies'),
  exam('Examens'),
  note('Notes');

  const _RecordFilter(this.label);

  final String label;
}

/// Carnet de santé d'un animal (maquette Stitch « Carnet de santé – Milo »).
///
/// Ouvert depuis la fiche de l'animal (module 1) ou l'Accueil : `AppRoutes.healthRecord`
/// avec l'identifiant de l'animal en argument.
class HealthRecordScreen extends StatefulWidget {
  const HealthRecordScreen({super.key, required this.petId});

  final String petId;

  @override
  State<HealthRecordScreen> createState() => _HealthRecordScreenState();
}

class _HealthRecordScreenState extends State<HealthRecordScreen> {
  final _repository = HealthRepository();
  late final _petStream = _repository.watchPet(widget.petId);
  late final _entriesStream = _repository.watchEntries(widget.petId);
  late final _treatmentsStream = _repository.watchTreatments(widget.petId);

  var _filter = _RecordFilter.all;
  HealthPet? _pet;
  List<HealthEntry> _entries = const [];
  List<Treatment> _treatments = const [];

  Future<void> _addEntry() async {
    final saved = await pushHealthRoute<bool>(context, AppRoutes.healthEntryForm, arguments: widget.petId);
    if (saved == true && mounted) {
      showHealthToast(context, 'Soin médical de ${_pet?.name ?? "votre animal"} enregistré avec succès.', icon: Symbols.verified);
    }
  }

  void _openTreatments() => pushHealthRoute<void>(context, AppRoutes.treatments, arguments: widget.petId);

  Future<void> _bookReminder(HealthEntry entry) => pushHealthRoute<void>(
        context,
        AppRoutes.appointmentForm,
        arguments: AppointmentFormArgs(initialDate: entry.nextReminderAt, initialPet: _pet?.name),
      );

  Future<void> _markReminderDone(HealthEntry entry) async {
    try {
      await _repository.markReminderDone(widget.petId, entry.id);
      if (mounted) showHealthToast(context, 'Rappel marqué comme effectué.');
    } catch (e) {
      if (mounted) showHealthToast(context, friendlyHealthError(e), icon: Symbols.error);
    }
  }

  Future<void> _openAttachment(HealthEntry entry, int index) => openHealthAttachment(
        context,
        petId: widget.petId,
        entryId: entry.id,
        index: index,
        attachment: entry.attachments[index],
      );

  /// Résumé texte du carnet : enregistré sur le téléphone (⤓) ou copié pour le partager.
  String _summary() {
    final pet = _pet;
    final buffer = StringBuffer()
      ..writeln('Carnet de santé – ${pet?.name ?? ''}')
      ..writeln(pet?.breedAndAge() ?? '');
    if (pet?.chipNumber != null) buffer.writeln('ICAD : ${pet!.chipNumber}');
    buffer
      ..writeln()
      ..writeln('Historique médical');
    for (final e in _entries) {
      buffer.writeln('- ${formatHealthDate(e.date)} · ${e.type.cardLabel} · ${e.title}'
          '${e.practitioner == null ? '' : ' · ${e.practitioner}'}');
      if (e.description != null) buffer.writeln('  ${e.description}');
      if (e.type == HealthEntryType.vaccine) {
        buffer.writeln('  Lot : ${e.batchNumber ?? '—'} · Prochain rappel : '
            '${e.nextReminderAt == null ? '—' : formatHealthDate(e.nextReminderAt!)}');
      }
    }
    if (_treatments.isNotEmpty) {
      buffer
        ..writeln()
        ..writeln('Traitements');
      for (final t in _treatments) {
        buffer
          ..writeln('- ${t.name} (${t.status.label}) · ${formatHealthRange(t.startDate, t.endDate)}')
          ..writeln('  ${t.posology}');
      }
    }
    return buffer.toString();
  }

  Future<void> _export() async {
    final name = 'Carnet_${(_pet?.name ?? 'animal').replaceAll(' ', '_')}.txt';
    try {
      final uri = await FilePicker.saveFile(
        fileName: name,
        bytes: Uint8List.fromList(utf8.encode(_summary())),
        mimeType: 'text/plain',
      );
      if (uri != null && mounted) showHealthToast(context, 'Téléchargement de : $name');
    } catch (e) {
      if (mounted) showHealthToast(context, friendlyHealthError(e), icon: Symbols.error);
    }
  }

  Future<void> _share() async {
    await Clipboard.setData(ClipboardData(text: _summary()));
    if (mounted) showHealthToast(context, 'Résumé du carnet copié : collez-le pour le partager.');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HealthColors.surface,
      appBar: HealthAppBar(
        title: 'Mes Animaux',
        actions: [
          IconButton(
            tooltip: 'Partager ou exporter',
            onPressed: _share,
            icon: const Icon(Symbols.ios_share, size: 22, color: HealthColors.onSurface),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addEntry,
        backgroundColor: HealthColors.primary,
        foregroundColor: Colors.white,
        elevation: 4,
        shape: const StadiumBorder(),
        icon: const Icon(Symbols.add, size: 22),
        label: const Text('Ajouter un soin', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
      ),
      bottomNavigationBar: const HealthBottomBar(selectedIndex: 1),
      body: StreamBuilder<HealthPet?>(
        stream: _petStream,
        builder: (context, petSnap) {
          if (petSnap.hasError) {
            return _Message(
              icon: Symbols.lock,
              title: 'Carnet inaccessible',
              message: friendlyHealthError(petSnap.error!),
            );
          }
          if (petSnap.connectionState == ConnectionState.waiting && !petSnap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final pet = petSnap.data;
          if (pet == null) {
            return const _Message(
              icon: Symbols.pets,
              title: 'Animal introuvable',
              message: "Cette fiche n'existe plus ou a été archivée.",
            );
          }
          _pet = pet;
          return StreamBuilder<List<HealthEntry>>(
            stream: _entriesStream,
            builder: (context, entriesSnap) => StreamBuilder<List<Treatment>>(
              stream: _treatmentsStream,
              builder: (context, treatmentsSnap) {
                final error = entriesSnap.error ?? treatmentsSnap.error;
                _entries = entriesSnap.data ?? const [];
                _treatments = treatmentsSnap.data ?? const [];
                return _buildContent(pet, error, loading: !entriesSnap.hasData && error == null);
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildContent(HealthPet pet, Object? error, {required bool loading}) {
    final now = DateTime.now();
    final pendingReminders = _entries.where((e) => e.hasPendingReminder).toList()
      ..sort((a, b) => a.nextReminderAt!.compareTo(b.nextReminderAt!));
    final overdue = pendingReminders.any((e) => dayOf(e.nextReminderAt!).isBefore(dayOf(now)));

    final items = <_RecordItem>[
      for (final e in _entries) _RecordItem.entry(e),
      for (final t in _treatments) _RecordItem.treatment(t),
    ]..sort((a, b) => b.date.compareTo(a.date));
    final visible = items.where((i) => i.matches(_filter)).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
      children: [
        _PetHeader(pet: pet, upToDate: !overdue, onExport: _export),
        if (pendingReminders.isNotEmpty) ...[
          const SizedBox(height: 24),
          _ReminderHighlight(
            entry: pendingReminders.first,
            onBook: () => _bookReminder(pendingReminders.first),
            onDone: () => _markReminderDone(pendingReminders.first),
          ),
        ],
        const SizedBox(height: 24),
        Row(
          children: [
            const Expanded(child: Text('Historique médical', style: HealthText.headlineSm)),
            Text(
              items.length <= 1 ? '${items.length} soin récent' : '${items.length} soins récents',
              style: HealthText.bodySm.copyWith(color: HealthColors.outline),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          clipBehavior: Clip.none,
          child: Row(
            children: [
              for (final f in _RecordFilter.values) ...[
                HealthFilterChip(label: f.label, selected: f == _filter, onTap: () => setState(() => _filter = f)),
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
            icon: Symbols.medical_information,
            title: items.isEmpty ? 'Carnet encore vide' : 'Aucun soin dans cette catégorie',
            message: items.isEmpty
                ? 'Ajoutez la première visite, un vaccin ou une allergie de ${pet.name} avec « Ajouter un soin ».'
                : 'Choisissez un autre filtre ou ajoutez un soin.',
          )
        else
          for (final item in visible) ...[
            item.entry != null
                ? _EntryCard(
                    entry: item.entry!,
                    onOpenAttachment: (index) => _openAttachment(item.entry!, index),
                  )
                : _TreatmentRecordCard(treatment: item.treatment!, onOpen: _openTreatments),
            const SizedBox(height: 16),
          ],
        const SizedBox(height: 8),
        const _EmergencyCard(),
      ],
    );
  }
}

/// Un élément de l'historique : un soin du carnet ou un traitement.
class _RecordItem {
  _RecordItem.entry(HealthEntry this.entry)
      : treatment = null,
        date = entry.date;

  _RecordItem.treatment(Treatment this.treatment)
      : entry = null,
        date = treatment.startDate;

  final HealthEntry? entry;
  final Treatment? treatment;
  final DateTime date;

  bool matches(_RecordFilter filter) => switch (filter) {
        _RecordFilter.all => true,
        _RecordFilter.treatment => treatment != null,
        _RecordFilter.visit => entry?.type == HealthEntryType.visit,
        _RecordFilter.vaccine => entry?.type == HealthEntryType.vaccine,
        _RecordFilter.allergy => entry?.type == HealthEntryType.allergy,
        _RecordFilter.exam => entry?.type == HealthEntryType.exam,
        _RecordFilter.note => entry?.type == HealthEntryType.note,
      };
}

class _Message extends StatelessWidget {
  const _Message({required this.icon, required this.title, required this.message});

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [HealthEmptyState(icon: icon, title: title, message: message)],
    );
  }
}

/// 1. En-tête : photo, nom, race et âge, numéro ICAD, confidentialité et état du dossier.
class _PetHeader extends StatelessWidget {
  const _PetHeader({required this.pet, required this.upToDate, required this.onExport});

  final HealthPet pet;
  final bool upToDate;
  final VoidCallback onExport;

  @override
  Widget build(BuildContext context) {
    return HealthCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  HealthPetPhoto(name: pet.name, photo: pet.photo, size: 80),
                  const Positioned(right: 0, bottom: 0, child: HealthPhotoBadge(icon: Symbols.verified, size: 24)),
                ],
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(pet.name, style: HealthText.headlineMd, overflow: TextOverflow.ellipsis),
                        ),
                        Material(
                          color: HealthColors.surfaceLow,
                          shape: const CircleBorder(),
                          child: IconButton(
                            tooltip: 'Exporter le dossier médical',
                            onPressed: onExport,
                            constraints: const BoxConstraints.tightFor(width: 36, height: 36),
                            padding: EdgeInsets.zero,
                            icon: const Icon(Symbols.download, size: 20, color: HealthColors.primary),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(pet.breedAndAge(), style: HealthText.bodyMd, maxLines: 1, overflow: TextOverflow.ellipsis),
                    if (pet.chipNumber != null) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Symbols.fingerprint, size: 15, color: HealthColors.outline),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              'ICAD : ${pet.chipNumber}',
                              style: HealthText.labelSm.copyWith(color: HealthColors.outline, letterSpacing: 0.4),
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
          const SizedBox(height: 16),
          Row(
            children: [
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: HealthColors.surfaceHigh.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Symbols.lock, size: 16, color: HealthColors.primaryContainer),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          'Données santé chiffrées de bout en bout',
                          style: HealthText.labelSm.copyWith(color: HealthColors.primaryContainer),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: upToDate ? HealthColors.primaryContainer : HealthColors.amber800,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                upToDate ? 'Dossier à jour' : 'Rappel en retard',
                style: HealthText.labelSm.copyWith(
                  fontWeight: FontWeight.w600,
                  color: upToDate ? HealthColors.primary : HealthColors.amber800,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 2. Carte « Prochain rappel vaccinal » (fond corail pâle, filigrane seringue).
class _ReminderHighlight extends StatelessWidget {
  const _ReminderHighlight({required this.entry, required this.onBook, required this.onDone});

  final HealthEntry entry;
  final VoidCallback onBook;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final due = entry.nextReminderAt!;
    final days = dayOf(due).difference(dayOf(DateTime.now())).inDays;
    final kicker = days < 0 ? 'Rappel en retard' : (days <= 30 ? 'Échéance imminente' : 'Prochaine échéance');

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: HealthColors.secondaryFixed.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(16),
        boxShadow: HealthColors.cardShadow,
      ),
      child: Stack(
        children: [
          Positioned(
            right: -16,
            bottom: -16,
            child: Icon(Symbols.vaccines, size: 100, color: HealthColors.secondaryContainer.withValues(alpha: 0.2)),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: HealthColors.secondaryContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Symbols.notifications_active, size: 22, color: HealthColors.onSecondaryContainer),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            kicker.toUpperCase(),
                            style: HealthText.labelSm.copyWith(
                              color: HealthColors.secondary,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.8,
                            ),
                          ),
                          const Text('Prochain rappel vaccinal', style: HealthText.headlineSm),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: HealthColors.secondaryContainer,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        formatTimeUntil(due),
                        style: HealthText.labelSm.copyWith(color: HealthColors.onSecondaryContainer),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(entry.vaccineName ?? entry.title, style: HealthText.labelLg),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            formatHealthDate(due),
                            style: HealthText.labelMd.copyWith(color: HealthColors.secondary, fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                      if (entry.practitioner != null) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(Symbols.local_hospital, size: 16, color: HealthColors.secondary),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(entry.practitioner!, style: HealthText.bodySm, overflow: TextOverflow.ellipsis),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 44,
                        child: FilledButton.icon(
                          onPressed: onBook,
                          style: FilledButton.styleFrom(
                            backgroundColor: HealthColors.primary,
                            minimumSize: const Size.fromHeight(44),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                          ),
                          icon: const Icon(Symbols.calendar_add_on, size: 18),
                          label: const Text('Prendre RDV rappel'),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Material(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        onTap: onDone,
                        borderRadius: BorderRadius.circular(12),
                        child: const Tooltip(
                          message: 'Marquer comme déjà effectué',
                          child: SizedBox(
                            width: 48,
                            height: 44,
                            child: Icon(Symbols.done_all, size: 20, color: HealthColors.onSurfaceVariant),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Carte d'historique commune : icône ronde, date • catégorie, titre, pastille, encadré, pied.
class _RecordCard extends StatelessWidget {
  const _RecordCard({
    required this.icon,
    required this.iconBackground,
    required this.iconColor,
    required this.date,
    required this.label,
    required this.labelColor,
    required this.title,
    required this.box,
    required this.footerIcon,
    required this.footerText,
    this.pill,
    this.trailing,
    this.onTap,
  });

  final IconData icon;
  final Color iconBackground;
  final Color iconColor;
  final DateTime date;
  final String label;
  final Color labelColor;
  final String title;
  final Widget? pill;
  final List<Widget> box;
  final IconData footerIcon;
  final String footerText;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return HealthCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(color: iconBackground, shape: BoxShape.circle),
                child: Icon(icon, size: 22, color: iconColor),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(formatHealthDate(date), style: HealthText.labelSm.copyWith(color: HealthColors.outline)),
                        Container(
                          width: 4,
                          height: 4,
                          margin: const EdgeInsets.symmetric(horizontal: 6),
                          decoration: const BoxDecoration(color: HealthColors.outline, shape: BoxShape.circle),
                        ),
                        Flexible(
                          child: Text(
                            label,
                            style: HealthText.labelSm.copyWith(color: labelColor, fontWeight: FontWeight.w600),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    Text(title, style: HealthText.headlineSm.copyWith(height: 1.3)),
                  ],
                ),
              ),
              if (pill != null) ...[const SizedBox(width: 8), pill!],
            ],
          ),
          if (box.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: HealthColors.surfaceLow, borderRadius: BorderRadius.circular(12)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: box),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(footerIcon, size: 16, color: HealthColors.outline),
              const SizedBox(width: 6),
              Expanded(child: Text(footerText, style: HealthText.bodySm)),
              if (trailing != null) ...[const SizedBox(width: 8), trailing!],
            ],
          ),
        ],
      ),
    );
  }
}

Widget _bodyText(String text) =>
    Text(text, style: HealthText.bodyMd.copyWith(height: 1.6));

/// Carte d'un soin du carnet : visite, vaccin, examen, allergie ou note.
class _EntryCard extends StatelessWidget {
  const _EntryCard({required this.entry, required this.onOpenAttachment});

  final HealthEntry entry;
  final ValueChanged<int> onOpenAttachment;

  static const _validated = HealthPill(
    label: 'Validé',
    icon: Symbols.check,
    background: HealthColors.emerald50,
    foreground: HealthColors.emerald700,
  );

  Widget? get _attachmentChip {
    if (entry.attachments.isEmpty) return null;
    return Flexible(
      child: Material(
        color: HealthColors.surfaceHigh,
        borderRadius: BorderRadius.circular(999),
        child: InkWell(
          onTap: () => onOpenAttachment(0),
          borderRadius: BorderRadius.circular(999),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Symbols.attach_file, size: 16, color: HealthColors.primary),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    entry.attachments.length > 1
                        ? '${entry.attachments.first.name} +${entry.attachments.length - 1}'
                        : entry.attachments.first.name,
                    style: HealthText.labelSm,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final practitioner = entry.practitioner;
    switch (entry.type) {
      case HealthEntryType.visit:
      case HealthEntryType.exam:
        final isVisit = entry.type == HealthEntryType.visit;
        return _RecordCard(
          icon: isVisit ? Symbols.stethoscope : Symbols.radiology,
          iconBackground: HealthColors.primaryContainer.withValues(alpha: 0.15),
          iconColor: HealthColors.primaryContainer,
          date: entry.date,
          label: entry.type.cardLabel,
          labelColor: HealthColors.primary,
          title: entry.title,
          pill: practitioner != null || entry.attachments.isNotEmpty ? _validated : null,
          box: [
            if (entry.weightKg != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Row(
                  children: [
                    const Icon(Symbols.scale, size: 16, color: HealthColors.primary),
                    const SizedBox(width: 8),
                    Text(
                      'Poids : ${formatKg(entry.weightKg!).replaceAll('.', ',')} kg',
                      style: HealthText.labelMd.copyWith(color: HealthColors.primary),
                    ),
                    if (entry.weightDeltaKg != null) ...[
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          '(${entry.weightDeltaKg! >= 0 ? '+' : '−'}${(entry.weightDeltaKg!.abs() * 1000).round()}g vs pesée préc.)',
                          style: HealthText.bodySm.copyWith(color: HealthColors.outline),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            if (entry.description != null) _bodyText(entry.description!),
          ],
          footerIcon: Symbols.person_pin,
          footerText: practitioner ?? 'Consigné par le maître',
          trailing: _attachmentChip,
        );
      case HealthEntryType.vaccine:
        final next = entry.nextReminderAt;
        final late = entry.hasPendingReminder && dayOf(next!).isBefore(dayOf(DateTime.now()));
        return _RecordCard(
          icon: Symbols.syringe,
          iconBackground: HealthColors.blue50,
          iconColor: HealthColors.blue700,
          date: entry.date,
          label: entry.type.cardLabel,
          labelColor: HealthColors.blue700,
          title: entry.title,
          pill: late
              ? const HealthPill(
                  label: 'Rappel dépassé',
                  icon: Symbols.warning,
                  background: HealthColors.amber50,
                  foreground: HealthColors.amber800,
                )
              : const HealthPill(
                  label: 'À jour',
                  icon: Symbols.done_all,
                  background: HealthColors.emerald50,
                  foreground: HealthColors.emerald700,
                ),
          box: [
            Row(
              children: [
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      text: 'Lot : ',
                      style: HealthText.labelSm,
                      children: [
                        TextSpan(
                          text: entry.batchNumber ?? '—',
                          style: const TextStyle(fontFamily: 'monospace', color: HealthColors.outline),
                        ),
                      ],
                    ),
                  ),
                ),
                if (next != null)
                  Text(_intervalLabel(entry.date, next), style: HealthText.labelSm.copyWith(color: HealthColors.outline)),
              ],
            ),
            if (entry.description != null) ...[const SizedBox(height: 4), _bodyText(entry.description!)],
          ],
          footerIcon: Symbols.medication,
          footerText: practitioner == null ? 'Administré par le maître' : 'Administré par $practitioner',
          trailing: entry.attachments.isEmpty
              ? null
              : InkWell(
                  onTap: () => onOpenAttachment(0),
                  child: Text('Vignette validée', style: HealthText.labelSm.copyWith(color: HealthColors.outline)),
                ),
        );
      case HealthEntryType.allergy:
        return _RecordCard(
          icon: Symbols.nutrition,
          iconBackground: HealthColors.amber100,
          iconColor: HealthColors.amber800,
          date: entry.date,
          label: entry.type.cardLabel,
          labelColor: HealthColors.amber800,
          title: entry.title,
          pill: const HealthPill(
            label: 'Actif',
            icon: Symbols.warning,
            background: HealthColors.amber50,
            foreground: HealthColors.amber800,
          ),
          box: [if (entry.description != null) _bodyText(entry.description!)],
          footerIcon: Symbols.medical_services,
          footerText: practitioner == null ? 'Déclaré par le maître' : 'Déclaré par $practitioner',
          trailing: _attachmentChip,
        );
      case HealthEntryType.note:
        return _RecordCard(
          icon: Symbols.edit_note,
          iconBackground: HealthColors.surfaceHigh,
          iconColor: HealthColors.onSurfaceVariant,
          date: entry.date,
          label: entry.type.cardLabel,
          labelColor: HealthColors.onSurfaceVariant,
          title: entry.title,
          box: [if (entry.description != null) _bodyText(entry.description!)],
          footerIcon: practitioner == null ? Symbols.home : Symbols.person_pin,
          footerText: practitioner ?? 'Note du maître (Moi-même)',
          trailing: _attachmentChip,
        );
    }
  }

  /// « Rappel annuel », « Rappel tous les 3 ans », « Rappel à 6 mois ».
  static String _intervalLabel(DateTime from, DateTime to) {
    final months = ((to.difference(from).inDays) / 30.4).round();
    if (months >= 11 && months <= 13) return 'Rappel annuel';
    if (months >= 23) return 'Rappel tous les ${(months / 12).round()} ans';
    return 'Rappel à $months mois';
  }
}

/// Carte d'un traitement dans l'historique (ex. « Vermifuge & Tiques Milbemax »).
class _TreatmentRecordCard extends StatelessWidget {
  const _TreatmentRecordCard({required this.treatment, required this.onOpen});

  final Treatment treatment;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final status = treatment.statusAt(now);
    final next = treatment.nextDose(now);
    final parasite = const ['Antiparasitaire', 'Vermifuge'].contains(treatment.category);
    final byOwner = treatment.practitioner == null;

    final HealthPill pill = byOwner
        ? const HealthPill(label: 'Fait maison', background: HealthColors.surfaceHigh, foreground: HealthColors.onSurfaceVariant)
        : switch (status) {
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

    final nextText = next != null
        ? formatDoseMoment(next)
        : (treatment.renewalAt != null && status != TreatmentStatus.stopped ? formatApproxMonth(treatment.renewalAt!) : null);

    return _RecordCard(
      onTap: onOpen,
      icon: parasite ? Symbols.pest_control : Symbols.medication,
      iconBackground: HealthColors.secondaryContainer.withValues(alpha: 0.3),
      iconColor: HealthColors.secondary,
      date: treatment.startDate,
      label: treatment.category,
      labelColor: HealthColors.secondary,
      title: treatment.name,
      pill: pill,
      box: [
        _bodyText(treatment.posology),
        if (nextText != null) ...[
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Symbols.event_repeat, size: 15, color: HealthColors.secondary),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  'Prochaine administration : $nextText',
                  style: HealthText.labelSm.copyWith(color: HealthColors.secondary),
                ),
              ),
            ],
          ),
        ],
      ],
      footerIcon: byOwner ? Symbols.home : Symbols.stethoscope,
      footerText: byOwner ? 'Administré par le maître (Moi-même)' : 'Prescrit par ${treatment.practitioner}',
      trailing: InkWell(
        onTap: onOpen,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Suivi', style: HealthText.labelSm.copyWith(color: HealthColors.primary)),
            const SizedBox(width: 4),
            const Icon(Symbols.open_in_new, size: 14, color: HealthColors.primary),
          ],
        ),
      ),
    );
  }
}

/// Carte « Urgences vétérinaires 24/7 » en bas du carnet.
class _EmergencyCard extends StatelessWidget {
  const _EmergencyCard();

  @override
  Widget build(BuildContext context) {
    return HealthCard(
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(color: HealthColors.errorContainer, shape: BoxShape.circle),
            child: const Icon(Symbols.call, size: 20, color: HealthColors.onErrorContainer),
          ),
          const SizedBox(width: 8),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Urgences vétérinaires 24/7', style: HealthText.labelLg),
                Text('Samu Vétérinaire & Garde régionale', style: HealthText.bodySm),
              ],
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            height: 40,
            child: FilledButton(
              onPressed: () => launchUrl(Uri(scheme: 'tel', path: '3115')),
              style: FilledButton.styleFrom(
                backgroundColor: HealthColors.error,
                minimumSize: const Size(0, 40),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text.rich(
                TextSpan(
                  text: '3115 ',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  children: [
                    TextSpan(text: '(Gratuit)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w400)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
