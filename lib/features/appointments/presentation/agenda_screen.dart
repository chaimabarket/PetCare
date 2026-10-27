import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../core/routes.dart';
import '../../../core/widgets/coming_soon_screen.dart';
import '../data/appointment.dart';
import '../data/appointment_format.dart';
import '../data/appointment_repository.dart';
import '../data/reminder.dart';
import '../data/reminder_repository.dart';
import 'appointment_actions.dart';
import 'appointment_form_screen.dart';
import 'widgets/rdv_ui.dart';

/// Agenda (maquette Stitch « Agenda rendez-vous ») : semaine ou mois, filtres par animal et
/// par statut, rendez-vous et rappels du jour choisi puis du lendemain.
class AgendaScreen extends StatefulWidget {
  const AgendaScreen({super.key, this.initialPet});

  /// Ouvre l'agenda déjà filtré sur un animal (depuis la fiche animal du module 1).
  final String? initialPet;

  @override
  State<AgendaScreen> createState() => _AgendaScreenState();
}

class _AgendaScreenState extends State<AgendaScreen> {
  final _uid = FirebaseAuth.instance.currentUser?.uid;
  late final _appointments = _uid == null ? null : AppointmentRepository().watchAgenda(_uid);
  late final _reminders = _uid == null ? null : ReminderRepository().watch(_uid);

  DateTime _selectedDay = dayOnly(DateTime.now());
  bool _monthView = false;
  String? _pet;
  AppointmentStatus? _status;

  @override
  void initState() {
    super.initState();
    _pet = widget.initialPet;
  }

  void _move(int direction) {
    setState(() {
      _selectedDay = _monthView
          ? DateTime(_selectedDay.year, _selectedDay.month + direction, 1)
          : _selectedDay.add(Duration(days: 7 * direction));
    });
  }

  Future<void> _newAppointment() async {
    await Navigator.of(context).pushNamed(
      AppRoutes.appointmentForm,
      arguments: AppointmentFormArgs(initialDate: _selectedDay, initialPet: _pet),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_uid == null) {
      return const ComingSoonScreen(title: 'Agenda');
    }

    return RdvTabScaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _newAppointment,
        backgroundColor: RdvColors.primary,
        foregroundColor: Colors.white,
        shape: const StadiumBorder(),
        icon: const Icon(Icons.add),
        label: const Text('Rendez-vous', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
      ),
      body: StreamBuilder<List<Appointment>>(
        stream: _appointments,
        builder: (context, apptSnap) {
          return StreamBuilder<List<Reminder>>(
            stream: _reminders,
            builder: (context, remSnap) {
              if (apptSnap.hasError) {
                return _ErrorState(message: friendlyError(apptSnap.error!));
              }
              if (!apptSnap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              return _buildContent(apptSnap.data!, remSnap.data ?? const []);
            },
          );
        },
      ),
    );
  }

  Widget _buildContent(List<Appointment> all, List<Reminder> reminders) {
    // Compteurs des puces (sur tous les rendez-vous de l'animal choisi).
    final forPet = all.where((a) => _pet == null || a.petName == _pet).toList();
    int countStatus(AppointmentStatus s) => forPet.where((a) => a.status == s).length;

    final pets = <String, int>{};
    for (final a in all) {
      pets[a.petName] = (pets[a.petName] ?? 0) + (a.status.isActive ? 1 : 0);
    }
    for (final r in reminders) {
      pets.putIfAbsent(r.petName, () => 0);
    }
    final petPhotos = {for (final a in all) a.petName: a.petPhotoUrl};

    bool keepAppointment(Appointment a) =>
        (_pet == null || a.petName == _pet) && (_status == null || a.status == _status);
    bool keepReminder(Reminder r) => _status == null && (_pet == null || r.petName == _pet) && !r.done;

    List<_AgendaItem> itemsFor(DateTime day) {
      final items = <_AgendaItem>[
        for (final a in all)
          if (isSameDay(a.startsAt, day) && keepAppointment(a)) _AgendaItem.appointment(a),
        for (final r in reminders)
          if (isSameDay(r.dueAt, day) && keepReminder(r)) _AgendaItem.reminder(r),
      ]..sort((a, b) => a.time.compareTo(b.time));
      return items;
    }

    // Points sous chaque jour : la couleur du statut des rendez-vous de ce jour.
    Map<DateTime, Set<Color>> dots = {};
    for (final a in all.where(keepAppointment)) {
      dots.putIfAbsent(dayOnly(a.startsAt), () => {}).add(_statusDotColor(a.status));
    }
    for (final r in reminders.where(keepReminder)) {
      dots.putIfAbsent(dayOnly(r.dueAt), () => {}).add(RdvColors.outlineVariant);
    }

    final today = itemsFor(_selectedDay);
    final nextDay = _selectedDay.add(const Duration(days: 1));
    final tomorrowItems = itemsFor(nextDay);
    final isToday = isSameDay(_selectedDay, DateTime.now());

    return ListView(
      padding: const EdgeInsets.only(bottom: 96),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: _MonthHeader(
            month: _selectedDay,
            monthView: _monthView,
            onPrevious: () => _move(-1),
            onNext: () => _move(1),
            onToggleView: (month) => setState(() => _monthView = month),
          ),
        ),
        if (_monthView)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _MonthGrid(
              month: _selectedDay,
              selected: _selectedDay,
              dots: dots,
              onSelect: (day) => setState(() => _selectedDay = day),
            ),
          )
        else
          _WeekStrip(
            selected: _selectedDay,
            dots: dots,
            onSelect: (day) => setState(() => _selectedDay = day),
          ),
        const SizedBox(height: 12),
        _ChipRow(
          children: [
            RdvChip(
              label: 'Tous les animaux',
              selected: _pet == null,
              leading: Icon(Icons.pets, size: 18, color: _pet == null ? Colors.white : RdvColors.primary),
              onTap: () => setState(() => _pet = null),
            ),
            for (final entry in pets.entries)
              RdvChip(
                label: entry.key,
                selected: _pet == entry.key,
                leading: PetAvatar(name: entry.key, photoUrl: petPhotos[entry.key], size: 26, badge: false),
                trailing: Text(
                  '${entry.value}',
                  style: TextStyle(
                    fontSize: 13,
                    color: _pet == entry.key ? Colors.white70 : RdvColors.outline,
                  ),
                ),
                onTap: () => setState(() => _pet = _pet == entry.key ? null : entry.key),
              ),
          ],
        ),
        const SizedBox(height: 8),
        _ChipRow(
          children: [
            _StatusChip(
              label: 'Tous les statuts',
              selected: _status == null,
              onTap: () => setState(() => _status = null),
            ),
            _StatusChip(
              label: 'Confirmés (${countStatus(AppointmentStatus.confirmed)})',
              dot: RdvColors.primaryContainer,
              selected: _status == AppointmentStatus.confirmed,
              onTap: () => setState(() => _status = AppointmentStatus.confirmed),
            ),
            _StatusChip(
              label: 'En attente (${countStatus(AppointmentStatus.planned)})',
              dot: RdvColors.secondaryContainer,
              selected: _status == AppointmentStatus.planned,
              onTap: () => setState(() => _status = AppointmentStatus.planned),
            ),
            _StatusChip(
              label: 'Annulés',
              dot: RdvColors.error,
              selected: _status == AppointmentStatus.cancelled,
              onTap: () => setState(() => _status = AppointmentStatus.cancelled),
            ),
            _StatusChip(
              label: 'Terminés',
              dot: RdvColors.outline,
              selected: _status == AppointmentStatus.completed,
              onTap: () => setState(() => _status = AppointmentStatus.completed),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      formatLongDate(_selectedDay),
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: RdvColors.onSurface),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _countLabel(today.length),
                      style: const TextStyle(fontSize: 13, color: RdvColors.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              if (isToday)
                StatusPill(
                  label: "Aujourd'hui",
                  background: RdvColors.primaryFixed.withValues(alpha: 0.45),
                  foreground: RdvColors.onPrimaryFixedVariant,
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (today.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _EmptyDay(onAdd: _newAppointment, hasFilters: _pet != null || _status != null),
          )
        else
          for (final item in today)
            Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 16), child: item.build(context)),
        if (tomorrowItems.isNotEmpty) ...[
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    formatDayTitle(nextDay),
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: RdvColors.onSurface),
                  ),
                ),
                Text(
                  formatRelativeDay(nextDay),
                  style: const TextStyle(fontSize: 13, color: RdvColors.onSurfaceVariant),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          for (final item in tomorrowItems)
            Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 16), child: item.build(context)),
        ],
      ],
    );
  }

  static String _countLabel(int n) => switch (n) {
        0 => 'Aucun rendez-vous prévu pour votre foyer',
        1 => '1 rendez-vous prévu pour votre foyer',
        _ => '$n rendez-vous prévus pour votre foyer',
      };
}

Color _statusDotColor(AppointmentStatus status) => switch (status) {
      AppointmentStatus.confirmed => RdvColors.primaryContainer,
      AppointmentStatus.planned => RdvColors.secondaryContainer,
      AppointmentStatus.cancelled => RdvColors.error,
      AppointmentStatus.completed => RdvColors.outline,
    };

/// Un élément de la journée : un rendez-vous ou un rappel de soin.
class _AgendaItem {
  _AgendaItem.appointment(Appointment this.appointment)
      : reminder = null,
        time = appointment.startsAt;

  _AgendaItem.reminder(Reminder this.reminder)
      : appointment = null,
        time = reminder.dueAt;

  final Appointment? appointment;
  final Reminder? reminder;
  final DateTime time;

  Widget build(BuildContext context) {
    final a = appointment;
    if (a != null) {
      return a.status == AppointmentStatus.cancelled
          ? _CancelledCard(appointment: a)
          : AppointmentCard(appointment: a);
    }
    return _ReminderCard(reminder: reminder!);
  }
}

class _ChipRow extends StatelessWidget {
  const _ChipRow({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          for (final child in children) Padding(padding: const EdgeInsets.only(right: 8), child: child),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.selected, required this.onTap, this.dot});

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color? dot;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? RdvColors.surfaceHigh : Colors.white,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (dot != null) ...[
                Container(width: 8, height: 8, decoration: BoxDecoration(color: dot, shape: BoxShape.circle)),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: selected ? RdvColors.onSurface : RdvColors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MonthHeader extends StatelessWidget {
  const _MonthHeader({
    required this.month,
    required this.monthView,
    required this.onPrevious,
    required this.onNext,
    required this.onToggleView,
  });

  final DateTime month;
  final bool monthView;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final ValueChanged<bool> onToggleView;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _RoundIconButton(icon: Icons.chevron_left, tooltip: 'Précédent', onPressed: onPrevious),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            formatMonthYear(month),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: RdvColors.onSurface),
          ),
        ),
        IconButton(
          tooltip: 'Vue mois',
          onPressed: () => onToggleView(!monthView),
          icon: const Icon(Icons.calendar_month_outlined, color: RdvColors.primary, size: 20),
        ),
        _RoundIconButton(icon: Icons.chevron_right, tooltip: 'Suivant', onPressed: onNext),
        const Spacer(),
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(color: RdvColors.surfaceHigh, borderRadius: BorderRadius.circular(12)),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _Segment(label: 'Semaine', selected: !monthView, onTap: () => onToggleView(false)),
              _Segment(label: 'Mois', selected: monthView, onTap: () => onToggleView(true)),
            ],
          ),
        ),
      ],
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          boxShadow: selected ? RdvColors.cardShadow : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: selected ? RdvColors.primaryContainer : RdvColors.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({required this.icon, required this.tooltip, required this.onPressed});

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      elevation: 1,
      shadowColor: Colors.black26,
      child: IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        visualDensity: VisualDensity.compact,
        icon: Icon(icon, size: 20, color: RdvColors.onSurfaceVariant),
      ),
    );
  }
}

/// Bande de la semaine (dimanche → samedi), jour choisi en teal.
class _WeekStrip extends StatelessWidget {
  const _WeekStrip({required this.selected, required this.dots, required this.onSelect});

  final DateTime selected;
  final Map<DateTime, Set<Color>> dots;
  final ValueChanged<DateTime> onSelect;

  @override
  Widget build(BuildContext context) {
    final sunday = selected.subtract(Duration(days: selected.weekday % 7));
    final days = [for (var i = 0; i < 7; i++) DateTime(sunday.year, sunday.month, sunday.day + i)];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          for (final day in days)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: _DayPill(
                  day: day,
                  selected: isSameDay(day, selected),
                  dots: dots[day] ?? const {},
                  onTap: () => onSelect(day),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _DayPill extends StatelessWidget {
  const _DayPill({required this.day, required this.selected, required this.dots, required this.onTap});

  final DateTime day;
  final bool selected;
  final Set<Color> dots;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = selected ? Colors.white : RdvColors.onSurface;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        height: selected ? 80 : 72,
        decoration: BoxDecoration(
          color: selected ? RdvColors.primaryContainer : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: RdvColors.cardShadow,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              shortDayName(day),
              style: TextStyle(fontSize: 11, color: selected ? Colors.white70 : RdvColors.onSurfaceVariant),
            ),
            const SizedBox(height: 4),
            Text('${day.day}', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: fg)),
            const SizedBox(height: 6),
            SizedBox(
              height: 6,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (final color in dots.take(2))
                    Container(
                      width: 6,
                      height: 6,
                      margin: const EdgeInsets.symmetric(horizontal: 1.5),
                      decoration: BoxDecoration(
                        color: selected ? (color == RdvColors.primaryContainer ? Colors.white : RdvColors.secondaryFixed) : color,
                        shape: BoxShape.circle,
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

/// Vue « Mois » : grille complète du mois avec les mêmes points de couleur.
class _MonthGrid extends StatelessWidget {
  const _MonthGrid({required this.month, required this.selected, required this.dots, required this.onSelect});

  final DateTime month;
  final DateTime selected;
  final Map<DateTime, Set<Color>> dots;
  final ValueChanged<DateTime> onSelect;

  @override
  Widget build(BuildContext context) {
    final first = DateTime(month.year, month.month, 1);
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final leading = first.weekday % 7; // colonnes vides avant le 1er (semaine commençant dimanche)

    return RdvCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
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
          const SizedBox(height: 8),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: leading + daysInMonth,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 7, mainAxisExtent: 44),
            itemBuilder: (context, index) {
              if (index < leading) return const SizedBox.shrink();
              final day = DateTime(month.year, month.month, index - leading + 1);
              final isSelected = isSameDay(day, selected);
              final dayDots = dots[day] ?? const <Color>{};
              return InkWell(
                onTap: () => onSelect(day),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  margin: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: isSelected ? RdvColors.primaryContainer : null,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '${day.day}',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: isSelected ? Colors.white : RdvColors.onSurface,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          for (final color in dayDots.take(2))
                            Container(
                              width: 5,
                              height: 5,
                              margin: const EdgeInsets.symmetric(horizontal: 1),
                              decoration: BoxDecoration(
                                color: isSelected ? Colors.white : color,
                                shape: BoxShape.circle,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

/// Carte d'un rendez-vous actif ou terminé (maquette : Milo / Nala).
class AppointmentCard extends StatelessWidget {
  const AppointmentCard({super.key, required this.appointment, this.showActions = true});

  final Appointment appointment;
  final bool showActions;

  @override
  Widget build(BuildContext context) {
    final a = appointment;
    final timeColor = a.status == AppointmentStatus.planned ? RdvColors.secondary : RdvColors.primaryContainer;

    return GestureDetector(
      onTap: () => openAppointmentDetail(context, a),
      child: RdvCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                PetAvatar(name: a.petName, photoUrl: a.petPhotoUrl),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text.rich(
                        TextSpan(
                          text: a.petName,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                          children: [
                            if ((a.petBreed ?? '').isNotEmpty)
                              TextSpan(
                                text: '  • ${a.petBreed}',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w400,
                                  color: RdvColors.onSurfaceVariant,
                                ),
                              ),
                          ],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.schedule, size: 16, color: timeColor),
                          const SizedBox(width: 4),
                          Text(
                            '${formatTime(a.startsAt)} - ${formatTime(a.endsAt)}',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: timeColor),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                StatusPill.forStatus(a.status),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: RdvColors.surfaceLow, borderRadius: BorderRadius.circular(12)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      TypeTag.forType(a.type, label: a.isBooking || a.type != AppointmentType.personalCare ? null : 'Personnel'),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          a.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _IconLine(
                    icon: a.isBooking
                        ? (a.type == AppointmentType.grooming ? Icons.storefront_outlined : Icons.local_hospital_outlined)
                        : Icons.home_outlined,
                    text: a.providerName ?? a.place.label,
                    strong: true,
                  ),
                  if (a.location.isNotEmpty || (a.providerAddress ?? '').isNotEmpty) ...[
                    const SizedBox(height: 4),
                    _IconLine(icon: Icons.location_on_outlined, text: a.providerAddress ?? a.location),
                  ],
                ],
              ),
            ),
            if (showActions && a.status.isActive) ...[
              const SizedBox(height: 12),
              _CardActions(appointment: a),
            ],
          ],
        ),
      ),
    );
  }
}

class _IconLine extends StatelessWidget {
  const _IconLine({required this.icon, required this.text, this.strong = false});

  final IconData icon;
  final String text;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: RdvColors.onSurfaceVariant),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              fontWeight: strong ? FontWeight.w600 : FontWeight.w400,
              color: strong ? RdvColors.onSurface : RdvColors.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}

/// Boutons sous la carte : « Itinéraire / Carnet santé / Appeler » pour un rendez-vous confirmé,
/// « Modifier / Contacter le salon » pour une demande en attente.
class _CardActions extends StatelessWidget {
  const _CardActions({required this.appointment});

  final Appointment appointment;

  @override
  Widget build(BuildContext context) {
    final a = appointment;
    if (a.status == AppointmentStatus.planned) {
      return Row(
        children: [
          Expanded(
            child: SoftButton(
              label: 'Modifier',
              icon: Icons.edit_calendar_outlined,
              onPressed: a.canReschedule() ? () => openReschedule(context, a) : null,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: SoftButton(
              label: a.isBooking ? 'Contacter le salon' : 'Contacter',
              icon: Icons.chat_outlined,
              background: RdvColors.secondaryFixed,
              foreground: RdvColors.onSecondaryContainer,
              onPressed: () => callPhone(context, a.providerPhone),
            ),
          ),
        ],
      );
    }

    final address = a.providerAddress ?? a.location;
    return Row(
      children: [
        Expanded(
          child: SoftButton(
            label: 'Itinéraire',
            icon: Icons.near_me_outlined,
            onPressed: address.isEmpty ? null : () => openDirections(context, address),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: SoftButton(
            label: 'Carnet santé',
            icon: Icons.bookmark_add_outlined,
            onPressed: () => openHealthRecord(context),
          ),
        ),
        if ((a.providerPhone ?? '').isNotEmpty) ...[
          const SizedBox(width: 8),
          SizedBox(
            width: 44,
            height: 44,
            child: Material(
              color: RdvColors.primaryContainer,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => callPhone(context, a.providerPhone),
                child: const Icon(Icons.call, color: Colors.white, size: 20),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Carte d'un rendez-vous annulé : titre barré, motif et « Reprogrammer ».
class _CancelledCard extends StatelessWidget {
  const _CancelledCard({required this.appointment});

  final Appointment appointment;

  @override
  Widget build(BuildContext context) {
    final a = appointment;
    return GestureDetector(
      onTap: () => openAppointmentDetail(context, a),
      child: RdvCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(color: RdvColors.errorContainer, borderRadius: BorderRadius.circular(26)),
                  child: const Icon(Icons.event_busy, color: RdvColors.error),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        a.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: RdvColors.outline,
                          decoration: TextDecoration.lineThrough,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${a.providerName ?? a.petName} • ${formatTime(a.startsAt)}',
                        style: const TextStyle(fontSize: 13, color: RdvColors.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                StatusPill.forStatus(a.status),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
              decoration: BoxDecoration(color: RdvColors.surfaceLow, borderRadius: BorderRadius.circular(12)),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Motif : ${a.cancelReason ?? 'non précisé'}',
                      style: const TextStyle(fontSize: 13, color: RdvColors.onSurfaceVariant),
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).pushNamed(
                      AppRoutes.appointmentForm,
                      arguments: AppointmentFormArgs.copyOf(a),
                    ),
                    style: TextButton.styleFrom(foregroundColor: RdvColors.primaryContainer),
                    child: const Text('Reprogrammer', style: TextStyle(fontWeight: FontWeight.w600)),
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

/// Rappel de soin du jour dans l'agenda, avec la case « Valider ».
class _ReminderCard extends StatelessWidget {
  const _ReminderCard({required this.reminder});

  final Reminder reminder;

  @override
  Widget build(BuildContext context) {
    final r = reminder;
    return RdvCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(color: RdvColors.surfaceContainer, borderRadius: BorderRadius.circular(26)),
                child: const Icon(Icons.medication_outlined, color: RdvColors.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text.rich(
                      TextSpan(
                        text: r.petName,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                        children: [
                          TextSpan(
                            text: '  • ${r.category.label}',
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w400, color: RdvColors.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.schedule, size: 16, color: RdvColors.onSurfaceVariant),
                        const SizedBox(width: 4),
                        Text(formatTime(r.dueAt), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ],
                ),
              ),
              StatusPill(
                label: 'Rappel',
                icon: Icons.notifications_active_outlined,
                background: RdvColors.primaryFixed.withValues(alpha: 0.45),
                foreground: RdvColors.onPrimaryFixedVariant,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: RdvColors.surfaceLow, borderRadius: BorderRadius.circular(12)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    TypeTag(
                      label: 'Personnel',
                      icon: Icons.home_outlined,
                      background: Colors.white,
                      foreground: RdvColors.onSurfaceVariant,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        r.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
                if ((r.description ?? '').isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(r.description!, style: const TextStyle(fontSize: 13, color: RdvColors.onSurfaceVariant)),
                ],
              ],
            ),
          ),
          const SizedBox(height: 10),
          Material(
            color: RdvColors.surfaceLow,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => markReminderDone(context, r),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  children: [
                    Checkbox(value: r.done, onChanged: (_) => markReminderDone(context, r)),
                    Expanded(
                      child: Text(
                        'Valider : ${r.title}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.only(right: 8),
                      child: Icon(Icons.check, size: 18, color: RdvColors.onSurfaceVariant),
                    ),
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

class _EmptyDay extends StatelessWidget {
  const _EmptyDay({required this.onAdd, required this.hasFilters});

  final VoidCallback onAdd;
  final bool hasFilters;

  @override
  Widget build(BuildContext context) {
    return RdvCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: const BoxDecoration(color: RdvColors.surfaceContainer, shape: BoxShape.circle),
            child: const Icon(Icons.event_available_outlined, color: RdvColors.primary, size: 30),
          ),
          const SizedBox(height: 12),
          Text(
            hasFilters ? 'Aucun rendez-vous pour ces filtres' : 'Aucun rendez-vous ce jour-là',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          const Text(
            'Choisissez un autre jour ou programmez un soin pour votre compagnon.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: RdvColors.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onAdd,
            style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
            icon: const Icon(Icons.add),
            label: const Text('Rendez-vous'),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_outlined, size: 40, color: RdvColors.error),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center, style: const TextStyle(color: RdvColors.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}

/// Ouvre la fiche santé du module 2 quand elle existera.
void openHealthRecord(BuildContext context) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => const ComingSoonScreen(title: 'Carnet de santé')),
  );
}

/// Valide (ou dévalide) un rappel de soin.
Future<void> markReminderDone(BuildContext context, Reminder reminder) async {
  try {
    await ReminderRepository().setDone(reminder.id, done: !reminder.done);
  } catch (e) {
    if (context.mounted) showRdvError(context, e);
  }
}
