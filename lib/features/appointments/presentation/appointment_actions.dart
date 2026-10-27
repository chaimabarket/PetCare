import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/routes.dart';
import '../data/appointment.dart';
import 'appointment_form_screen.dart';
import 'widgets/rdv_ui.dart';

/// Ouvre le détail d'un rendez-vous.
void openAppointmentDetail(BuildContext context, Appointment appointment) {
  Navigator.of(context).pushNamed(AppRoutes.appointmentDetail, arguments: appointment.id);
}

/// Ouvre le formulaire en mode « report » pour ce rendez-vous.
Future<void> openReschedule(BuildContext context, Appointment appointment) async {
  final done = await Navigator.of(context).pushNamed<bool>(
    AppRoutes.appointmentForm,
    arguments: AppointmentFormArgs.reschedule(appointment),
  );
  if (done == true && context.mounted) {
    showRdvMessage(
      context,
      appointment.isBooking
          ? 'Rendez-vous reporté. Le prestataire doit le confirmer à nouveau.'
          : 'Rendez-vous reporté.',
    );
  }
}

/// Appelle un numéro (prestataire, salon…).
Future<void> callPhone(BuildContext context, String? phone) async {
  if (phone == null || phone.trim().isEmpty) {
    showRdvMessage(context, "Aucun numéro de téléphone n'est renseigné.");
    return;
  }
  await _open(context, Uri(scheme: 'tel', path: phone.replaceAll(' ', '')));
}

/// Ouvre l'itinéraire vers une adresse dans l'application de cartes.
Future<void> openDirections(BuildContext context, String address) => _open(
      context,
      Uri.https('www.google.com', '/maps/search/', {'api': '1', 'query': address}),
    );

/// Ajoute le rendez-vous à Google Agenda (Apple Calendar accepte aussi ce lien depuis le navigateur).
Future<void> addToCalendar(BuildContext context, Appointment a) {
  String stamp(DateTime d) {
    final u = d.toUtc();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${u.year}${two(u.month)}${two(u.day)}T${two(u.hour)}${two(u.minute)}00Z';
  }

  return _open(
    context,
    Uri.https('calendar.google.com', '/calendar/render', {
      'action': 'TEMPLATE',
      'text': '${a.title} – ${a.petName}',
      'dates': '${stamp(a.startsAt)}/${stamp(a.endsAt)}',
      'details': 'Rendez-vous PetCare Community pour ${a.petName}.',
      'location': a.providerAddress ?? a.location,
    }),
  );
}

Future<void> _open(BuildContext context, Uri uri) async {
  try {
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) showRdvMessage(context, "Impossible d'ouvrir ce lien sur cet appareil.");
  } catch (_) {
    if (context.mounted) showRdvMessage(context, "Impossible d'ouvrir ce lien sur cet appareil.");
  }
}

void showRdvMessage(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message), behavior: SnackBarBehavior.floating));
}

void showRdvError(BuildContext context, Object error) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(friendlyError(error)),
      backgroundColor: RdvColors.error,
      behavior: SnackBarBehavior.floating,
    ));
}
