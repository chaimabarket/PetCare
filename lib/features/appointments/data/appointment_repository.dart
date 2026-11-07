import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/polling.dart';
import '../../notifications/data/app_notification.dart';
import '../../notifications/data/notification_service.dart';
import 'appointment.dart';
import 'appointment_format.dart';

/// Erreur métier affichable telle quelle à l'utilisateur.
class AppointmentException implements Exception {
  const AppointmentException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Lecture et actions sur les rendez-vous (`appointments/{id}`).
///
/// Tout passe par l'API REST PetCare (`/api/appointments`, dossier `backend/`) ; si le serveur
/// est injoignable, les mêmes opérations passent directement par Firestore.
///
/// Chaque action vérifie les règles du cahier des charges (RG-12 à RG-21) : ici en secours,
/// sur le serveur sinon, et toujours dans les règles Firestore (`firestore.rules`).
class AppointmentRepository {
  AppointmentRepository({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    NotificationService? notifications,
    ApiClient? api,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance,
        _notifications = notifications ?? NotificationService(firestore: firestore),
        _api = api ?? ApiClient();

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final NotificationService _notifications;
  final ApiClient _api;

  CollectionReference<Map<String, dynamic>> get _collection => _firestore.collection('appointments');

  String get _uid {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw const AppointmentException('Connectez-vous pour gérer vos rendez-vous.');
    return uid;
  }

  /// Lit par l'API ; si le serveur est éteint, [viaFirestore] prend le relais.
  Future<T> _read<T>(Future<T> Function() viaApi, Future<T> Function() viaFirestore) async {
    try {
      return await viaApi();
    } on ApiException catch (e) {
      if (e.isUnreachable) return viaFirestore();
      throw AppointmentException(e.message);
    }
  }

  /// Écrit par l'API ; un refus du serveur devient une erreur affichable. Les écrans se rafraîchissent aussitôt.
  Future<T> _write<T>(Future<T> Function() viaApi, Future<T> Function() viaFirestore) async {
    try {
      return await viaApi();
    } on ApiException catch (e) {
      if (e.isUnreachable) return viaFirestore();
      throw AppointmentException(e.message);
    } finally {
      notifyApiDataChanged();
    }
  }

  static String _iso(DateTime d) => d.toUtc().toIso8601String();

  static List<Appointment> _listFrom(dynamic json) =>
      [for (final item in json as List<dynamic>) Appointment.fromJson(item as Map<String, dynamic>)];

  // ---------------------------------------------------------------------------
  // Lecture
  // ---------------------------------------------------------------------------

  /// Les rendez-vous de l'utilisateur : ceux de ses animaux et, s'il est prestataire,
  /// les réservations qu'il a reçues. Triés par date de début.
  Stream<List<Appointment>> watchAgenda(String uid) => poll(() => _read(
        () async => _listFrom(await _api.get('/api/appointments')),
        () => _agendaFirestore(uid).first,
      ));

  Stream<List<Appointment>> _agendaFirestore(String uid) {
    // Deux requêtes simples (sans index composite) fusionnées à la main.
    final mine = _collection.where('ownerId', isEqualTo: uid).snapshots();
    final received = _collection.where('providerId', isEqualTo: uid).snapshots();

    late StreamController<List<Appointment>> controller;
    final subscriptions = <StreamSubscription<QuerySnapshot<Map<String, dynamic>>>>[];
    var mineDocs = <Appointment>[];
    var receivedDocs = <Appointment>[];

    void emit() {
      final byId = {for (final a in [...mineDocs, ...receivedDocs]) a.id: a};
      final list = byId.values.toList()..sort((a, b) => a.startsAt.compareTo(b.startsAt));
      controller.add(list);
    }

    controller = StreamController<List<Appointment>>(
      onListen: () {
        subscriptions
          ..add(mine.listen((snap) {
            mineDocs = snap.docs.map(Appointment.fromFirestore).toList();
            emit();
          }, onError: controller.addError))
          ..add(received.listen((snap) {
            receivedDocs = snap.docs.map(Appointment.fromFirestore).toList();
            emit();
          }, onError: (Object _) {
            // Un propriétaire n'a pas de réservations reçues : on ignore simplement.
          }));
      },
      onCancel: () async {
        for (final s in subscriptions) {
          await s.cancel();
        }
      },
    );
    return controller.stream;
  }

  /// Un rendez-vous, rafraîchi régulièrement. Émet null s'il n'existe pas ou n'est pas accessible.
  Stream<Appointment?> watchOne(String id) => poll(() async {
        try {
          return Appointment.fromJson(await _api.get('/api/appointments/$id') as Map<String, dynamic>);
        } on ApiException catch (e) {
          if (e.statusCode == 404 || e.statusCode == 403) return null;
          if (!e.isUnreachable) throw AppointmentException(e.message);
          final doc = await _collection.doc(id).get();
          return doc.exists ? Appointment.fromFirestore(doc) : null;
        }
      });

  // ---------------------------------------------------------------------------
  // Création
  // ---------------------------------------------------------------------------

  /// FR-11 : crée un rendez-vous personnel. Il démarre « Confirmé » (RG-16).
  ///
  /// Refuse un créneau qui chevauche un autre rendez-vous actif du même animal.
  Future<String> createPersonal({
    required String petName,
    String? petId,
    String? petBreed,
    String? petPhotoUrl,
    required String title,
    required AppointmentType type,
    required DateTime startsAt,
    required Duration duration,
    required AppointmentPlace place,
    required String location,
    String notes = '',
    int reminderMinutes = 1440,
    bool pushReminder = true,
  }) {
    _uid; // Connexion requise.
    return _write(
      () async {
        final json = await _api.post('/api/appointments', {
          'petId': petId,
          'petName': petName,
          'petBreed': petBreed,
          'petPhotoUrl': petPhotoUrl,
          'title': title,
          'type': type.firestoreValue,
          'startsAt': _iso(startsAt),
          'durationMinutes': duration.inMinutes,
          'place': place.firestoreValue,
          'location': location,
          'notes': notes,
          'reminderMinutes': reminderMinutes,
          'pushReminder': pushReminder,
        }) as Map<String, dynamic>;
        return json['id'] as String;
      },
      () => _createPersonalFirestore(
        petName: petName,
        petId: petId,
        petBreed: petBreed,
        petPhotoUrl: petPhotoUrl,
        title: title,
        type: type,
        startsAt: startsAt,
        duration: duration,
        place: place,
        location: location,
        notes: notes,
        reminderMinutes: reminderMinutes,
        pushReminder: pushReminder,
      ),
    );
  }

  Future<String> _createPersonalFirestore({
    required String petName,
    String? petId,
    String? petBreed,
    String? petPhotoUrl,
    required String title,
    required AppointmentType type,
    required DateTime startsAt,
    required Duration duration,
    required AppointmentPlace place,
    required String location,
    required String notes,
    required int reminderMinutes,
    required bool pushReminder,
  }) async {
    final uid = _uid;
    final endsAt = startsAt.add(duration);
    _checkTimes(startsAt, endsAt);
    if (title.trim().isEmpty) throw const AppointmentException("L'intitulé est obligatoire.");
    if (petName.trim().isEmpty) throw const AppointmentException("Choisissez l'animal concerné.");

    final conflict = await findPetConflict(
      ownerId: uid,
      petName: petName,
      start: startsAt,
      end: endsAt,
    );
    if (conflict != null) {
      throw AppointmentException(
        '${petName.trim()} a déjà « ${conflict.title} » prévu à ${formatTime(conflict.startsAt)}.',
      );
    }

    final now = DateTime.now();
    final doc = await _collection.add({
      'ownerId': uid,
      'petId': petId,
      'petName': petName.trim(),
      'petBreed': petBreed,
      'petPhotoUrl': petPhotoUrl,
      'title': title.trim(),
      'type': type.firestoreValue,
      'startsAt': Timestamp.fromDate(startsAt),
      'endsAt': Timestamp.fromDate(endsAt),
      'status': AppointmentStatus.confirmed.firestoreValue,
      'providerId': null,
      'place': place.firestoreValue,
      'location': location.trim(),
      'notes': notes.trim(),
      'reminderMinutes': reminderMinutes,
      'pushReminder': pushReminder,
      'version': 1,
      'changes': [AppointmentChange(action: AppointmentAction.created, at: now, byUserId: uid).toMap()],
      'createdAt': FieldValue.serverTimestamp(),
    });

    await _notify(
      uid,
      'Rendez-vous ajouté',
      '${title.trim()} pour ${petName.trim()} le ${formatDayMonth(startsAt)} à ${formatTime(startsAt)}.',
    );
    return doc.id;
  }

  /// FR-11 / FR-24 : réservation d'un service, appelée par le module 6 (Services).
  /// Elle démarre « En attente » jusqu'à la confirmation du prestataire (RG-16).
  ///
  /// La capacité du prestataire (un seul animal à la fois, RG-14) doit être garantie côté
  /// serveur : les règles Firestore ne laissent pas un client lire l'agenda d'un autre client.
  Future<String> createBooking({
    required String petName,
    String? petId,
    String? petBreed,
    String? petPhotoUrl,
    required String providerId,
    required String providerName,
    String? providerAddress,
    String? providerPhone,
    required String serviceId,
    required String title,
    required AppointmentType type,
    required DateTime startsAt,
    required Duration duration,
    double? price,
    String notes = '',
    int reminderMinutes = 1440,
  }) {
    _uid; // Connexion requise.
    return _write(
      () async {
        final json = await _api.post('/api/appointments', {
          'petId': petId,
          'petName': petName,
          'petBreed': petBreed,
          'petPhotoUrl': petPhotoUrl,
          'providerId': providerId,
          'providerName': providerName,
          'providerAddress': providerAddress,
          'providerPhone': providerPhone,
          'serviceId': serviceId,
          'title': title,
          'type': type.firestoreValue,
          'startsAt': _iso(startsAt),
          'durationMinutes': duration.inMinutes,
          'price': price,
          'notes': notes,
          'reminderMinutes': reminderMinutes,
        }) as Map<String, dynamic>;
        return json['id'] as String;
      },
      () => _createBookingFirestore(
        petName: petName,
        petId: petId,
        petBreed: petBreed,
        petPhotoUrl: petPhotoUrl,
        providerId: providerId,
        providerName: providerName,
        providerAddress: providerAddress,
        providerPhone: providerPhone,
        serviceId: serviceId,
        title: title,
        type: type,
        startsAt: startsAt,
        duration: duration,
        price: price,
        notes: notes,
        reminderMinutes: reminderMinutes,
      ),
    );
  }

  Future<String> _createBookingFirestore({
    required String petName,
    String? petId,
    String? petBreed,
    String? petPhotoUrl,
    required String providerId,
    required String providerName,
    String? providerAddress,
    String? providerPhone,
    required String serviceId,
    required String title,
    required AppointmentType type,
    required DateTime startsAt,
    required Duration duration,
    double? price,
    required String notes,
    required int reminderMinutes,
  }) async {
    final uid = _uid;
    final endsAt = startsAt.add(duration);
    _checkTimes(startsAt, endsAt);

    final now = DateTime.now();
    final doc = await _collection.add({
      'ownerId': uid,
      'petId': petId,
      'petName': petName.trim(),
      'petBreed': petBreed,
      'petPhotoUrl': petPhotoUrl,
      'title': title.trim(),
      'type': type.firestoreValue,
      'startsAt': Timestamp.fromDate(startsAt),
      'endsAt': Timestamp.fromDate(endsAt),
      'status': AppointmentStatus.planned.firestoreValue,
      'providerId': providerId,
      'providerName': providerName,
      'providerAddress': providerAddress,
      'providerPhone': providerPhone,
      'serviceId': serviceId,
      'price': price,
      'place': AppointmentPlace.other.firestoreValue,
      'location': providerAddress ?? '',
      'notes': notes.trim(),
      'reminderMinutes': reminderMinutes,
      'pushReminder': true,
      'version': 1,
      'changes': [AppointmentChange(action: AppointmentAction.created, at: now, byUserId: uid).toMap()],
      'createdAt': FieldValue.serverTimestamp(),
    });

    await _notify(
      providerId,
      'Nouvelle demande de réservation',
      '$title pour $petName le ${formatDayMonth(startsAt)} à ${formatTime(startsAt)}.',
    );
    return doc.id;
  }

  /// Le rendez-vous actif du même animal qui chevauche [start, end[, s'il y en a un.
  Future<Appointment?> findPetConflict({
    required String ownerId,
    required String petName,
    required DateTime start,
    required DateTime end,
    String? ignoreId,
  }) async {
    final all = await _read(
      () async => _listFrom(await _api.get('/api/appointments')).where((a) => a.ownerId == ownerId).toList(),
      () async => (await _collection.where('ownerId', isEqualTo: ownerId).get()).docs.map(Appointment.fromFirestore).toList(),
    );
    for (final other in all) {
      if (other.id == ignoreId || !other.status.isActive) continue;
      if (other.petName.trim().toLowerCase() != petName.trim().toLowerCase()) continue;
      if (other.overlaps(start, end)) return other;
    }
    return null;
  }

  // ---------------------------------------------------------------------------
  // Transitions (FR-12, FR-13)
  // ---------------------------------------------------------------------------

  /// Envoie une action à l'API avec la version affichée (RG-20) ; en secours, [viaFirestore].
  Future<void> _action(Appointment a, String method, String path, Map<String, dynamic> body, Future<void> Function() viaFirestore) =>
      _write(
        () async {
          final payload = {...body, 'version': a.version};
          final url = '/api/appointments/${a.id}/$path';
          method == 'PUT' ? await _api.put(url, payload) : await _api.post(url, payload);
        },
        viaFirestore,
      );

  /// Le prestataire confirme une réservation en attente.
  Future<void> confirm(Appointment appointment) =>
      _action(appointment, 'POST', 'confirm', const {}, () => _confirmFirestore(appointment));

  Future<void> _confirmFirestore(Appointment appointment) => _transition(
        appointment,
        check: (a) => a.canConfirm() ? null : 'Ce rendez-vous ne peut plus être confirmé.',
        changes: (a) => {'status': AppointmentStatus.confirmed.firestoreValue},
        action: AppointmentAction.confirmed,
        notifyTitle: 'Rendez-vous confirmé',
        notifyBody: (a) =>
            '${a.title} pour ${a.petName} est confirmé le ${formatDayMonth(a.startsAt)} à ${formatTime(a.startsAt)}.',
      );

  /// Reporte avant le début, avec un motif (RG-18). Même rendez-vous, nouvel horaire, version +1.
  /// Une réservation repasse « En attente » : le prestataire doit la confirmer à nouveau.
  Future<void> reschedule(Appointment appointment, {required DateTime newStart, required String reason}) {
    if (reason.trim().isEmpty) throw const AppointmentException('Indiquez le motif du report.');
    return _action(
      appointment,
      'POST',
      'reschedule',
      {'startsAt': _iso(newStart), 'reason': reason.trim()},
      () => _rescheduleFirestore(appointment, newStart: newStart, reason: reason),
    );
  }

  Future<void> _rescheduleFirestore(Appointment appointment, {required DateTime newStart, required String reason}) async {
    final newEnd = newStart.add(appointment.duration);
    _checkTimes(newStart, newEnd);
    if (reason.trim().isEmpty) throw const AppointmentException('Indiquez le motif du report.');
    if (newStart == appointment.startsAt) {
      throw const AppointmentException("Choisissez un horaire différent de l'horaire actuel.");
    }
    final conflict = await findPetConflict(
      ownerId: appointment.ownerId,
      petName: appointment.petName,
      start: newStart,
      end: newEnd,
      ignoreId: appointment.id,
    );
    if (conflict != null) {
      throw AppointmentException(
        '${appointment.petName} a déjà « ${conflict.title} » prévu à ${formatTime(conflict.startsAt)}.',
      );
    }

    await _transition(
      appointment,
      check: (a) => a.canReschedule() ? null : 'Ce rendez-vous ne peut plus être reporté : il a commencé ou est terminé.',
      changes: (a) => {
        'startsAt': Timestamp.fromDate(newStart),
        'endsAt': Timestamp.fromDate(newEnd),
        'status': (a.isBooking ? AppointmentStatus.planned : AppointmentStatus.confirmed).firestoreValue,
        // Le rappel est recalculé pour le nouvel horaire (RG-21).
        'reminderDoneAt': null,
      },
      action: AppointmentAction.rescheduled,
      reason: reason.trim(),
      oldStart: appointment.startsAt,
      newStart: newStart,
      notifyTitle: 'Rendez-vous reporté',
      notifyBody: (a) => '${a.title} pour ${a.petName} : ${formatDayMonth(a.startsAt)} ${formatTime(a.startsAt)} → '
          '${formatDayMonth(newStart)} ${formatTime(newStart)}.'
          '${a.isBooking ? ' En attente de confirmation du prestataire.' : ''}',
    );
  }

  /// Annule un rendez-vous pas encore commencé (RG-17). CANCELLED est définitif.
  Future<void> cancel(Appointment appointment, {String reason = ''}) =>
      _action(appointment, 'POST', 'cancel', {'reason': reason.trim()}, () => _cancelFirestore(appointment, reason: reason));

  Future<void> _cancelFirestore(Appointment appointment, {required String reason}) => _transition(
        appointment,
        check: (a) => a.canCancel() ? null : 'Ce rendez-vous ne peut plus être annulé : il a déjà commencé.',
        changes: (a) => {
          'status': AppointmentStatus.cancelled.firestoreValue,
          'cancelReason': reason.trim().isEmpty ? null : reason.trim(),
        },
        action: AppointmentAction.cancelled,
        reason: reason.trim().isEmpty ? null : reason.trim(),
        notifyTitle: 'Rendez-vous annulé',
        notifyBody: (a) => '${a.title} pour ${a.petName}, prévu le ${formatDayMonth(a.startsAt)} à '
            '${formatTime(a.startsAt)}, est annulé.',
      );

  /// Termine un rendez-vous confirmé après son heure de fin (RG-19).
  Future<void> complete(Appointment appointment) =>
      _action(appointment, 'POST', 'complete', const {}, () => _completeFirestore(appointment));

  Future<void> _completeFirestore(Appointment appointment) => _transition(
        appointment,
        check: (a) => a.canComplete() ? null : "Un rendez-vous se termine après son heure de fin, s'il était confirmé.",
        changes: (a) => {'status': AppointmentStatus.completed.firestoreValue},
        action: AppointmentAction.completed,
      );

  /// Active ou désactive le rappel (« Me rappeler 1 jour avant »).
  Future<void> setReminder(Appointment appointment, {required int minutes}) => _action(
        appointment,
        'PUT',
        'reminder',
        {'minutes': minutes},
        () => _setReminderFirestore(appointment, minutes: minutes),
      );

  Future<void> _setReminderFirestore(Appointment appointment, {required int minutes}) => _transition(
        appointment,
        check: (a) => a.status.isActive ? null : 'Ce rendez-vous est terminé ou annulé.',
        changes: (a) => {'reminderMinutes': minutes, 'reminderDoneAt': null},
      );

  /// Bouton « Fait » de la liste des rappels pour un rendez-vous.
  Future<void> markReminderDone(Appointment appointment, {bool done = true}) => _action(
        appointment,
        'PUT',
        'reminder-done',
        {'done': done},
        () => _markReminderDoneFirestore(appointment, done: done),
      );

  Future<void> _markReminderDoneFirestore(Appointment appointment, {required bool done}) => _transition(
        appointment,
        check: (_) => null,
        changes: (a) => {'reminderDoneAt': done ? Timestamp.now() : null},
      );

  // ---------------------------------------------------------------------------

  /// Secours sans serveur : applique une modification dans une transaction Firestore.
  ///
  /// Si le rendez-vous a été modifié depuis son affichage (version différente), la modification
  /// est refusée plutôt que d'écraser celle de l'autre personne (RG-20).
  Future<void> _transition(
    Appointment appointment, {
    required String? Function(Appointment current) check,
    required Map<String, dynamic> Function(Appointment current) changes,
    AppointmentAction? action,
    String? reason,
    DateTime? oldStart,
    DateTime? newStart,
    String? notifyTitle,
    String Function(Appointment current)? notifyBody,
  }) async {
    final uid = _uid;
    final ref = _collection.doc(appointment.id);
    late Appointment current;

    await _firestore.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) throw const AppointmentException('Ce rendez-vous n\'existe plus.');
      current = Appointment.fromFirestore(snap);
      if (current.version != appointment.version) {
        throw const AppointmentException(
          'Ce rendez-vous vient d\'être modifié par quelqu\'un d\'autre. Vérifiez-le puis recommencez.',
        );
      }
      final error = check(current);
      if (error != null) throw AppointmentException(error);

      tx.update(ref, {
        ...changes(current),
        'version': current.version + 1,
        'updatedAt': FieldValue.serverTimestamp(),
        if (action != null)
          'changes': FieldValue.arrayUnion([
            AppointmentChange(
              action: action,
              at: DateTime.now(),
              byUserId: uid,
              reason: reason,
              oldStart: oldStart,
              newStart: newStart,
            ).toMap(),
          ]),
      });
    });

    if (notifyTitle != null && notifyBody != null) {
      // On prévient l'autre personne : le prestataire si c'est le client qui agit, et inversement.
      final target = uid == current.ownerId ? (current.providerId ?? current.ownerId) : current.ownerId;
      await _notify(target, notifyTitle, notifyBody(current));
    }
  }

  void _checkTimes(DateTime start, DateTime end) {
    if (!start.isAfter(DateTime.now())) {
      throw const AppointmentException('Le rendez-vous doit commencer dans le futur.');
    }
    if (!end.isAfter(start)) throw const AppointmentException('La fin doit être après le début.');
  }

  Future<void> _notify(String toUserId, String title, String body) async {
    try {
      await _notifications.send(
        toUserId: toUserId,
        title: title,
        body: body,
        category: NotificationCategory.appointment,
      );
    } on FirebaseException {
      // La notification est un plus : son échec ne doit pas annuler le rendez-vous.
    }
  }
}
