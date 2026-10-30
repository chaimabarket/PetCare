import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/polling.dart';
import 'appointment_repository.dart';
import 'reminder.dart';

/// Rappels de soins créés à la main (`reminders/{id}`).
///
/// Tout passe par l'API REST PetCare (`/api/reminders`) ; si le serveur est injoignable,
/// les mêmes opérations passent directement par Firestore.
///
/// Les rappels des rendez-vous ne sont pas stockés ici : ils sont calculés à partir des
/// rendez-vous actifs, ce qui évite qu'un rappel reste visible après un report ou une annulation.
class ReminderRepository {
  ReminderRepository({FirebaseFirestore? firestore, FirebaseAuth? auth, ApiClient? api})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance,
        _api = api ?? ApiClient();

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final ApiClient _api;

  CollectionReference<Map<String, dynamic>> get _collection => _firestore.collection('reminders');

  Future<T> _read<T>(Future<T> Function() viaApi, Future<T> Function() viaFirestore) async {
    try {
      return await viaApi();
    } on ApiException catch (e) {
      if (e.isUnreachable) return viaFirestore();
      throw AppointmentException(e.message);
    }
  }

  Future<void> _write(Future<void> Function() viaApi, Future<void> Function() viaFirestore) async {
    try {
      await viaApi();
    } on ApiException catch (e) {
      if (!e.isUnreachable) throw AppointmentException(e.message);
      await viaFirestore();
    } finally {
      notifyApiDataChanged();
    }
  }

  /// Les rappels de l'utilisateur, triés par échéance.
  Stream<List<Reminder>> watch(String uid) => poll(() => _read(
        () async => [
          for (final item in await _api.get('/api/reminders') as List<dynamic>)
            Reminder.fromJson(item as Map<String, dynamic>),
        ],
        () => _watchFirestore(uid).first,
      ));

  Stream<List<Reminder>> _watchFirestore(String uid) => _collection
      .where('ownerId', isEqualTo: uid)
      .snapshots()
      .map((snap) => snap.docs.map(Reminder.fromFirestore).toList()..sort((a, b) => a.dueAt.compareTo(b.dueAt)));

  Future<void> create({
    required String petName,
    String? petBreed,
    String? petPhotoUrl,
    required String title,
    String? description,
    String? detail,
    required ReminderCategory category,
    required DateTime dueAt,
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw const AppointmentException('Connectez-vous pour créer un rappel.');
    if (title.trim().isEmpty) throw const AppointmentException("L'intitulé est obligatoire.");
    if (petName.trim().isEmpty) throw const AppointmentException("Choisissez l'animal concerné.");

    String? clean(String? value) => (value ?? '').trim().isEmpty ? null : value!.trim();

    await _write(
      () => _api.post('/api/reminders', {
        'petName': petName.trim(),
        'petBreed': petBreed,
        'petPhotoUrl': petPhotoUrl,
        'title': title.trim(),
        'description': clean(description),
        'detail': clean(detail),
        'category': category.firestoreValue,
        'dueAt': dueAt.toUtc().toIso8601String(),
      }),
      () => _collection.add({
        'ownerId': uid,
        'petName': petName.trim(),
        'petBreed': petBreed,
        'petPhotoUrl': petPhotoUrl,
        'title': title.trim(),
        'description': clean(description),
        'detail': clean(detail),
        'category': category.firestoreValue,
        'dueAt': Timestamp.fromDate(dueAt),
        'done': false,
        'doneAt': null,
        'createdAt': FieldValue.serverTimestamp(),
      }),
    );
  }

  /// Bouton « Fait » (ou annulation du « Fait »).
  Future<void> setDone(String id, {required bool done}) => _write(
        () => _api.patch('/api/reminders/$id', {'done': done}),
        () => _collection.doc(id).update({
          'done': done,
          'doneAt': done ? FieldValue.serverTimestamp() : null,
        }),
      );

  Future<void> delete(String id) => _write(
        () => _api.delete('/api/reminders/$id'),
        () => _collection.doc(id).delete(),
      );
}
