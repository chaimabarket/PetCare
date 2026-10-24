import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';

import 'pet.dart';
import 'pet_media.dart';

/// Nombre maximum de photos par animal (FR-06).
const maxPetPhotos = 5;

/// Photo du formulaire : déjà enregistrée ([id] renseigné) ou nouvellement choisie.
class EditablePhoto {
  const EditablePhoto({required this.bytes, this.id});

  final String? id;
  final Uint8List bytes;
}

/// Une pesée existe déjà à cette date (UNIQUE(pet_id, measured_on)).
class DuplicateWeightException implements Exception {
  const DuplicateWeightException();
}

/// Lecture et écriture des animaux `pets/{petId}` et de leurs sous-collections `photos` et `weights`.
class PetRepository {
  PetRepository({FirebaseFirestore? firestore}) : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _pets => _firestore.collection('pets');
  CollectionReference<Map<String, dynamic>> _photos(String petId) => _pets.doc(petId).collection('photos');
  CollectionReference<Map<String, dynamic>> _weights(String petId) => _pets.doc(petId).collection('weights');

  /// Tous les animaux du compte (actifs et archivés), triés côté client.
  Stream<List<Pet>> watchMine(String uid) => _pets
      .where('ownerId', isEqualTo: uid)
      .snapshots()
      .map((snap) => snap.docs.map(Pet.fromFirestore).toList());

  Stream<Pet?> watch(String petId) =>
      _pets.doc(petId).snapshots().map((doc) => doc.exists ? Pet.fromFirestore(doc) : null);

  Stream<List<PetPhoto>> watchPhotos(String petId) => _photos(petId)
      .orderBy('sortOrder')
      .snapshots()
      .map((snap) => snap.docs.map(PetPhoto.fromFirestore).toList());

  /// Photo principale (position 0), ou `null` si la galerie est vide.
  Stream<PetPhoto?> watchCover(String petId) => _photos(petId)
      .orderBy('sortOrder')
      .limit(1)
      .snapshots()
      .map((snap) => snap.docs.isEmpty ? null : PetPhoto.fromFirestore(snap.docs.first));

  /// Pesées, la plus récente d'abord.
  Stream<List<WeightEntry>> watchWeights(String petId, {int? limit}) {
    Query<Map<String, dynamic>> query = _weights(petId).orderBy('measuredOn', descending: true);
    if (limit != null) query = query.limit(limit);
    return query.snapshots().map((snap) => snap.docs.map(WeightEntry.fromFirestore).toList());
  }

  /// Crée l'animal, ses photos et sa première pesée en une seule écriture atomique.
  Future<String> create({
    required String ownerId,
    required PetDraft draft,
    required List<Uint8List> photos,
    double? weightKg,
  }) async {
    final petRef = _pets.doc();
    final batch = _firestore.batch()
      ..set(petRef, {
        ...draft.toMap(),
        'ownerId': ownerId,
        'status': PetStatus.active.code,
        'archivedReason': null,
        'favorite': false,
        'contacts': <Map<String, dynamic>>[],
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    for (var i = 0; i < photos.length && i < maxPetPhotos; i++) {
      batch.set(_photos(petRef.id).doc(), _photoData(photos[i], i));
    }
    if (weightKg != null) _setTodayWeight(batch, petRef.id, weightKg);
    await batch.commit();
    return petRef.id;
  }

  /// Met à jour la fiche et remplace la galerie par [photos] (dans l'ordre, la première en couverture).
  Future<void> update({
    required String petId,
    required PetDraft draft,
    required List<EditablePhoto> photos,
    required List<String> previousPhotoIds,
    double? weightKg,
  }) async {
    final batch = _firestore.batch()
      ..update(_pets.doc(petId), {...draft.toMap(), 'updatedAt': FieldValue.serverTimestamp()});

    final keptIds = photos.map((p) => p.id).whereType<String>().toSet();
    for (final id in previousPhotoIds) {
      if (!keptIds.contains(id)) batch.delete(_photos(petId).doc(id));
    }
    for (var i = 0; i < photos.length && i < maxPetPhotos; i++) {
      final photo = photos[i];
      if (photo.id == null) {
        batch.set(_photos(petId).doc(), _photoData(photo.bytes, i));
      } else {
        batch.update(_photos(petId).doc(photo.id), {'sortOrder': i});
      }
    }
    if (weightKg != null) _setTodayWeight(batch, petId, weightKg);
    await batch.commit();
  }

  /// Ajoute une photo en fin de galerie depuis la fiche.
  Future<void> addPhoto(String petId, Uint8List bytes, {required int position}) =>
      _photos(petId).add(_photoData(bytes, position));

  /// Supprime une photo et recompacte l'ordre pour garder la couverture en position 0.
  Future<void> deletePhoto(String petId, List<PetPhoto> gallery, String photoId) async {
    final batch = _firestore.batch()..delete(_photos(petId).doc(photoId));
    var order = 0;
    for (final photo in gallery) {
      if (photo.id == photoId) continue;
      if (photo.sortOrder != order) batch.update(_photos(petId).doc(photo.id), {'sortOrder': order});
      order++;
    }
    await batch.commit();
  }

  /// Place la photo en position 0 (photo principale).
  Future<void> setCover(String petId, List<PetPhoto> gallery, String photoId) async {
    final ordered = [
      ...gallery.where((p) => p.id == photoId),
      ...gallery.where((p) => p.id != photoId),
    ];
    final batch = _firestore.batch();
    for (var i = 0; i < ordered.length; i++) {
      batch.update(_photos(petId).doc(ordered[i].id), {'sortOrder': i});
    }
    await batch.commit();
  }

  /// Enregistre une pesée. Lève [DuplicateWeightException] si une mesure existe déjà ce jour-là.
  Future<void> addWeight(String petId, {required DateTime date, required double weightKg, String? note}) {
    final day = DateTime(date.year, date.month, date.day);
    final ref = _weights(petId).doc(WeightEntry.idFor(day));
    return _firestore.runTransaction((tx) async {
      final existing = await tx.get(ref);
      if (existing.exists) throw const DuplicateWeightException();
      tx.set(ref, _weightData(day, weightKg, note));
    });
  }

  Future<void> deleteWeight(String petId, String entryId) => _weights(petId).doc(entryId).delete();

  Future<void> setNotes(String petId, String notes) => _pets.doc(petId).update({
        'notes': notes.trim().isEmpty ? null : notes.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

  Future<void> setFavorite(String petId, bool favorite) => _pets.doc(petId).update({
        'favorite': favorite,
        'updatedAt': FieldValue.serverTimestamp(),
      });

  Future<void> setContacts(String petId, List<PetContact> contacts) => _pets.doc(petId).update({
        'contacts': contacts.map((c) => c.toMap()).toList(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

  /// Archive l'animal (RG-06) : l'historique est conservé, la fiche quitte la liste des actifs.
  Future<void> archive(String petId) => _pets.doc(petId).update({
        'status': PetStatus.archived.code,
        'archivedReason': 'USER',
        'updatedAt': FieldValue.serverTimestamp(),
      });

  Future<void> restore(String petId) => _pets.doc(petId).update({
        'status': PetStatus.active.code,
        'archivedReason': null,
        'updatedAt': FieldValue.serverTimestamp(),
      });

  Map<String, dynamic> _photoData(Uint8List bytes, int position) => {
        'data': Blob(bytes),
        'sortOrder': position,
        'createdAt': FieldValue.serverTimestamp(),
      };

  Map<String, dynamic> _weightData(DateTime day, double weightKg, String? note) => {
        'measuredOn': Timestamp.fromDate(day),
        'weightKg': weightKg,
        'note': note == null || note.trim().isEmpty ? null : note.trim(),
        'createdAt': FieldValue.serverTimestamp(),
      };

  void _setTodayWeight(WriteBatch batch, String petId, double weightKg) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    batch.set(_weights(petId).doc(WeightEntry.idFor(today)), _weightData(today, weightKg, null));
  }
}
