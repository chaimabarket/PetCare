import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:projet_flutter/core/routes.dart';
import 'package:projet_flutter/features/appointments/data/appointment.dart';
import 'package:projet_flutter/features/appointments/presentation/appointment_actions.dart';
import 'package:projet_flutter/features/appointments/presentation/appointment_form_screen.dart';

/// Régression : « Reporter le rendez-vous » ne faisait rien, car `pushNamed<bool>` sur une route de la
/// table `routes:` (`MaterialPageRoute<dynamic>`) lève une TypeError.
void main() {
  testWidgets('Reporter ouvre le formulaire de report puis affiche la confirmation', (tester) async {
    final start = DateTime.now().add(const Duration(days: 2));
    final appointment = Appointment(
      id: 'a1',
      ownerId: 'owner',
      petName: 'Milo',
      title: 'Toilettage',
      type: AppointmentType.grooming,
      startsAt: start,
      endsAt: start.add(const Duration(minutes: 45)),
      status: AppointmentStatus.confirmed,
    );

    await tester.pumpWidget(MaterialApp(
      // Même mécanisme que l'application : une table de routes nommées.
      routes: {
        AppRoutes.appointmentForm: (context) {
          final args = ModalRoute.of(context)!.settings.arguments! as AppointmentFormArgs;
          return Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text('Formulaire de report : ${args.reschedule!.title}'),
            ),
          );
        },
      },
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => openReschedule(context, appointment),
            child: const Text('Reporter'),
          ),
        ),
      ),
    ));

    await tester.tap(find.text('Reporter'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Formulaire de report : Toilettage'), findsOneWidget);

    await tester.tap(find.text('Formulaire de report : Toilettage'));
    await tester.pumpAndSettle();
    expect(find.text('Rendez-vous reporté.'), findsOneWidget);
  });
}
