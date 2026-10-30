import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../core/routes.dart';
import '../../../core/widgets/coming_soon_screen.dart';
import '../data/appointment.dart';
import '../data/appointment_format.dart';
import '../data/appointment_repository.dart';
import '../data/pet_option.dart';
import '../data/reminder.dart';
import '../data/reminder_repository.dart';
import 'appointment_actions.dart';
import 'widgets/rdv_ui.dart';

/// Liste des rappels (maquette Stitch « Liste des rappels ») : Aujourd'hui, Cette semaine, Plus tard.
///
/// Elle réunit les rappels de soins créés à la main et les rendez-vous à venir qui ont un rappel.
class RemindersScreen extends StatefulWidget {
  const RemindersScreen({super.key});

  @override
  State<RemindersScreen> createState() => _RemindersScreenState();
}

enum _Filter { all, medication, appointments }

class _RemindersScreenState extends State<RemindersScreen> {
  final _uid = FirebaseAuth.instance.currentUser?.uid;
  late final _appointments = _uid == null ? null : AppointmentRepository().watchAgenda(_uid);
  late final _reminders = _uid == null ? null : ReminderRepository().watch(_uid);

  String? _pet;
  _Filter _filter = _Filter.all;
  bool _showDone = false;

  Future<void> _newReminder(List<String> pets) async {
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      showDragHandle: true,
      builder: (_) => NewReminderSheet(knownPets: pets),
    );
    if (created == true && mounted) showRdvMessage(context, 'Rappel ajouté.');
  }

  @override
  Widget build(BuildContext context) {
    if (_uid == null) return const ComingSoonScreen(title: 'Rappels');

    return StreamBuilder<List<Appointment>>(
      stream: _appointments,
      builder: (context, apptSnap) {
        return StreamBuilder<List<Reminder>>(
          stream: _reminders,
          builder: (context, remSnap) {
            final loading = !apptSnap.hasData && !apptSnap.hasError || !remSnap.hasData && !remSnap.hasError;
            final error = apptSnap.error ?? remSnap.error;
            final items = _items(apptSnap.data ?? const [], remSnap.data ?? const []);
            final pets = {for (final i in items) i.petName: i.petPhotoUrl};

            return RdvTabScaffold(
              showLogo: false,
              extraAction: IconButton(
                tooltip: 'Filtrer',
                onPressed: () => _openFilters(pets.keys.toList()),
                icon: const Icon(Icons.tune, color: RdvColors.onSurfaceVariant),
              ),
              floatingActionButton: FloatingActionButton.extended(
                onPressed: () => _newReminder(pets.keys.toList()),
                backgroundColor: RdvColors.primary,
                foregroundColor: Colors.white,
                shape: const StadiumBorder(),
                icon: const Icon(Icons.add),
                label: const Text('Nouveau rappel', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              ),
              body: error != null
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Text(friendlyError(error), textAlign: TextAlign.center),
                      ),
                    )
                  : loading
                      ? const Center(child: CircularProgressIndicator())
                      : _buildList(items, pets),
            );
          },
        );
      },
    );
  }

  Future<void> _openFilters(List<String> pets) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: StatefulBuilder(
          builder: (context, setSheet) {
            void update(VoidCallback change) {
              setState(change);
              setSheet(() {});
            }

            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Filtres', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 12),
                  const Text('Animal', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      RdvChip(label: 'Tous', selected: _pet == null, onTap: () => update(() => _pet = null)),
                      for (final p in pets) RdvChip(label: p, selected: _pet == p, onTap: () => update(() => _pet = p)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Afficher les rappels terminés'),
                    value: _showDone,
                    activeTrackColor: RdvColors.primary,
                    onChanged: (v) => update(() => _showDone = v),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  List<_ReminderItem> _items(List<Appointment> appointments, List<Reminder> reminders) {
    final now = DateTime.now();
    return [
      for (final r in reminders) _ReminderItem.fromReminder(r),
      for (final a in appointments)
        if (a.ownerId == _uid && a.status.isActive && a.reminderMinutes > 0 && a.endsAt.isAfter(now))
          _ReminderItem.fromAppointment(a),
    ]..sort((x, y) => x.dueAt.compareTo(y.dueAt));
  }

  Widget _buildList(List<_ReminderItem> all, Map<String, String?> pets) {
    final now = DateTime.now();
    final today = dayOnly(now);
    final weekEnd = today.add(const Duration(days: 8));

    bool keep(_ReminderItem i) =>
        (_pet == null || i.petName == _pet) &&
        switch (_filter) {
          _Filter.all => true,
          _Filter.medication =>
            i.reminder?.category == ReminderCategory.medication || i.reminder?.category == ReminderCategory.treatment,
          _Filter.appointments => i.appointment != null,
        };

    final visible = all.where(keep).toList();
    final todo = visible.where((i) => !i.done).toList();
    final todayItems = todo.where((i) => i.dueAt.isBefore(today.add(const Duration(days: 1)))).toList();
    final weekItems = todo.where((i) => !i.dueAt.isBefore(today.add(const Duration(days: 1))) && i.dueAt.isBefore(weekEnd)).toList();
    final laterItems = todo.where((i) => !i.dueAt.isBefore(weekEnd)).toList();
    final doneToday = visible.where((i) => i.done && i.doneAt != null && isSameDay(i.doneAt!, now)).toList();
    final doneOther = visible.where((i) => i.done && !doneToday.contains(i)).toList();

    final todayPets = {for (final i in [...todayItems, ...doneToday]) i.petName}.toList();
    final totalToday = todayItems.length + doneToday.length;

    return ListView(
      padding: const EdgeInsets.only(bottom: 96),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
          child: Row(
            children: [
              const Text('Rappels & Soins', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
              const SizedBox(width: 8),
              StatusPill(
                label: '${todo.length} à faire',
                background: RdvColors.secondaryFixed,
                foreground: RdvColors.onSecondaryContainer,
              ),
              const Spacer(),
              OutlinedButton.icon(
                onPressed: () => pushRdvTabRoute(context, AppRoutes.agenda),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 34),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  foregroundColor: RdvColors.primary,
                  side: const BorderSide(color: RdvColors.outlineVariant),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.calendar_today_outlined, size: 16),
                label: const Text('Vue mois', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _ProgressCard(pets: todayPets, done: doneToday.length, total: totalToday),
        ),
        const SizedBox(height: 16),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              RdvChip(
                label: 'Tous les rappels',
                selected: _pet == null && _filter == _Filter.all,
                leading: Icon(
                  Icons.done_all,
                  size: 18,
                  color: _pet == null && _filter == _Filter.all ? Colors.white : RdvColors.primary,
                ),
                onTap: () => setState(() {
                  _pet = null;
                  _filter = _Filter.all;
                }),
              ),
              for (final (index, entry) in pets.entries.indexed) ...[
                const SizedBox(width: 8),
                RdvChip(
                  label: entry.key,
                  selected: _pet == entry.key,
                  leading: PetAvatar(name: entry.key, photoUrl: entry.value, size: 24, badge: false),
                  trailing: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: index.isEven ? RdvColors.secondary : RdvColors.primaryContainer,
                      shape: BoxShape.circle,
                    ),
                  ),
                  onTap: () => setState(() => _pet = _pet == entry.key ? null : entry.key),
                ),
              ],
              const SizedBox(width: 8),
              RdvChip(
                label: 'Médicaments',
                selected: _filter == _Filter.medication,
                leading: Icon(Icons.medication_outlined, size: 18,
                    color: _filter == _Filter.medication ? Colors.white : RdvColors.primary),
                onTap: () => setState(() => _filter = _filter == _Filter.medication ? _Filter.all : _Filter.medication),
              ),
              const SizedBox(width: 8),
              RdvChip(
                label: 'Rendez-vous',
                selected: _filter == _Filter.appointments,
                leading: Icon(Icons.event_outlined, size: 18,
                    color: _filter == _Filter.appointments ? Colors.white : RdvColors.primary),
                onTap: () =>
                    setState(() => _filter = _filter == _Filter.appointments ? _Filter.all : _Filter.appointments),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        if (todo.isEmpty && doneToday.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: _EmptyReminders(),
          ),
        if (todayItems.isNotEmpty)
          _Group(
            title: "Aujourd'hui",
            count: todayItems.length,
            trailing: todayItems.any((i) => i.dueAt.hour >= 18) ? 'Ce soir' : formatDayMonth(today),
            items: todayItems,
            emphasize: true,
          ),
        if (weekItems.isNotEmpty)
          _Group(
            title: 'Cette semaine',
            count: weekItems.length,
            trailing: '${today.add(const Duration(days: 1)).day} - ${formatDayMonth(weekEnd.subtract(const Duration(days: 1)))}',
            items: weekItems,
          ),
        if (laterItems.isNotEmpty)
          _Group(
            title: 'Plus tard',
            badge: 'À venir',
            trailing: _monthsLabel(laterItems),
            items: laterItems,
          ),
        if (doneToday.isNotEmpty || (_showDone && doneOther.isNotEmpty))
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _DoneSection(items: _showDone ? [...doneToday, ...doneOther] : doneToday, todayCount: doneToday.length),
          ),
      ],
    );
  }

  static String _monthsLabel(List<_ReminderItem> items) {
    final months = <String>[];
    for (final i in items) {
      final m = formatMonthYear(i.dueAt).split(' ').first;
      if (!months.contains(m)) months.add(m);
      if (months.length == 2) break;
    }
    return months.join(' & ');
  }
}

/// Un rappel affiché : un rappel de soin ou un rendez-vous avec rappel.
class _ReminderItem {
  _ReminderItem.fromReminder(Reminder this.reminder)
      : appointment = null,
        petName = reminder.petName,
        petBreed = reminder.petBreed,
        petPhotoUrl = reminder.petPhotoUrl,
        title = reminder.title,
        description = reminder.description,
        dueAt = reminder.dueAt,
        done = reminder.done,
        doneAt = reminder.doneAt;

  _ReminderItem.fromAppointment(Appointment this.appointment)
      : reminder = null,
        petName = appointment.petName,
        petBreed = appointment.petBreed,
        petPhotoUrl = appointment.petPhotoUrl,
        title = appointment.title,
        description = appointment.providerName ?? (appointment.location.isEmpty ? null : appointment.location),
        dueAt = appointment.startsAt,
        done = appointment.reminderDoneAt != null,
        doneAt = appointment.reminderDoneAt;

  final Reminder? reminder;
  final Appointment? appointment;
  final String petName;
  final String? petBreed;
  final String? petPhotoUrl;
  final String title;
  final String? description;
  final DateTime dueAt;
  final bool done;
  final DateTime? doneAt;

  String get tag => reminder?.category.label ?? appointment!.type.label;

  IconData get icon => reminder != null
      ? switch (reminder!.category) {
          ReminderCategory.medication => Icons.medication_outlined,
          ReminderCategory.care => Icons.healing_outlined,
          ReminderCategory.vet => Icons.calendar_month_outlined,
          ReminderCategory.treatment => Icons.science_outlined,
          ReminderCategory.hygiene => Icons.content_cut,
          ReminderCategory.checkup => Icons.biotech_outlined,
        }
      : appointmentTypeIcon(appointment!.type);

  (Color, Color) get colors {
    final category = reminder?.category;
    if (category == ReminderCategory.medication || category == ReminderCategory.treatment) {
      return (RdvColors.secondaryFixed, RdvColors.secondary);
    }
    if (appointment != null || category == ReminderCategory.checkup) {
      return (RdvColors.primaryFixed.withValues(alpha: 0.6), RdvColors.onPrimaryFixedVariant);
    }
    return (RdvColors.surfaceContainer, RdvColors.primary);
  }

  Future<void> toggleDone(BuildContext context) async {
    try {
      if (reminder != null) {
        await ReminderRepository().setDone(reminder!.id, done: !done);
      } else {
        await AppointmentRepository().markReminderDone(appointment!, done: !done);
      }
    } catch (e) {
      if (context.mounted) showRdvError(context, e);
    }
  }
}

class _ProgressCard extends StatelessWidget {
  const _ProgressCard({required this.pets, required this.done, required this.total});

  final List<String> pets;
  final int done;
  final int total;

  @override
  Widget build(BuildContext context) {
    final left = total - done;
    final title = pets.isEmpty ? 'Journée de soin' : 'Journée de soin pour ${pets.join(' & ')}';
    final subtitle = total == 0
        ? "Aucun soin prévu aujourd'hui."
        : left == 0
            ? 'Tous les soins du jour sont validés. Bravo !'
            : '${done == 0 ? 'Aucun soin validé' : '$done soin${done > 1 ? 's' : ''} déjà validé${done > 1 ? 's' : ''}'}. '
                'Plus que $left aujourd\'hui !';

    return RdvCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: RdvColors.primaryFixed.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.favorite_border, color: RdvColors.onPrimaryFixedVariant),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(subtitle, style: const TextStyle(fontSize: 13, color: RdvColors.onSurfaceVariant)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: total == 0 ? 0 : done / total,
              minHeight: 6,
              color: RdvColors.primaryContainer,
              backgroundColor: RdvColors.surfaceHigh,
            ),
          ),
        ],
      ),
    );
  }
}

class _Group extends StatelessWidget {
  const _Group({
    required this.title,
    required this.items,
    required this.trailing,
    this.count,
    this.badge,
    this.emphasize = false,
  });

  final String title;
  final int? count;
  final String? badge;
  final String trailing;
  final List<_ReminderItem> items;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
              const SizedBox(width: 8),
              StatusPill(
                label: badge ?? (count == 1 ? '1 rappel' : '$count rappels'),
                background: emphasize ? RdvColors.secondaryFixed : RdvColors.surfaceHigh,
                foreground: emphasize ? RdvColors.onSecondaryContainer : RdvColors.onSurfaceVariant,
              ),
              const Spacer(),
              Text(trailing, style: const TextStyle(fontSize: 13, color: RdvColors.onSurfaceVariant)),
            ],
          ),
          const SizedBox(height: 12),
          for (final item in items)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: _ReminderTile(item: item, emphasize: emphasize),
            ),
        ],
      ),
    );
  }
}

class _ReminderTile extends StatelessWidget {
  const _ReminderTile({required this.item, required this.emphasize});

  final _ReminderItem item;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final (bg, fg) = item.colors;
    final appointment = item.appointment;
    final detail = item.reminder?.detail;

    // Pastille d'urgence pour les rappels du jour.
    StatusPill? urgency;
    if (emphasize) {
      if (item.dueAt.isBefore(now)) {
        urgency = const StatusPill(
          label: 'En retard',
          background: RdvColors.errorContainer,
          foreground: RdvColors.onErrorContainer,
        );
      } else if (item.dueAt.difference(now).inMinutes <= 60) {
        urgency = StatusPill(
          label: "À l'heure",
          background: RdvColors.primaryFixed.withValues(alpha: 0.45),
          foreground: RdvColors.onPrimaryFixedVariant,
        );
      } else if (item.dueAt.hour >= 18) {
        urgency = const StatusPill(
          label: 'Ce soir',
          background: RdvColors.secondaryFixed,
          foreground: RdvColors.onSecondaryContainer,
        );
      }
    }

    return RdvCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
                child: Icon(item.icon, color: fg, size: 22),
              ),
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
                        PetAvatar(name: item.petName, photoUrl: item.petPhotoUrl, size: 18, badge: false),
                        Text(
                          (item.petBreed ?? '').isEmpty ? item.petName : '${item.petName} • ${item.petBreed}',
                          style: const TextStyle(fontSize: 12, color: RdvColors.onSurfaceVariant),
                        ),
                        TypeTag(
                          label: item.tag,
                          background: RdvColors.surfaceContainer,
                          foreground: RdvColors.onSurfaceVariant,
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                    if ((item.description ?? '').isNotEmpty)
                      Text(
                        item.description!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13, color: RdvColors.onSurfaceVariant),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (emphasize)
                    Text(
                      formatTime(item.dueAt),
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: RdvColors.secondary),
                    )
                  else ...[
                    Text(
                      formatShortDayMonth(item.dueAt),
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    Text(formatTime(item.dueAt), style: const TextStyle(fontSize: 12, color: RdvColors.onSurfaceVariant)),
                  ],
                  if (urgency != null) ...[const SizedBox(height: 4), urgency],
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: appointment != null
                    ? Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: () => openAppointmentDetail(context, appointment),
                          style: TextButton.styleFrom(
                            foregroundColor: RdvColors.primary,
                            padding: EdgeInsets.zero,
                            minimumSize: const Size(0, 36),
                          ),
                          icon: const Icon(Icons.pin_drop_outlined, size: 18),
                          label: const Text('Voir RDV & plan', style: TextStyle(fontWeight: FontWeight.w600)),
                        ),
                      )
                    : detail == null
                        ? const SizedBox.shrink()
                        : Row(
                            children: [
                              const Icon(Icons.info_outline, size: 16, color: RdvColors.outlineVariant),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  detail,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 13, color: RdvColors.outline),
                                ),
                              ),
                            ],
                          ),
              ),
              if (emphasize)
                FilledButton.icon(
                  onPressed: () => item.toggleDone(context),
                  style: FilledButton.styleFrom(
                    backgroundColor: RdvColors.primary,
                    minimumSize: const Size(0, 40),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                  icon: const Icon(Icons.check_circle_outline, size: 18),
                  label: const Text('Fait'),
                )
              else
                SizedBox(
                  width: 92,
                  child: SoftButton(
                    label: 'Fait',
                    icon: Icons.check,
                    foreground: RdvColors.primary,
                    onPressed: () => item.toggleDone(context),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DoneSection extends StatefulWidget {
  const _DoneSection({required this.items, required this.todayCount});

  final List<_ReminderItem> items;
  final int todayCount;

  @override
  State<_DoneSection> createState() => _DoneSectionState();
}

class _DoneSectionState extends State<_DoneSection> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final label = widget.todayCount == 1
        ? "1 rappel terminé aujourd'hui"
        : "${widget.todayCount} rappels terminés aujourd'hui";

    return RdvCard(
      color: RdvColors.surfaceLow,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _open = !_open),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: const BoxDecoration(color: RdvColors.secondaryContainer, shape: BoxShape.circle),
                    child: const Icon(Icons.check, size: 16, color: RdvColors.onSecondaryContainer),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600))),
                  Icon(_open ? Icons.expand_less : Icons.expand_more, color: RdvColors.onSurfaceVariant),
                ],
              ),
            ),
          ),
          if (_open)
            for (final item in widget.items)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.check_circle, color: RdvColors.primaryContainer),
                title: Text('${item.title} – ${item.petName}', style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(
                  item.doneAt == null ? 'Terminé' : 'Complété le ${formatDayMonth(item.doneAt!)} à ${formatTime(item.doneAt!)}',
                ),
                trailing: TextButton(
                  onPressed: () => item.toggleDone(context),
                  child: const Text('Annuler'),
                ),
              ),
        ],
      ),
    );
  }
}

class _EmptyReminders extends StatelessWidget {
  const _EmptyReminders();

  @override
  Widget build(BuildContext context) {
    return const RdvCard(
      padding: EdgeInsets.all(24),
      child: Column(
        children: [
          Icon(Icons.notifications_none, size: 40, color: RdvColors.primary),
          SizedBox(height: 10),
          Text('Aucun rappel pour le moment', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          SizedBox(height: 4),
          Text(
            'Ajoutez un rappel de soin ou programmez un rendez-vous avec rappel.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: RdvColors.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

/// Formulaire « Nouveau rappel » (feuille du bas).
class NewReminderSheet extends StatefulWidget {
  const NewReminderSheet({super.key, this.knownPets = const []});

  final List<String> knownPets;

  @override
  State<NewReminderSheet> createState() => _NewReminderSheetState();
}

class _NewReminderSheetState extends State<NewReminderSheet> {
  final _formKey = GlobalKey<FormState>();
  final _pet = TextEditingController();
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _detail = TextEditingController();
  final _uid = FirebaseAuth.instance.currentUser?.uid;
  late final _pets = _uid == null ? null : PetDirectory().watch(_uid);

  ReminderCategory _category = ReminderCategory.medication;
  DateTime _day = dayOnly(DateTime.now());
  TimeOfDay _time = TimeOfDay.fromDateTime(DateTime.now().add(const Duration(hours: 1)));
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _pet.dispose();
    _title.dispose();
    _description.dispose();
    _detail.dispose();
    super.dispose();
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _time,
      builder: (context, child) =>
          MediaQuery(data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true), child: child!),
    );
    if (picked != null) setState(() => _time = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ReminderRepository().create(
        petName: _pet.text,
        title: _title.text,
        description: _description.text,
        detail: _detail.text,
        category: _category,
        dueAt: DateTime(_day.year, _day.month, _day.day, _time.hour, _time.minute),
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final today = dayOnly(DateTime.now());

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Nouveau rappel', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
                const SizedBox(height: 16),
                const FieldLabel('Animal concerné', required: true),
                StreamBuilder<List<PetOption>>(
                  stream: _pets,
                  builder: (context, snap) {
                    final names = {...?snap.data?.map((p) => p.name), ...widget.knownPets}.toList();
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (names.isNotEmpty)
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final n in names)
                                RdvChip(
                                  label: n,
                                  selected: _pet.text == n,
                                  onTap: () => setState(() => _pet.text = n),
                                ),
                            ],
                          ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _pet,
                          maxLength: 80,
                          textCapitalization: TextCapitalization.words,
                          decoration: const InputDecoration(hintText: "Nom de l'animal", counterText: ''),
                          onChanged: (_) => setState(() {}),
                          validator: (v) => (v == null || v.trim().isEmpty) ? "Indiquez l'animal concerné." : null,
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 16),
                const FieldLabel('Type de rappel', required: true),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final c in ReminderCategory.values)
                      RdvChip(label: c.label, selected: _category == c, onTap: () => setState(() => _category = c)),
                  ],
                ),
                const SizedBox(height: 16),
                const FieldLabel('Intitulé', required: true),
                TextFormField(
                  controller: _title,
                  maxLength: 120,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(hintText: 'Ex. Vermifuge Milbemax', counterText: ''),
                  validator: (v) => (v == null || v.trim().isEmpty) ? "L'intitulé est obligatoire." : null,
                ),
                const SizedBox(height: 16),
                const FieldLabel('Quand', required: true),
                Row(
                  children: [
                    for (var i = 0; i < 3; i++) ...[
                      Expanded(
                        child: RdvChip(
                          label: switch (i) { 0 => "Aujourd'hui", 1 => 'Demain', _ => formatDayMonth(today.add(Duration(days: i))) },
                          selected: isSameDay(_day, today.add(Duration(days: i))),
                          onTap: () => setState(() => _day = today.add(Duration(days: i))),
                        ),
                      ),
                      const SizedBox(width: 6),
                    ],
                    OutlinedButton.icon(
                      onPressed: _pickTime,
                      style: OutlinedButton.styleFrom(minimumSize: const Size(0, 40)),
                      icon: const Icon(Icons.schedule, size: 18),
                      label: Text(
                        '${_time.hour.toString().padLeft(2, '0')}:${_time.minute.toString().padLeft(2, '0')}',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const FieldLabel('Consigne'),
                TextFormField(
                  controller: _description,
                  maxLength: 300,
                  maxLines: 2,
                  decoration: const InputDecoration(hintText: 'Ex. Comprimé à donner pendant le repas du soir.', counterText: ''),
                ),
                const SizedBox(height: 12),
                const FieldLabel('Détail'),
                TextFormField(
                  controller: _detail,
                  maxLength: 60,
                  decoration: const InputDecoration(hintText: 'Ex. 1 comprimé', counterText: ''),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!, style: const TextStyle(color: RdvColors.error)),
                ],
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  style: FilledButton.styleFrom(backgroundColor: RdvColors.primary),
                  icon: const Icon(Icons.check_circle_outline),
                  label: const Text('Enregistrer le rappel'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
