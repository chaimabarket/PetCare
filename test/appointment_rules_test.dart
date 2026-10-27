import 'package:flutter_test/flutter_test.dart';
import 'package:projet_flutter/features/appointments/data/appointment.dart';
import 'package:projet_flutter/features/appointments/data/appointment_format.dart';

Appointment _appointment({
  required AppointmentStatus status,
  required DateTime start,
  Duration duration = const Duration(minutes: 45),
  String? providerId,
}) =>
    Appointment(
      id: 'a1',
      ownerId: 'owner',
      petName: 'Milo',
      title: 'Toilettage',
      type: AppointmentType.grooming,
      startsAt: start,
      endsAt: start.add(duration),
      status: status,
      providerId: providerId,
    );

void main() {
  final now = DateTime(2026, 11, 12, 10);

  group('Transitions (RG-16 à RG-19)', () {
    test('une réservation en attente et future peut être confirmée', () {
      final a = _appointment(status: AppointmentStatus.planned, start: now.add(const Duration(days: 1)), providerId: 'p');
      expect(a.canConfirm(now), isTrue);
    });

    test('un rendez-vous confirmé ne se confirme pas une seconde fois', () {
      final a = _appointment(status: AppointmentStatus.confirmed, start: now.add(const Duration(days: 1)));
      expect(a.canConfirm(now), isFalse);
    });

    test('report et annulation sont refusés après le début', () {
      final a = _appointment(status: AppointmentStatus.confirmed, start: now.subtract(const Duration(minutes: 10)));
      expect(a.canReschedule(now), isFalse);
      expect(a.canCancel(now), isFalse);
    });

    test('« Terminé » seulement depuis Confirmé et après la fin', () {
      final past = now.subtract(const Duration(hours: 2));
      expect(_appointment(status: AppointmentStatus.confirmed, start: past).canComplete(now), isTrue);
      expect(_appointment(status: AppointmentStatus.planned, start: past).canComplete(now), isFalse);
      expect(
        _appointment(status: AppointmentStatus.confirmed, start: now.subtract(const Duration(minutes: 10))).canComplete(now),
        isFalse,
      );
    });

    test('annulé et terminé sont définitifs', () {
      final future = now.add(const Duration(days: 2));
      for (final status in [AppointmentStatus.cancelled, AppointmentStatus.completed]) {
        final a = _appointment(status: status, start: future);
        expect(a.canReschedule(now) || a.canCancel(now) || a.canConfirm(now), isFalse);
      }
    });
  });

  group('Chevauchement de créneaux', () {
    final a = _appointment(status: AppointmentStatus.confirmed, start: DateTime(2026, 11, 12, 15));

    test('un créneau qui commence pendant le rendez-vous est en conflit', () {
      expect(a.overlaps(DateTime(2026, 11, 12, 15, 30), DateTime(2026, 11, 12, 16, 15)), isTrue);
    });

    test('un créneau qui commence à la fin exacte ne chevauche pas', () {
      expect(a.overlaps(DateTime(2026, 11, 12, 15, 45), DateTime(2026, 11, 12, 16, 30)), isFalse);
    });
  });

  group('Format des dates', () {
    test('date longue en français', () {
      expect(formatLongDate(DateTime(2024, 11, 12)), 'Mardi 12 novembre 2024');
    });

    test('numéro de semaine ISO', () {
      expect(isoWeekNumber(DateTime(2024, 11, 12)), 46);
      expect(isoWeekNumber(DateTime(2026, 1, 1)), 1);
    });

    test('délai de rappel', () {
      expect(formatReminderOffset(0), 'Sans rappel');
      expect(formatReminderOffset(60), '1 heure avant');
      expect(formatReminderOffset(1440), '1 jour avant');
      expect(formatReminderOffset(2880), '2 jours avant');
    });

    test('jour relatif', () {
      final base = DateTime(2024, 11, 9, 9);
      expect(formatRelativeDay(DateTime(2024, 11, 12, 14), now: base), 'Dans 3 jours');
      expect(formatRelativeDay(DateTime(2024, 11, 10, 8), now: base), 'Demain');
    });

    test('prix en dinars', () {
      expect(formatPrice(45), '45,00 DT');
    });
  });
}
