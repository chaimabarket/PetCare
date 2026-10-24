import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'appointment_repository.dart';
import 'reminder.dart';

/// Rappels de soins créés à la main (`reminders/{id}`).
///
/// Les rappels des rendez-vous ne sont pas stockés ici : ils sont calculés à partir des
/// rendez-vous actifs, ce qui évite qu'un rappel reste visible après un report ou une annulation.
class ReminderRepository {
  ReminderRepository({FirebaseFirestore? firestore, FirebaseAuth? auth})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  CollectionReference<Map<String, dynamic>> get _collection => _firestore.collection('reminders');

  /// Les rappels de l'utilisateur, triés par échéance.
  Stream<List<Reminder>> watch(String uid) => _collection
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

    await _collection.add({
      'ownerId': uid,
      'petName': petName.trim(),
      'petBreed': petBreed,
      'petPhotoUrl': petPhotoUrl,
      'title': title.trim(),
      'description': (description ?? '').trim().isEmpty ? null : description!.trim(),
      'detail': (detail ?? '').trim().isEmpty ? null : detail!.trim(),
      'category': category.firestoreValue,
      'dueAt': Timestamp.fromDate(dueAt),
      'done': false,
      'doneAt': null,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Bouton « Fait » (ou annulation du « Fait »).
  Future<void> setDone(String id, {required bool done}) => _collection.doc(id).update({
        'done': done,
        'doneAt': done ? FieldValue.serverTimestamp() : null,
      });

  Future<void> delete(String id) => _collection.doc(id).delete();
}
