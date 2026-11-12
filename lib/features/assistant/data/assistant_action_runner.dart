import 'package:flutter/foundation.dart';

import '../../appointments/data/appointment.dart';
import '../../appointments/data/appointment_repository.dart';
import '../../appointments/data/reminder.dart';
import '../../appointments/data/reminder_repository.dart';
import '../../health/data/health_entry.dart';
import '../../health/data/health_repository.dart';
import '../../health/data/treatment.dart';
import '../../pets/data/pet_repository.dart';
import 'assistant_actions.dart';
import 'assistant_pet.dart';

/// Enregistre une action confirmée avec les mêmes dépôts (et donc les mêmes règles) que les formulaires.
class AssistantActionRunner {
  AssistantActionRunner({
    HealthRepository? health,
    PetRepository? pets,
    AppointmentRepository? appointments,
    ReminderRepository? reminders,
  })  : _health = health ?? HealthRepository(),
        _pets = pets ?? PetRepository(),
        _appointments = appointments ?? AppointmentRepository(),
        _reminders = reminders ?? ReminderRepository();

  final HealthRepository _health;
  final PetRepository _pets;
  final AppointmentRepository _appointments;
  final ReminderRepository _reminders;

  static const _note = "Ajouté depuis l'assistant PetCare";

  /// Lève une [Exception] dont le message est affichable tel quel.
  Future<void> run(AssistantAction a, AssistantPet pet) async {
    try {
      await _run(a, pet);
    } on DuplicateWeightException {
      throw Exception('Une pesée existe déjà ce jour-là pour ${pet.name}.');
    } on HealthException catch (e) {
      throw Exception(e.message);
    } on AppointmentException catch (e) {
      throw Exception(e.message);
    } on PetException catch (e) {
      throw Exception(e.message);
    } catch (e) {
      debugPrint('AssistantActionRunner: $e');
      throw Exception("L'enregistrement a échoué. Vérifiez votre connexion et réessayez.");
    }
  }

  Future<void> _run(AssistantAction a, AssistantPet pet) {
    String? opt(String key) => a.text(key).isEmpty ? null : a.text(key);

    switch (a.type) {
      case AssistantActionType.healthEntry:
        final now = DateTime.now();
        final day = a.date('date')!;
        // Un soin du jour garde l'heure actuelle : la règle refuse une date dans le futur.
        final today = day.year == now.year && day.month == now.month && day.day == now.day;
        final date = today ? now : DateTime(day.year, day.month, day.day, 12);
        return _health.addEntry(
          petId: pet.id,
          type: HealthEntryType.fromFirestore(a.text('type')),
          title: a.text('titre'),
          date: date,
          vaccineName: opt('nom_vaccin'),
          nextReminderAt: a.date('prochain_rappel'),
          practitioner: opt('praticien'),
          description: opt('description') ?? _note,
        );
      case AssistantActionType.treatment:
        return _health.addTreatment(
          petId: pet.id,
          category: a.text('categorie'),
          name: a.text('nom'),
          posology: a.text('posologie'),
          startDate: a.date('debut')!,
          endDate: a.date('fin')!,
          form: TreatmentForm.fromFirestore(opt('forme')),
        );
      case AssistantActionType.appointment:
        return _appointments.createPersonal(
          petId: pet.id,
          petName: pet.name,
          petBreed: pet.breed,
          title: a.text('titre'),
          type: AppointmentType.fromFirestore(a.text('type')),
          startsAt: a.startsAt!,
          duration: Duration(minutes: (a.number('duree_minutes') ?? 30).round()),
          place: AppointmentPlace.other,
          location: a.text('lieu'),
          notes: _note,
        );
      case AssistantActionType.weight:
        return _pets.addWeight(
          pet.id,
          date: a.date('date') ?? DateTime.now(),
          weightKg: a.number('poids_kg')!,
          note: _note,
        );
      case AssistantActionType.reminder:
        final day = a.date('date')!;
        return _reminders.create(
          petName: pet.name,
          petBreed: pet.breed,
          title: a.text('titre'),
          description: _note,
          category: ReminderCategory.values.where((c) => c.firestoreValue == a.text('categorie')).firstOrNull ??
              ReminderCategory.care,
          dueAt: DateTime(day.year, day.month, day.day, 9),
        );
    }
  }
}
