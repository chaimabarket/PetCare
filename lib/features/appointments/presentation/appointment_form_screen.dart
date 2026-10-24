import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../profile/data/profile_repository.dart';
import '../data/appointment.dart';
import '../data/appointment_format.dart';
import '../data/appointment_repository.dart';
import '../data/pet_option.dart';
import 'appointment_actions.dart';
import 'widgets/rdv_ui.dart';

/// Ce que l'on passe à l'écran « Nouveau rendez-vous » (route nommée).
class AppointmentFormArgs {
  const AppointmentFormArgs({this.initialDate, this.initialPet, this.reschedule, this.copyFrom});

  /// Reporter un rendez-vous existant (FR-12).
  factory AppointmentFormArgs.reschedule(Appointment a) => AppointmentFormArgs(reschedule: a);

  /// « Reprogrammer » un rendez-vous annulé : nouveau rendez-vous prérempli.
  factory AppointmentFormArgs.copyOf(Appointment a) => AppointmentFormArgs(copyFrom: a);

  final DateTime? initialDate;
  final String? initialPet;
  final Appointment? reschedule;
  final Appointment? copyFrom;
}

/// Créneaux proposés (maquette « Nouveau rendez-vous »).
const _slotTimes = [(9, 0), (10, 30), (14, 0), (15, 30), (16, 30), (17, 30), (18, 30)];
const _durations = [15, 30, 45, 60, 90, 120];
const _reminderChoices = [0, 60, 1440, 2880];

/// Ajouter un rendez-vous personnel, ou reporter un rendez-vous (maquette « Nouveau rendez-vous »).
class AppointmentFormScreen extends StatefulWidget {
  const AppointmentFormScreen({super.key, this.args = const AppointmentFormArgs()});

  final AppointmentFormArgs args;

  @override
  State<AppointmentFormScreen> createState() => _AppointmentFormScreenState();
}

class _AppointmentFormScreenState extends State<AppointmentFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _repository = AppointmentRepository();
  final _uid = FirebaseAuth.instance.currentUser?.uid;
  final _titleController = TextEditingController();
  final _notesController = TextEditingController();
  final _reasonController = TextEditingController();

  late final Stream<List<PetOption>>? _pets = _uid == null ? null : PetDirectory().watch(_uid);
  late final Stream<List<Appointment>>? _agenda = _uid == null ? null : _repository.watchAgenda(_uid);

  PetOption? _pet;
  final List<PetOption> _typedPets = [];
  AppointmentType _type = AppointmentType.personalCare;
  late DateTime _day;
  (int, int)? _slot;
  (int, int)? _conflictSlot;
  int _durationMinutes = 45;
  AppointmentPlace _place = AppointmentPlace.home;
  String _address = '';
  int _reminderMinutes = 1440;
  bool _push = true;
  bool _submitted = false;
  bool _saving = false;
  String? _serverError;

  Appointment? get _rescheduled => widget.args.reschedule;
  bool get _isReschedule => _rescheduled != null;

  @override
  void initState() {
    super.initState();
    final source = widget.args.reschedule ?? widget.args.copyFrom;
    _day = dayOnly(widget.args.initialDate ?? DateTime.now());
    if (_day.isBefore(dayOnly(DateTime.now()))) _day = dayOnly(DateTime.now());

    if (source != null) {
      _pet = PetOption(id: source.petId, name: source.petName, breed: source.petBreed, photoUrl: source.petPhotoUrl);
      _typedPets.add(_pet!);
      _type = AppointmentType.personalChoices.contains(source.type) ? source.type : AppointmentType.other;
      _titleController.text = source.title;
      _notesController.text = source.notes;
      _durationMinutes = source.duration.inMinutes;
      _place = source.place;
      _address = source.location;
      _reminderMinutes = source.reminderMinutes;
      _push = source.pushReminder;
      if (_isReschedule) _day = dayOnly(source.startsAt.isAfter(DateTime.now()) ? source.startsAt : DateTime.now());
    } else if (widget.args.initialPet != null) {
      _pet = PetOption(name: widget.args.initialPet!);
      _typedPets.add(_pet!);
    }

    // Adresse par défaut : la ville du profil.
    if (_address.isEmpty && _uid != null) {
      ProfileRepository().watch(_uid).first.then((profile) {
        if (mounted && _address.isEmpty && profile != null && profile.city.isNotEmpty) {
          setState(() => _address = profile.city);
        }
      }).catchError((Object _) {});
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  DateTime _slotStart((int, int) slot) => DateTime(_day.year, _day.month, _day.day, slot.$1, slot.$2);

  /// Rendez-vous actif du même animal qui chevauche ce créneau (« Créneau en conflit »).
  Appointment? _conflictFor((int, int) slot, List<Appointment> agenda) {
    final pet = _pet;
    if (pet == null) return null;
    final start = _slotStart(slot);
    final end = start.add(Duration(minutes: _durationMinutes));
    for (final a in agenda) {
      if (a.id == _rescheduled?.id || !a.status.isActive || a.ownerId != _uid) continue;
      if (a.petName.toLowerCase() != pet.name.toLowerCase()) continue;
      if (a.overlaps(start, end)) return a;
    }
    return null;
  }

  Future<void> _addOtherPet() async {
    final name = await showDialog<String>(context: context, builder: (_) => const _OtherPetDialog());
    if (name == null || name.trim().isEmpty) return;
    setState(() {
      final pet = PetOption(name: name.trim());
      if (!_typedPets.contains(pet)) _typedPets.add(pet);
      _pet = pet;
      _conflictSlot = null;
    });
  }

  Future<void> _editAddress() async {
    final value = await showDialog<String>(
      context: context,
      builder: (_) => _AddressDialog(initial: _address),
    );
    if (value != null) setState(() => _address = value.trim());
  }

  Future<void> _pickDate() async {
    final picked = await showModalBottomSheet<DateTime>(
      context: context,
      backgroundColor: Colors.white,
      showDragHandle: true,
      builder: (_) => _MonthPicker(initial: _day),
    );
    if (picked != null) setState(() => _selectDay(picked));
  }

  void _selectDay(DateTime day) {
    _day = dayOnly(day);
    _slot = null;
    _conflictSlot = null;
  }

  Future<void> _pickDuration() async {
    final picked = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: Colors.white,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Durée du rendez-vous', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            for (final m in _durations)
              ListTile(
                title: Text(formatDuration(Duration(minutes: m))),
                trailing: m == _durationMinutes ? const Icon(Icons.check, color: RdvColors.primary) : null,
                onTap: () => Navigator.of(context).pop(m),
              ),
          ],
        ),
      ),
    );
    if (picked != null) {
      setState(() {
        _durationMinutes = picked;
        _slot = null;
        _conflictSlot = null;
      });
    }
  }

  Future<void> _save() async {
    setState(() {
      _submitted = true;
      _serverError = null;
    });
    final formOk = _formKey.currentState!.validate();
    if (!formOk || _pet == null || _slot == null) return;

    setState(() => _saving = true);
    try {
      final start = _slotStart(_slot!);
      if (_isReschedule) {
        await _repository.reschedule(_rescheduled!, newStart: start, reason: _reasonController.text);
        if (mounted) Navigator.of(context).pop(true);
      } else {
        await _repository.createPersonal(
          petName: _pet!.name,
          petId: _pet!.id,
          petBreed: _pet!.breed,
          petPhotoUrl: _pet!.photoUrl,
          title: _titleController.text,
          type: _type,
          startsAt: start,
          duration: Duration(minutes: _durationMinutes),
          place: _place,
          location: _address,
          notes: _notesController.text,
          reminderMinutes: _reminderMinutes,
          pushReminder: _push,
        );
        if (mounted) {
          showRdvMessage(context, 'Rendez-vous enregistré dans votre agenda.');
          Navigator.of(context).pop(true);
        }
      }
    } catch (e) {
      // Les valeurs saisies restent : seule l'erreur s'affiche, près du bouton.
      if (mounted) setState(() => _serverError = friendlyError(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: RdvColors.surface,
      appBar: AppBar(
        backgroundColor: RdvColors.surface,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          tooltip: 'Retour',
          icon: const Icon(Icons.arrow_back, color: RdvColors.onSurface),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text(
          _isReschedule ? 'Reporter Le Rendez Vous' : 'Nouveau Rendez Vous',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: RdvColors.onSurface),
        ),
        actions: [
          IconButton(
            tooltip: 'Fermer',
            icon: const Icon(Icons.close, color: RdvColors.onSurfaceVariant),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          const Padding(padding: EdgeInsets.only(right: 12), child: RdvProfileButton()),
        ],
      ),
      body: StreamBuilder<List<Appointment>>(
        stream: _agenda,
        builder: (context, agendaSnap) {
          final agenda = agendaSnap.data ?? const <Appointment>[];
          return StreamBuilder<List<PetOption>>(
            stream: _pets,
            builder: (context, petSnap) {
              final pets = _petChoices(petSnap.data ?? const [], agenda);
              return Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  children: _sections(pets, agenda),
                ),
              );
            },
          );
        },
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_serverError != null) ...[
                _ErrorBanner(title: 'Enregistrement impossible', message: _serverError!),
                const SizedBox(height: 8),
              ],
              Row(
                children: [
                  Expanded(
                    child: SoftButton(
                      label: 'Annuler',
                      icon: Icons.close,
                      height: 52,
                      onPressed: _saving ? null : () => Navigator.of(context).maybePop(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: FilledButton.icon(
                      onPressed: _saving ? null : _save,
                      style: FilledButton.styleFrom(
                        backgroundColor: RdvColors.primary,
                        minimumSize: const Size(0, 52),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      icon: _saving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.check_circle_outline),
                      label: Text(
                        _isReschedule ? 'Enregistrer le report' : 'Enregistrer le rendez-vous',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Animaux du module 1, puis ceux déjà vus dans l'agenda, puis ceux saisis à la main.
  List<PetOption> _petChoices(List<PetOption> fromPets, List<Appointment> agenda) {
    final result = <PetOption>[...fromPets];
    bool known(String name) => result.any((p) => p.name.toLowerCase() == name.toLowerCase());
    for (final a in agenda.where((a) => a.ownerId == _uid)) {
      if (!known(a.petName)) {
        result.add(PetOption(id: a.petId, name: a.petName, breed: a.petBreed, photoUrl: a.petPhotoUrl));
      }
    }
    for (final p in _typedPets) {
      if (!known(p.name)) result.add(p);
    }
    return result;
  }

  List<Widget> _sections(List<PetOption> pets, List<Appointment> agenda) {
    final locked = _isReschedule;
    final today = dayOnly(DateTime.now());
    final quickDays = [for (var i = 0; i < 4; i++) today.add(Duration(days: i))];
    final freeSlots = _slotTimes.where((s) => _slotStart(s).isAfter(DateTime.now()) && _conflictFor(s, agenda) == null).toList();
    final recommended = freeSlots.isEmpty ? null : freeSlots.first;
    final conflict = _conflictSlot == null ? null : _conflictFor(_conflictSlot!, agenda);

    return [
      // Bandeau d'introduction
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: RdvColors.surfaceContainer, borderRadius: BorderRadius.circular(16)),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.7), borderRadius: BorderRadius.circular(14)),
              child: const Icon(Icons.event_available_outlined, color: RdvColors.primary),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    locked ? 'Choisir un nouvel horaire' : 'Prendre soin de vos proches',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: RdvColors.primary),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    locked
                        ? "L'ancien horaire reste dans l'historique du rendez-vous et le rappel est recalculé."
                        : "Programmez un soin personnel, une séance d'éducation ou une visite de contrôle à "
                            'domicile pour votre compagnon en toute sérénité.',
                    style: const TextStyle(fontSize: 14, height: 1.4, color: RdvColors.onSurface),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 24),

      // Animal concerné
      FieldLabel(
        'Animal concerné',
        required: true,
        trailing: Text(
          pets.length <= 1 ? '${pets.length} compagnon enregistré' : '${pets.length} compagnons enregistrés',
          style: const TextStyle(fontSize: 12, color: RdvColors.onSurfaceVariant),
        ),
      ),
      SizedBox(
        height: 128,
        child: ListView(
          scrollDirection: Axis.horizontal,
          children: [
            for (final pet in pets)
              Padding(
                padding: const EdgeInsets.only(right: 10),
                child: _PetChoice(
                  pet: pet,
                  selected: _pet?.name.toLowerCase() == pet.name.toLowerCase(),
                  onTap: locked
                      ? null
                      : () => setState(() {
                            _pet = pet;
                            _conflictSlot = null;
                          }),
                ),
              ),
            if (!locked) _OtherPetCard(onTap: _addOtherPet),
          ],
        ),
      ),
      if (_submitted && _pet == null) const _FieldError("Choisissez l'animal concerné."),
      const SizedBox(height: 20),

      // Type de rendez-vous
      const FieldLabel('Type de rendez-vous', required: true),
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final type in AppointmentType.personalChoices)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: RdvChip(
                  label: type.label,
                  selected: _type == type,
                  leading: _type == type ? Icon(appointmentTypeIcon(type), size: 18, color: Colors.white) : null,
                  onTap: locked ? () {} : () => setState(() => _type = type),
                ),
              ),
          ],
        ),
      ),
      const SizedBox(height: 20),

      // Intitulé
      const FieldLabel('Intitulé du rendez-vous', required: true),
      TextFormField(
        controller: _titleController,
        enabled: !locked,
        maxLength: 120,
        textCapitalization: TextCapitalization.sentences,
        decoration: _inputDecoration(hint: 'Ex. Brossage approfondi & coupe des griffes', icon: Icons.brush_outlined),
        validator: (value) {
          if (value == null || value.trim().isEmpty) return "L'intitulé est obligatoire.";
          return null;
        },
      ),
      const SizedBox(height: 8),

      // Date souhaitée
      FieldLabel(
        'Date souhaitée',
        required: true,
        trailing: TextButton.icon(
          onPressed: _pickDate,
          style: TextButton.styleFrom(
            foregroundColor: RdvColors.primaryContainer,
            padding: EdgeInsets.zero,
            visualDensity: VisualDensity.compact,
          ),
          icon: const Icon(Icons.calendar_month_outlined, size: 16),
          label: const Text('Calendrier complet', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        ),
      ),
      Row(
        children: [
          for (var i = 0; i < quickDays.length; i++)
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(right: i == quickDays.length - 1 ? 0 : 6),
                child: _DayChip(
                  label: switch (i) { 0 => "Aujourd'hui", 1 => 'Demain', _ => formatDayMonth(quickDays[i]) },
                  selected: isSameDay(_day, quickDays[i]),
                  onTap: () => setState(() => _selectDay(quickDays[i])),
                ),
              ),
            ),
        ],
      ),
      const SizedBox(height: 10),
      Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: _pickDate,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(color: RdvColors.surfaceContainer, borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.calendar_today_outlined, color: RdvColors.primary, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(formatLongDate(_day), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                      Text(
                        'Semaine ${isoWeekNumber(_day)} • ${_availabilityLabel(freeSlots.length)}',
                        style: const TextStyle(fontSize: 12, color: RdvColors.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.expand_more, color: RdvColors.onSurfaceVariant),
              ],
            ),
          ),
        ),
      ),
      const SizedBox(height: 20),

      // Créneau horaire
      FieldLabel(
        'Sélection du créneau horaire',
        required: true,
        trailing: InkWell(
          onTap: _pickDuration,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.schedule, size: 15, color: RdvColors.onSurfaceVariant),
              const SizedBox(width: 4),
              Text(
                'Durée : ${formatDuration(Duration(minutes: _durationMinutes))}',
                style: const TextStyle(fontSize: 12, color: RdvColors.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
      ..._slotRows(agenda, recommended, conflict),
      if (_submitted && _slot == null) const _FieldError('Choisissez un créneau horaire.'),
      const SizedBox(height: 20),

      if (locked) ...[
        const FieldLabel('Motif du report', required: true),
        TextFormField(
          controller: _reasonController,
          maxLength: 300,
          maxLines: 3,
          minLines: 2,
          textCapitalization: TextCapitalization.sentences,
          decoration: _inputDecoration(hint: 'Ex. Empêchement professionnel'),
          validator: (value) => (value == null || value.trim().length < 3)
              ? 'Expliquez brièvement le motif (3 caractères minimum).'
              : null,
        ),
      ] else ...[
        // Lieu
        const FieldLabel('Lieu du rendez-vous'),
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(color: RdvColors.surfaceHigh, borderRadius: BorderRadius.circular(12)),
          child: Row(
            children: [
              for (final place in AppointmentPlace.values)
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _place = place),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: _place == place ? Colors.white : Colors.transparent,
                        borderRadius: BorderRadius.circular(9),
                        boxShadow: _place == place ? RdvColors.cardShadow : null,
                      ),
                      child: Text(
                        place.label,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: _place == place ? FontWeight.w600 : FontWeight.w500,
                          color: RdvColors.onSurface,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        RdvCard(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(color: RdvColors.secondaryFixed, borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.home_work_outlined, color: RdvColors.secondary, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _place == AppointmentPlace.home ? 'Adresse enregistrée' : 'Adresse',
                      style: const TextStyle(fontSize: 12, color: RdvColors.onSurfaceVariant),
                    ),
                    Text(
                      _address.isEmpty ? 'Aucune adresse' : _address,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: _editAddress,
                style: TextButton.styleFrom(foregroundColor: RdvColors.primaryContainer),
                child: const Text('Modifier', style: TextStyle(fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Notes
        const FieldLabel(
          'Notes personnelles & matériel',
          trailing: Text('Optionnel', style: TextStyle(fontSize: 12, color: RdvColors.onSurfaceVariant)),
        ),
        TextFormField(
          controller: _notesController,
          maxLength: 1000,
          minLines: 3,
          maxLines: 5,
          textCapitalization: TextCapitalization.sentences,
          decoration: _inputDecoration(hint: 'Ex. Prévoir serviette absorbante et friandises.'),
        ),
        const SizedBox(height: 12),

        // Rappels
        const FieldLabel('Rappels et notifications'),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final minutes in _reminderChoices)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: RdvChip(
                    label: formatReminderOffset(minutes),
                    selected: _reminderMinutes == minutes,
                    selectedColor: RdvColors.primary,
                    leading: _reminderMinutes == minutes ? const Icon(Icons.check, size: 16, color: Colors.white) : null,
                    onTap: () => setState(() => _reminderMinutes = minutes),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        RdvCard(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(color: RdvColors.surfaceContainer, borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.notifications_active_outlined, color: RdvColors.primary, size: 22),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Notification Push & SMS', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                    Text(
                      'Alerte directe sur mobile et par message',
                      style: TextStyle(fontSize: 12, color: RdvColors.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              Switch(
                value: _push && _reminderMinutes > 0,
                activeTrackColor: RdvColors.primary,
                onChanged: _reminderMinutes == 0 ? null : (v) => setState(() => _push = v),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (_pet != null) _LastCareNote(pet: _pet!, agenda: agenda, ownerId: _uid),
      ],
    ];
  }

  String _availabilityLabel(int free) {
    if (free == _slotTimes.length) return 'Disponible toute la journée';
    if (free == 0) return 'Aucun créneau disponible';
    return free == 1 ? '1 créneau disponible' : '$free créneaux disponibles';
  }

  /// Grille de créneaux par lignes de 3, avec le bandeau rouge sous la ligne du créneau en conflit.
  List<Widget> _slotRows(List<Appointment> agenda, (int, int)? recommended, Appointment? conflict) {
    final rows = <Widget>[];
    for (var i = 0; i < _slotTimes.length; i += 3) {
      final rowSlots = _slotTimes.skip(i).take(3).toList();
      rows.add(Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          children: [
            for (var j = 0; j < 3; j++)
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: j == 2 ? 0 : 8),
                  child: j < rowSlots.length ? _slotTile(rowSlots[j], agenda, recommended) : const SizedBox.shrink(),
                ),
              ),
          ],
        ),
      ));
      if (conflict != null && rowSlots.contains(_conflictSlot)) {
        rows.add(Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: _ErrorBanner(
            title: '${_formatSlot(_conflictSlot!)} — Créneau en conflit',
            badge: 'Indisponible',
            message: "Conflit d'agenda : ${_pet!.name} a déjà « ${conflict.title} » prévu à "
                '${formatTime(conflict.startsAt)}${conflict.providerName == null ? '' : ' chez ${conflict.providerName}'}.',
          ),
        ));
      }
    }
    return rows;
  }

  Widget _slotTile((int, int) slot, List<Appointment> agenda, (int, int)? recommended) {
    final past = !_slotStart(slot).isAfter(DateTime.now());
    final busy = _conflictFor(slot, agenda) != null;
    final selected = _slot == slot;

    final Color bg;
    final Color fg;
    if (selected) {
      bg = RdvColors.primary;
      fg = Colors.white;
    } else if (past || busy) {
      bg = RdvColors.surfaceHigh;
      fg = RdvColors.outline;
    } else {
      bg = Colors.white;
      fg = RdvColors.onSurface;
    }

    final subtitle = past
        ? 'PASSÉ'
        : busy
            ? 'OCCUPÉ'
            : slot == recommended
                ? 'Recommandé'
                : null;

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(14),
      elevation: selected || past || busy ? 0 : 0.5,
      shadowColor: Colors.black12,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: past
            ? null
            : () => setState(() {
                  if (busy) {
                    _conflictSlot = slot;
                  } else {
                    _slot = slot;
                    _conflictSlot = null;
                  }
                }),
        child: SizedBox(
          height: 52,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(_formatSlot(slot), style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: fg)),
              if (subtitle != null)
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: 0.4, color: fg),
                ),
            ],
          ),
        ),
      ),
    );
  }

  static String _formatSlot((int, int) slot) =>
      '${slot.$1.toString().padLeft(2, '0')}:${slot.$2.toString().padLeft(2, '0')}';

  static InputDecoration _inputDecoration({required String hint, IconData? icon}) => InputDecoration(
        hintText: hint,
        counterText: '',
        filled: true,
        fillColor: Colors.white,
        prefixIcon: icon == null ? null : Icon(icon, size: 20),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: RdvColors.primaryContainer, width: 2),
        ),
      );
}

class _PetChoice extends StatelessWidget {
  const _PetChoice({required this.pet, required this.selected, required this.onTap});

  final PetOption pet;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 108,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Material(
            color: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: selected ? RdvColors.primary : RdvColors.outlineVariant.withValues(alpha: 0.5),
                width: selected ? 2 : 1,
              ),
            ),
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    PetAvatar(name: pet.name, photoUrl: pet.photoUrl, size: 56, badge: false),
                    const SizedBox(height: 8),
                    Text(
                      pet.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                    Text(
                      pet.breed ?? ' ',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, color: RdvColors.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (selected)
            Positioned(
              right: 6,
              top: 6,
              child: Container(
                width: 22,
                height: 22,
                decoration: const BoxDecoration(color: RdvColors.primary, shape: BoxShape.circle),
                child: const Icon(Icons.check, size: 14, color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }
}

class _OtherPetCard extends StatelessWidget {
  const _OtherPetCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 108,
      child: Material(
        color: RdvColors.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: RdvColors.surfaceHighest,
                child: Icon(Icons.add, color: RdvColors.onSurfaceVariant),
              ),
              SizedBox(height: 8),
              Text(
                'Autre\ncompagnon',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: RdvColors.onSurface),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DayChip extends StatelessWidget {
  const _DayChip({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? RdvColors.primary : Colors.white,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: SizedBox(
          height: 38,
          child: Center(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : RdvColors.onSurface,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.title, required this.message, this.badge});

  final String title;
  final String message;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: RdvColors.errorContainer, borderRadius: BorderRadius.circular(14)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline, color: RdvColors.error, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: RdvColors.onErrorContainer),
                      ),
                    ),
                    if (badge != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(color: RdvColors.error, borderRadius: BorderRadius.circular(999)),
                        child: Text(badge!, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white)),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(message, style: const TextStyle(fontSize: 13, color: RdvColors.onErrorContainer)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FieldError extends StatelessWidget {
  const _FieldError(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6, left: 4),
      child: Text(text, style: const TextStyle(fontSize: 12, color: RdvColors.error)),
    );
  }
}

/// « Dernier soin personnel pour Milo effectué il y a 3 semaines. »
class _LastCareNote extends StatelessWidget {
  const _LastCareNote({required this.pet, required this.agenda, required this.ownerId});

  final PetOption pet;
  final List<Appointment> agenda;
  final String? ownerId;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final past = agenda
        .where((a) =>
            a.ownerId == ownerId &&
            !a.isBooking &&
            a.status != AppointmentStatus.cancelled &&
            a.petName.toLowerCase() == pet.name.toLowerCase() &&
            a.endsAt.isBefore(now))
        .toList()
      ..sort((a, b) => b.startsAt.compareTo(a.startsAt));

    final String text;
    if (past.isEmpty) {
      text = 'Premier soin personnel enregistré pour ${pet.name} dans PetCare.';
    } else {
      final days = now.difference(past.first.startsAt).inDays;
      final ago = days < 1
          ? "aujourd'hui"
          : days < 7
              ? 'il y a $days jour${days > 1 ? 's' : ''}'
              : 'il y a ${days ~/ 7} semaine${days ~/ 7 > 1 ? 's' : ''}';
      text = 'Dernier soin personnel pour ${pet.name} effectué $ago. Tout est en ordre !';
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: RdvColors.surfaceLow, borderRadius: BorderRadius.circular(14)),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: const BoxDecoration(color: RdvColors.secondaryContainer, shape: BoxShape.circle),
            child: const Icon(Icons.pets, size: 18, color: RdvColors.onSecondaryContainer),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 13, color: RdvColors.onSurface))),
        ],
      ),
    );
  }
}

class _OtherPetDialog extends StatefulWidget {
  const _OtherPetDialog();

  @override
  State<_OtherPetDialog> createState() => _OtherPetDialogState();
}

class _OtherPetDialogState extends State<_OtherPetDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Autre compagnon'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        maxLength: 80,
        textCapitalization: TextCapitalization.words,
        decoration: const InputDecoration(labelText: "Nom de l'animal"),
        onSubmitted: (v) => Navigator.of(context).pop(v),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Annuler')),
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
          onPressed: () => Navigator.of(context).pop(_controller.text),
          child: const Text('Ajouter'),
        ),
      ],
    );
  }
}

class _AddressDialog extends StatefulWidget {
  const _AddressDialog({required this.initial});

  final String initial;

  @override
  State<_AddressDialog> createState() => _AddressDialogState();
}

class _AddressDialogState extends State<_AddressDialog> {
  late final _controller = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Adresse du rendez-vous'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        maxLength: 160,
        decoration: const InputDecoration(labelText: 'Adresse'),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Annuler')),
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
          onPressed: () => Navigator.of(context).pop(_controller.text),
          child: const Text('Enregistrer'),
        ),
      ],
    );
  }
}

/// « Calendrier complet » : choix d'un jour à partir d'aujourd'hui.
class _MonthPicker extends StatefulWidget {
  const _MonthPicker({required this.initial});

  final DateTime initial;

  @override
  State<_MonthPicker> createState() => _MonthPickerState();
}

class _MonthPickerState extends State<_MonthPicker> {
  late DateTime _month = DateTime(widget.initial.year, widget.initial.month);

  @override
  Widget build(BuildContext context) {
    final today = dayOnly(DateTime.now());
    final daysInMonth = DateTime(_month.year, _month.month + 1, 0).day;
    final leading = DateTime(_month.year, _month.month, 1).weekday % 7;
    final canGoBack = DateTime(_month.year, _month.month).isAfter(DateTime(today.year, today.month));

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                IconButton(
                  onPressed: canGoBack ? () => setState(() => _month = DateTime(_month.year, _month.month - 1)) : null,
                  icon: const Icon(Icons.chevron_left),
                ),
                Expanded(
                  child: Text(
                    formatMonthYear(_month),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                  ),
                ),
                IconButton(
                  onPressed: () => setState(() => _month = DateTime(_month.year, _month.month + 1)),
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
            Row(
              children: [
                for (final d in const ['D', 'L', 'M', 'M', 'J', 'V', 'S'])
                  Expanded(
                    child: Center(
                      child: Text(d, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: RdvColors.outline)),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: leading + daysInMonth,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 7, mainAxisExtent: 42),
              itemBuilder: (context, index) {
                if (index < leading) return const SizedBox.shrink();
                final day = DateTime(_month.year, _month.month, index - leading + 1);
                final disabled = day.isBefore(today);
                final selected = isSameDay(day, widget.initial);
                return InkWell(
                  onTap: disabled ? null : () => Navigator.of(context).pop(day),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    margin: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: selected ? RdvColors.primary : null,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(
                      child: Text(
                        '${day.day}',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: selected
                              ? Colors.white
                              : disabled
                                  ? RdvColors.outlineVariant
                                  : RdvColors.onSurface,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
