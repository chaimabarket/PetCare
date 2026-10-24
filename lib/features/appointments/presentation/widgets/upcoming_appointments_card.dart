import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../../core/routes.dart';
import '../../data/appointment.dart';
import '../../data/appointment_format.dart';
import '../../data/appointment_repository.dart';
import '../appointment_actions.dart';
import 'rdv_ui.dart';

/// Carte « Prochains rendez-vous » de l'Accueil (maquette Accueil) : les 2 prochains rendez-vous,
/// et le lien « Voir l'agenda ».
class UpcomingAppointmentsCard extends StatefulWidget {
  const UpcomingAppointmentsCard({super.key, required this.onOpenTab});

  /// Ouvre un onglet de la barre du bas quand l'utilisateur en touche un depuis l'agenda.
  final ValueChanged<int> onOpenTab;

  @override
  State<UpcomingAppointmentsCard> createState() => _UpcomingAppointmentsCardState();
}

class _UpcomingAppointmentsCardState extends State<UpcomingAppointmentsCard> {
  final _uid = FirebaseAuth.instance.currentUser?.uid;
  late final _stream = _uid == null ? null : AppointmentRepository().watchAgenda(_uid);

  Future<void> _open(String route) async {
    final tab = await Navigator.of(context).pushNamed<Object?>(route);
    if (tab is int) widget.onOpenTab(tab);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: Color(0x0F0F172A), blurRadius: 3, offset: Offset(0, 1))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(color: RdvColors.surfaceLow, borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.calendar_month_outlined, size: 22, color: RdvColors.primaryContainer),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Prochains rendez-vous',
                  style: TextStyle(fontSize: 19, fontWeight: FontWeight.w600, letterSpacing: -0.3),
                ),
              ),
              TextButton.icon(
                onPressed: () => _open(AppRoutes.agenda),
                iconAlignment: IconAlignment.end,
                style: TextButton.styleFrom(
                  foregroundColor: RdvColors.primary,
                  textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
                icon: const Icon(Icons.chevron_right, size: 18),
                label: const Text("Voir l'agenda"),
              ),
            ],
          ),
          const SizedBox(height: 12),
          StreamBuilder<List<Appointment>>(
            stream: _stream,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return _Note(text: friendlyError(snapshot.error!));
              }
              if (!snapshot.hasData) {
                return const Padding(
                  padding: EdgeInsets.all(12),
                  child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                );
              }
              final now = DateTime.now();
              final next = snapshot.data!.where((a) => a.status.isActive && a.endsAt.isAfter(now)).take(2).toList();
              if (next.isEmpty) return const _Note(text: 'Aucun rendez-vous à venir.');
              return Column(
                children: [
                  for (final a in next)
                    Padding(
                      padding: EdgeInsets.only(bottom: a == next.last ? 0 : 8),
                      child: _UpcomingRow(appointment: a),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _UpcomingRow extends StatelessWidget {
  const _UpcomingRow({required this.appointment});

  final Appointment appointment;

  @override
  Widget build(BuildContext context) {
    final a = appointment;
    return Material(
      color: RdvColors.surfaceLow,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: () => openAppointmentDetail(context, a),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 48,
                padding: const EdgeInsets.symmetric(vertical: 6),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
                child: Column(
                  children: [
                    Text(shortDayName(a.startsAt), style: const TextStyle(fontSize: 11, color: RdvColors.onSurfaceVariant)),
                    Text(
                      '${a.startsAt.day}',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: RdvColors.primaryContainer),
                    ),
                  ],
                ),
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
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                    ),
                    Text(
                      '${a.petName} • ${a.type.label} • ${formatTime(a.startsAt)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13, color: RdvColors.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              StatusPill.forStatus(a.status),
            ],
          ),
        ),
      ),
    );
  }
}

class _Note extends StatelessWidget {
  const _Note({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: RdvColors.surfaceLow, borderRadius: BorderRadius.circular(12)),
      child: Text(text, style: const TextStyle(fontSize: 14, height: 1.4, color: RdvColors.onSurfaceVariant)),
    );
  }
}
