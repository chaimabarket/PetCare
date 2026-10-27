import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/appointment.dart';
import '../data/appointment_format.dart';
import '../data/appointment_repository.dart';
import 'agenda_screen.dart' show openHealthRecord;
import 'appointment_actions.dart';
import 'widgets/rdv_ui.dart';

/// Détail d'un rendez-vous (maquette Stitch « Détail du rendez-vous »).
///
/// Le client voit Reporter / Annuler ; le prestataire voit en plus l'« Espace Prestataire »
/// avec Confirmer et Proposer un autre horaire.
class AppointmentDetailScreen extends StatefulWidget {
  const AppointmentDetailScreen({super.key, required this.appointmentId});

  final String appointmentId;

  @override
  State<AppointmentDetailScreen> createState() => _AppointmentDetailScreenState();
}

class _AppointmentDetailScreenState extends State<AppointmentDetailScreen> {
  final _repository = AppointmentRepository();
  final _uid = FirebaseAuth.instance.currentUser?.uid;
  late final _stream = _repository.watchOne(widget.appointmentId);
  bool _busy = false;

  Future<void> _run(Future<void> Function() action, String success) async {
    setState(() => _busy = true);
    try {
      await action();
      if (mounted) showRdvMessage(context, success);
    } catch (e) {
      if (mounted) showRdvError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _cancel(Appointment a) async {
    final reason = await showDialog<String>(context: context, builder: (_) => _CancelDialog(appointment: a));
    if (reason == null) return;
    await _run(() => _repository.cancel(a, reason: reason), 'Rendez-vous annulé.');
  }

  void _share(Appointment a) {
    final text = '${a.title} – ${a.petName}\n${formatLongDate(a.startsAt)}, ${formatTime(a.startsAt)} à '
        '${formatTime(a.endsAt)}\n${a.providerName ?? a.place.label}'
        '${(a.providerAddress ?? a.location).isEmpty ? '' : ' – ${a.providerAddress ?? a.location}'}';
    Clipboard.setData(ClipboardData(text: text));
    showRdvMessage(context, 'Détails du rendez-vous copiés.');
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Appointment?>(
      stream: _stream,
      builder: (context, snapshot) {
        final a = snapshot.data;
        return Scaffold(
          backgroundColor: RdvColors.surface,
          appBar: AppBar(
            backgroundColor: RdvColors.surface,
            surfaceTintColor: Colors.transparent,
            centerTitle: true,
            leading: IconButton(
              tooltip: 'Retour',
              icon: const Icon(Icons.arrow_back_ios_new, size: 20, color: RdvColors.primary),
              onPressed: () => Navigator.of(context).maybePop(),
            ),
            title: const Text(
              'Détail Du Rendez Vous',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: RdvColors.onSurface),
            ),
            actions: [
              IconButton(
                tooltip: 'Partager',
                onPressed: a == null ? null : () => _share(a),
                icon: const Icon(Icons.share_outlined, color: RdvColors.onSurfaceVariant),
              ),
              const Padding(padding: EdgeInsets.only(right: 12), child: RdvProfileButton()),
            ],
          ),
          body: switch (snapshot) {
            AsyncSnapshot(hasError: true) => _Message(text: friendlyError(snapshot.error!)),
            AsyncSnapshot(connectionState: ConnectionState.waiting) => const Center(child: CircularProgressIndicator()),
            _ when a == null => const _Message(text: "Ce rendez-vous n'existe plus ou ne vous concerne pas."),
            _ => Stack(
                children: [
                  _buildBody(a),
                  if (_busy) const LinearProgressIndicator(),
                ],
              ),
          },
        );
      },
    );
  }

  Widget _buildBody(Appointment a) {
    final isProvider = _uid != null && _uid == a.providerId;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        _SummaryCard(appointment: a),
        const SizedBox(height: 16),
        _PetCard(appointment: a),
        const SizedBox(height: 16),
        _PlaceCard(appointment: a),
        const SizedBox(height: 16),
        _ReminderCard(
          appointment: a,
          busy: _busy,
          onToggle: (enabled) => _run(
            () => _repository.setReminder(a, minutes: enabled ? 1440 : 0),
            enabled ? 'Rappel activé.' : 'Rappel désactivé.',
          ),
        ),
        if (isProvider && a.status.isActive) ...[
          const SizedBox(height: 16),
          _ProviderCard(
            appointment: a,
            busy: _busy,
            onConfirm: () => _run(() => _repository.confirm(a), 'Rendez-vous confirmé.'),
            onPropose: () => openReschedule(context, a),
          ),
        ],
        const SizedBox(height: 16),
        if (a.canReschedule())
          SoftButton(
            label: 'Reporter le rendez-vous',
            icon: Icons.sync,
            height: 48,
            foreground: RdvColors.primary,
            onPressed: _busy ? null : () => openReschedule(context, a),
          ),
        if (a.canCancel())
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: TextButton.icon(
              onPressed: _busy ? null : () => _cancel(a),
              style: TextButton.styleFrom(
                foregroundColor: RdvColors.error,
                minimumSize: const Size.fromHeight(44),
                textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
              icon: const Icon(Icons.cancel_outlined, size: 20),
              label: const Text('Annuler le rendez-vous'),
            ),
          ),
        if (a.canComplete())
          FilledButton.icon(
            onPressed: _busy ? null : () => _run(() => _repository.complete(a), 'Rendez-vous terminé.'),
            style: FilledButton.styleFrom(backgroundColor: RdvColors.primary),
            icon: const Icon(Icons.task_alt),
            label: const Text('Marquer comme terminé'),
          ),
        if (!a.status.isActive || (a.hasStarted() && !a.canComplete()))
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              a.status.isActive
                  ? 'Ce rendez-vous a commencé : il ne peut plus être reporté ni annulé.'
                  : 'Ce rendez-vous est ${a.status.label.toLowerCase()} : aucune action possible.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: RdvColors.onSurfaceVariant),
            ),
          ),
        if (a.isBooking) ...[
          const SizedBox(height: 16),
          RdvCard(
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: const BoxDecoration(color: RdvColors.secondaryFixed, shape: BoxShape.circle),
                  child: const Icon(Icons.verified_user_outlined, color: RdvColors.secondary, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Annulation gratuite jusqu'à 24h avant",
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                      Text(
                        'Pour toute urgence concernant ${a.petName}, contactez directement l\'équipe du salon.',
                        style: const TextStyle(fontSize: 13, color: RdvColors.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
        if (a.changes.isNotEmpty) ...[
          const SizedBox(height: 16),
          _HistoryCard(changes: a.changes.reversed.toList()),
        ],
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.appointment});

  final Appointment appointment;

  @override
  Widget build(BuildContext context) {
    final a = appointment;
    return RdvCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              StatusPill.forStatus(
                a.status,
                label: a.status == AppointmentStatus.planned ? 'En attente de confirmation' : null,
              ),
              const Spacer(),
              StatusPill(
                label: formatRelativeDay(a.startsAt),
                icon: Icons.schedule,
                background: RdvColors.surfaceHigh,
                foreground: RdvColors.onSurfaceVariant,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(color: RdvColors.surfaceContainer, borderRadius: BorderRadius.circular(14)),
                child: Icon(appointmentTypeIcon(a.type), color: RdvColors.primary, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${a.title} – ${formatDuration(a.duration)}',
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: RdvColors.onSurface),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      a.description ?? a.type.label,
                      style: const TextStyle(fontSize: 13, color: RdvColors.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: RdvColors.surfaceLow, borderRadius: BorderRadius.circular(12)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.event_outlined, size: 20, color: RdvColors.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        formatLongDate(a.startsAt),
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: RdvColors.primary),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(left: 28),
                        child: Text(
                          '${formatTime(a.startsAt)} à ${formatTime(a.endsAt)}',
                          style: const TextStyle(fontSize: 15, color: RdvColors.onSurfaceVariant),
                        ),
                      ),
                    ),
                    if (a.price != null)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            formatPrice(a.price!),
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: RdvColors.primary),
                          ),
                          const Text(
                            'Règlement sur place',
                            style: TextStyle(fontSize: 12, color: RdvColors.onSurfaceVariant),
                          ),
                        ],
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

class _CardTitle extends StatelessWidget {
  const _CardTitle({required this.icon, required this.title, this.trailing});

  final IconData icon;
  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: RdvColors.primary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: RdvColors.onSurface)),
        ),
        ?trailing,
      ],
    );
  }
}

class _PetCard extends StatelessWidget {
  const _PetCard({required this.appointment});

  final Appointment appointment;

  @override
  Widget build(BuildContext context) {
    final a = appointment;
    return RdvCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _CardTitle(
            icon: Icons.pets,
            title: 'Animal concerné',
            trailing: a.petId == null
                ? null
                : const StatusPill(
                    label: 'Fiche à jour',
                    background: RdvColors.surfaceHigh,
                    foreground: RdvColors.onSurfaceVariant,
                  ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 64,
                  height: 64,
                  child: (a.petPhotoUrl ?? '').isEmpty
                      ? ColoredBox(
                          color: RdvColors.secondaryFixed,
                          child: Center(
                            child: Text(
                              a.petName.isEmpty ? '?' : a.petName.characters.first.toUpperCase(),
                              style: const TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.w700,
                                color: RdvColors.onSecondaryContainer,
                              ),
                            ),
                          ),
                        )
                      : Image.network(a.petPhotoUrl!, fit: BoxFit.cover),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(a.petName, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
                    if ((a.petBreed ?? '').isNotEmpty)
                      Text(a.petBreed!, style: const TextStyle(fontSize: 13, color: RdvColors.onSurfaceVariant)),
                  ],
                ),
              ),
            ],
          ),
          if (a.notes.isNotEmpty) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: RdvColors.secondaryFixed.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.favorite_border, size: 18, color: RdvColors.secondary),
                      const SizedBox(width: 6),
                      Text(
                        a.isBooking ? 'Notes de soin pour le prestataire' : 'Notes personnelles & matériel',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: RdvColors.onSecondaryContainer),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(a.notes, style: const TextStyle(fontSize: 13, height: 1.4, color: RdvColors.onSurface)),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          SoftButton(label: 'Carnet santé', icon: Icons.bookmark_add_outlined, onPressed: () => openHealthRecord(context)),
        ],
      ),
    );
  }
}

/// « Prestataire de soin » pour une réservation, « Lieu du rendez-vous » pour un rendez-vous personnel.
class _PlaceCard extends StatelessWidget {
  const _PlaceCard({required this.appointment});

  final Appointment appointment;

  @override
  Widget build(BuildContext context) {
    final a = appointment;
    final address = a.providerAddress ?? a.location;

    return RdvCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _CardTitle(
            icon: a.isBooking ? Icons.storefront_outlined : Icons.home_outlined,
            title: a.isBooking ? 'Prestataire de soin' : 'Lieu du rendez-vous',
          ),
          const SizedBox(height: 12),
          Text(
            a.providerName ?? a.place.label,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: RdvColors.onSurface),
          ),
          if (address.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(address, style: const TextStyle(fontSize: 14, color: RdvColors.onSurfaceVariant)),
            const SizedBox(height: 12),
            // Aperçu du lieu (sans clé de carte) : le bouton Itinéraire ouvre la vraie carte.
            Container(
              height: 120,
              decoration: BoxDecoration(
                color: RdvColors.surfaceContainer,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: RdvColors.outlineVariant.withValues(alpha: 0.5)),
              ),
              child: Stack(
                children: [
                  const Center(child: Icon(Icons.location_on, size: 40, color: RdvColors.primaryContainer)),
                  Positioned(
                    left: 8,
                    bottom: 8,
                    right: 8,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.location_on_outlined, size: 14, color: RdvColors.onSurfaceVariant),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                address,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: SoftButton(
                  label: 'Itinéraire',
                  icon: Icons.directions_outlined,
                  onPressed: address.isEmpty ? null : () => openDirections(context, address),
                ),
              ),
              if (a.isBooking) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: SoftButton(
                    label: 'Appeler',
                    icon: Icons.call_outlined,
                    onPressed: () => callPhone(context, a.providerPhone),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _ReminderCard extends StatelessWidget {
  const _ReminderCard({required this.appointment, required this.busy, required this.onToggle});

  final Appointment appointment;
  final bool busy;
  final ValueChanged<bool> onToggle;

  @override
  Widget build(BuildContext context) {
    final a = appointment;
    final enabled = a.reminderMinutes > 0;
    final offset = enabled ? a.reminderMinutes : 1440;

    return RdvCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _CardTitle(icon: Icons.notifications_active_outlined, title: 'Rappels & Alertes'),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Me rappeler ${formatReminderOffset(offset)}',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                    ),
                    Text(
                      enabled
                          ? '${formatReminderMoment(a.startsAt.subtract(Duration(minutes: offset)))}'
                              '${a.pushReminder ? ' (Push & SMS)' : ''}'
                          : 'Rappel désactivé',
                      style: const TextStyle(fontSize: 13, color: RdvColors.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              Switch(
                value: enabled,
                activeTrackColor: RdvColors.primary,
                onChanged: busy || !a.status.isActive ? null : onToggle,
              ),
            ],
          ),
          const SizedBox(height: 12),
          SoftButton(
            label: 'Ajouter à Google Agenda / Apple Calendar',
            icon: Icons.calendar_month_outlined,
            height: 48,
            onPressed: () => addToCalendar(context, a),
          ),
        ],
      ),
    );
  }
}

class _ProviderCard extends StatelessWidget {
  const _ProviderCard({
    required this.appointment,
    required this.busy,
    required this.onConfirm,
    required this.onPropose,
  });

  final Appointment appointment;
  final bool busy;
  final VoidCallback onConfirm;
  final VoidCallback onPropose;

  @override
  Widget build(BuildContext context) {
    final a = appointment;
    return RdvCard(
      color: RdvColors.surfaceLow,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _CardTitle(
            icon: Icons.badge_outlined,
            title: 'Espace Prestataire',
            trailing: StatusPill(
              label: 'Vue salon partenaire',
              background: RdvColors.primaryFixed.withValues(alpha: 0.6),
              foreground: RdvColors.onPrimaryFixedVariant,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            a.status == AppointmentStatus.planned
                ? 'Cette demande de réservation est en attente de votre validation pour bloquer '
                    'définitivement le créneau de ${formatTime(a.startsAt)}.'
                : 'Vous avez confirmé ce créneau de ${formatTime(a.startsAt)}.',
            style: const TextStyle(fontSize: 14, height: 1.4, color: RdvColors.onSurface),
          ),
          const SizedBox(height: 14),
          if (a.canConfirm()) ...[
            FilledButton.icon(
              onPressed: busy ? null : onConfirm,
              style: FilledButton.styleFrom(backgroundColor: RdvColors.primary, minimumSize: const Size.fromHeight(48)),
              icon: const Icon(Icons.check_circle_outline),
              label: const Text('Confirmer le rendez-vous'),
            ),
            const SizedBox(height: 8),
          ],
          if (a.canReschedule())
            OutlinedButton.icon(
              onPressed: busy ? null : onPropose,
              style: OutlinedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: RdvColors.primary,
                side: BorderSide.none,
                minimumSize: const Size.fromHeight(46),
              ),
              icon: const Icon(Icons.update),
              label: const Text('Proposer un autre horaire', style: TextStyle(fontWeight: FontWeight.w600)),
            ),
        ],
      ),
    );
  }
}

/// Historique du rendez-vous : l'ancien horaire reste visible après un report (RG-18).
class _HistoryCard extends StatelessWidget {
  const _HistoryCard({required this.changes});

  final List<AppointmentChange> changes;

  @override
  Widget build(BuildContext context) {
    return RdvCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _CardTitle(icon: Icons.history, title: 'Historique'),
          const SizedBox(height: 8),
          for (final c in changes)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 5),
                    child: Icon(Icons.circle, size: 8, color: RdvColors.primaryContainer),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${c.action.label} · ${formatDayMonth(c.at)} ${formatTime(c.at)}',
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                        ),
                        if (c.oldStart != null && c.newStart != null)
                          Text(
                            '${formatDayMonth(c.oldStart!)} ${formatTime(c.oldStart!)} → '
                            '${formatDayMonth(c.newStart!)} ${formatTime(c.newStart!)}',
                            style: const TextStyle(fontSize: 13, color: RdvColors.onSurfaceVariant),
                          ),
                        if (c.reason != null)
                          Text('Motif : ${c.reason}', style: const TextStyle(fontSize: 13, color: RdvColors.onSurfaceVariant)),
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

/// Confirmation d'annulation, avec un motif facultatif. Renvoie le motif, ou null si l'on garde le rendez-vous.
class _CancelDialog extends StatefulWidget {
  const _CancelDialog({required this.appointment});

  final Appointment appointment;

  @override
  State<_CancelDialog> createState() => _CancelDialogState();
}

class _CancelDialogState extends State<_CancelDialog> {
  final _reason = TextEditingController();

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.appointment;
    return AlertDialog(
      title: const Text('Annuler ce rendez-vous ?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '« ${a.title} » pour ${a.petName}, prévu le ${formatLongDate(a.startsAt)} à '
            '${formatTime(a.startsAt)}, sera annulé. Cette action est définitive.',
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _reason,
            maxLength: 200,
            decoration: const InputDecoration(labelText: 'Motif (facultatif)'),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Garder')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: RdvColors.error, minimumSize: const Size(0, 44)),
          onPressed: () => Navigator.of(context).pop(_reason.text.trim()),
          child: const Text('Annuler le rendez-vous'),
        ),
      ],
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(text, textAlign: TextAlign.center, style: const TextStyle(color: RdvColors.onSurfaceVariant)),
      ),
    );
  }
}
