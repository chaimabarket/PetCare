import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/polling.dart';
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

/// Erreur d'enregistrement, que l'écriture soit passée par l'API ou par Firestore.
class PetException implements Exception {
  const PetException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Lecture et écriture des animaux `pets/{petId}` et de leurs sous-collections `photos` et `weights`,
/// par l'API REST PetCare.
///
/// Si le serveur est éteint ou injoignable, tout passe directement par Firestore : les règles de
/// sécurité sont les mêmes, l'application reste utilisable.
class PetRepository {
  PetRepository({FirebaseFirestore? firestore, ApiClient? api})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _api = api ?? ApiClient();

  final FirebaseFirestore _firestore;
  final ApiClient _api;

  /// Les images sont lourdes : elles se rechargent après une modification, pas à chaque passage.
  static const _photoRefresh = Duration(minutes: 5);
  static const _uploadTimeout = Duration(seconds: 60);

  CollectionReference<Map<String, dynamic>> get _pets => _firestore.collection('pets');
  CollectionReference<Map<String, dynamic>> _photos(String petId) => _pets.doc(petId).collection('photos');
  CollectionReference<Map<String, dynamic>> _weights(String petId) => _pets.doc(petId).collection('weights');

  /// Lit par l'API ; si le serveur est éteint, [viaFirestore] prend le relais.
  Future<T> _read<T>(Future<T> Function() viaApi, Future<T> Function() viaFirestore) async {
    try {
      return await viaApi();
    } on ApiException catch (e) {
      if (e.isUnreachable) return viaFirestore();
      rethrow;
    }
  }

  /// Écrit par l'API, ou par Firestore si le serveur est éteint, puis rafraîchit les écrans.
  Future<T> _write<T>(Future<T> Function() viaApi, Future<T> Function() viaFirestore) async {
    try {
      final result = await _read(viaApi, viaFirestore);
      notifyApiDataChanged();
      return result;
    } on ApiException catch (e) {
      throw PetException(e.message);
    } on FirebaseException catch (e) {
      throw PetException(e.message ?? e.code);
    }
  }

  /// Tous les animaux du compte (actifs et archivés), triés côté client.
  Stream<List<Pet>> watchMine(String uid) => poll(() => _read(
        () async => [
          for (final item in await _api.get('/api/pets') as List<dynamic>) Pet.fromJson(item as Map<String, dynamic>),
        ],
        () async {
          final snap = await _pets.where('ownerId', isEqualTo: uid).get();
          return snap.docs.map(Pet.fromFirestore).toList();
        },
      ));

  Stream<Pet?> watch(String petId) => poll(() => _read<Pet?>(
        () async {
          try {
            return Pet.fromJson(await _api.get('/api/pets/$petId') as Map<String, dynamic>);
          } on ApiException catch (e) {
            if (e.statusCode == 404) return null;
            rethrow;
          }
        },
        () async {
          final doc = await _pets.doc(petId).get();
          return doc.exists ? Pet.fromFirestore(doc) : null;
        },
      ));

  Stream<List<PetPhoto>> watchPhotos(String petId) => poll(
        () => _read(
          () async => [
            for (final item in await _api.get('/api/pets/$petId/photos') as List<dynamic>)
              PetPhoto.fromJson(item as Map<String, dynamic>),
          ],
          () => _retryWhileUnconfirmed(
            () => _photos(petId).orderBy('sortOrder').snapshots().map((snap) => snap.docs.map(PetPhoto.fromFirestore).toList()),
          ).first,
        ),
        every: _photoRefresh,
      );

  /// Photo principale (position 0), ou `null` si la galerie est vide.
  Stream<PetPhoto?> watchCover(String petId) => poll(
        () => _read<PetPhoto?>(
          () async {
            final json = await _api.get('/api/pets/$petId/cover');
            return json == null ? null : PetPhoto.fromJson(json as Map<String, dynamic>);
          },
          () => _retryWhileUnconfirmed(
            () => _photos(petId)
                .orderBy('sortOrder')
                .limit(1)
                .snapshots()
                .map((snap) => snap.docs.isEmpty ? null : PetPhoto.fromFirestore(snap.docs.first)),
          ).first,
        ),
        every: _photoRefresh,
      );

  /// Pesées, la plus récente d'abord.
  Stream<List<WeightEntry>> watchWeights(String petId, {int? limit}) => poll(() => _read(
        () async => [
          for (final item in await _api.get('/api/pets/$petId/weights${limit == null ? '' : '?limit=$limit'}') as List<dynamic>)
            WeightEntry.fromJson(item as Map<String, dynamic>),
        ],
        () => _retryWhileUnconfirmed(() {
          Query<Map<String, dynamic>> query = _weights(petId).orderBy('measuredOn', descending: true);
          if (limit != null) query = query.limit(limit);
          return query.snapshots().map((snap) => snap.docs.map(WeightEntry.fromFirestore).toList());
        }).first,
      ));

  /// Juste après une création, la fiche n'existe encore que localement : les règles (qui lisent la
  /// fiche côté serveur) refusent alors la lecture des sous-collections. On réessaie quelques fois.
  Stream<T> _retryWhileUnconfirmed<T>(Stream<T> Function() open) {
    late final StreamController<T> controller;
    StreamSubscription<T>? subscription;
    var attempt = 0;

    void listen() {
      subscription = open().listen(
        controller.add,
        onError: (Object error, StackTrace stack) {
          if (error is FirebaseException && error.code == 'permission-denied' && attempt < 6) {
            attempt++;
            subscription?.cancel();
            Future<void>.delayed(Duration(milliseconds: 500 * attempt), () {
              if (!controller.isClosed) listen();
            });
          } else {
            controller.addError(error, stack);
          }
        },
      );
    }

    controller = StreamController<T>(onListen: listen, onCancel: () => subscription?.cancel());
    return controller.stream;
  }

  /// Crée l'animal, ses photos et sa première pesée en une seule écriture atomique.
  Future<String> create({
    required String ownerId,
    required PetDraft draft,
    required List<Uint8List> photos,
    double? weightKg,
  }) =>
      _write(
        () async {
          final json = await _api.post(
            '/api/pets',
            {
              ...draft.toJson(),
              'photos': [for (final bytes in photos.take(maxPetPhotos)) {'data': base64Encode(bytes)}],
              if (weightKg != null) 'weight': _weightJson(_today(), weightKg, null),
            },
            _uploadTimeout,
          );
          return (json as Map<String, dynamic>)['id'] as String;
        },
        () async {
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
        },
      );

  /// Met à jour la fiche et remplace la galerie par [photos] (dans l'ordre, la première en couverture).
  Future<void> update({
    required String petId,
    required PetDraft draft,
    required List<EditablePhoto> photos,
    required List<String> previousPhotoIds,
    double? weightKg,
  }) =>
      _write(
        () => _api.put(
          '/api/pets/$petId',
          {
            ...draft.toJson(),
            'photos': [
              for (final photo in photos.take(maxPetPhotos))
                photo.id == null ? {'data': base64Encode(photo.bytes)} : {'id': photo.id},
            ],
            if (weightKg != null) 'weight': _weightJson(_today(), weightKg, null),
          },
          timeout: _uploadTimeout,
        ),
        () async {
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
        },
      );

  /// Ajoute une photo en fin de galerie depuis la fiche.
  Future<void> addPhoto(String petId, Uint8List bytes, {required int position}) => _write(
        () => _api.post('/api/pets/$petId/photos', {'data': base64Encode(bytes)}, _uploadTimeout),
        () => _photos(petId).add(_photoData(bytes, position)),
      );

  /// Supprime une photo et recompacte l'ordre pour garder la couverture en position 0.
  Future<void> deletePhoto(String petId, List<PetPhoto> gallery, String photoId) => _write(
        () => _api.delete('/api/pets/$petId/photos/$photoId'),
        () async {
          final batch = _firestore.batch()..delete(_photos(petId).doc(photoId));
          var order = 0;
          for (final photo in gallery) {
            if (photo.id == photoId) continue;
            if (photo.sortOrder != order) batch.update(_photos(petId).doc(photo.id), {'sortOrder': order});
            order++;
          }
          await batch.commit();
        },
      );

  /// Place la photo en position 0 (photo principale).
  Future<void> setCover(String petId, List<PetPhoto> gallery, String photoId) => _write(
        () => _api.post('/api/pets/$petId/photos/$photoId/cover'),
        () async {
          final ordered = [
            ...gallery.where((p) => p.id == photoId),
            ...gallery.where((p) => p.id != photoId),
          ];
          final batch = _firestore.batch();
          for (var i = 0; i < ordered.length; i++) {
            batch.update(_photos(petId).doc(ordered[i].id), {'sortOrder': i});
          }
          await batch.commit();
        },
      );

  /// Enregistre une pesée. Lève [DuplicateWeightException] si une mesure existe déjà ce jour-là.
  Future<void> addWeight(String petId, {required DateTime date, required double weightKg, String? note}) {
    final day = DateTime(date.year, date.month, date.day);
    return _write(
      () async {
        try {
          await _api.post('/api/pets/$petId/weights', _weightJson(day, weightKg, note));
        } on ApiException catch (e) {
          if (e.statusCode == 409) throw const DuplicateWeightException();
          rethrow;
        }
      },
      () async {
        final ref = _weights(petId).doc(WeightEntry.idFor(day));
        // L'exception est levée hors de la transaction : sur le web, une erreur levée à l'intérieur la bloque.
        final created = await _firestore.runTransaction((tx) async {
          final existing = await tx.get(ref);
          if (existing.exists) return false;
          tx.set(ref, _weightData(day, weightKg, note));
          return true;
        });
        if (!created) throw const DuplicateWeightException();
      },
    );
  }

  /// Corrige le poids ou la note d'une pesée ; son jour ne change pas.
  Future<void> updateWeight(String petId, String entryId, {required double weightKg, String? note}) => _write(
        () => _api.put('/api/pets/$petId/weights/$entryId', {'weightKg': weightKg, 'note': note}),
        () => _weights(petId).doc(entryId).update({
              'weightKg': weightKg,
              'note': note == null || note.trim().isEmpty ? null : note.trim(),
            }),
      );

  Future<void> deleteWeight(String petId, String entryId) => _write(
        () => _api.delete('/api/pets/$petId/weights/$entryId'),
        () => _weights(petId).doc(entryId).delete(),
      );

  Future<void> setNotes(String petId, String notes) => _write(
        () => _api.patch('/api/pets/$petId', {'notes': notes}),
        () => _pets.doc(petId).update({
              'notes': notes.trim().isEmpty ? null : notes.trim(),
              'updatedAt': FieldValue.serverTimestamp(),
            }),
      );

  Future<void> setFavorite(String petId, bool favorite) => _write(
        () => _api.patch('/api/pets/$petId', {'favorite': favorite}),
        () => _pets.doc(petId).update({
              'favorite': favorite,
              'updatedAt': FieldValue.serverTimestamp(),
            }),
      );

  Future<void> setContacts(String petId, List<PetContact> contacts) => _write(
        () => _api.patch('/api/pets/$petId', {'contacts': contacts.map((c) => c.toMap()).toList()}),
        () => _pets.doc(petId).update({
              'contacts': contacts.map((c) => c.toMap()).toList(),
              'updatedAt': FieldValue.serverTimestamp(),
            }),
      );

  /// Archive l'animal (RG-06) : l'historique est conservé, la fiche quitte la liste des actifs.
  Future<void> archive(String petId) => _write(
        () => _api.post('/api/pets/$petId/archive'),
        () => _pets.doc(petId).update({
              'status': PetStatus.archived.code,
              'archivedReason': 'USER',
              'updatedAt': FieldValue.serverTimestamp(),
            }),
      );

  Future<void> restore(String petId) => _write(
        () => _api.post('/api/pets/$petId/restore'),
        () => _pets.doc(petId).update({
              'status': PetStatus.active.code,
              'archivedReason': null,
              'updatedAt': FieldValue.serverTimestamp(),
            }),
      );

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

  /// [day] est un minuit local : le jour de l'utilisateur reste l'identifiant de la pesée quel que soit son fuseau.
  Map<String, dynamic> _weightJson(DateTime day, double weightKg, String? note) => {
        'date': WeightEntry.idFor(day),
        'measuredOn': day.toUtc().toIso8601String(),
        'weightKg': weightKg,
        'note': note,
      };

  DateTime _today() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  void _setTodayWeight(WriteBatch batch, String petId, double weightKg) {
    final today = _today();
    batch.set(_weights(petId).doc(WeightEntry.idFor(today)), _weightData(today, weightKg, null));
  }
}
