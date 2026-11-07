import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/polling.dart';
import 'health_entry.dart';
import 'health_pet.dart';
import 'health_summary.dart';
import 'treatment.dart';

/// Erreur métier affichée telle quelle à l'utilisateur.
class HealthException implements Exception {
  const HealthException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Fichier choisi dans le formulaire, pas encore envoyé.
class PendingAttachment {
  const PendingAttachment({required this.name, required this.mimeType, required this.bytes});

  final String name;
  final String mimeType;
  final Uint8List bytes;
}

/// Une échéance à venir pour l'Accueil : rappel vaccinal ou prochaine prise d'un traitement.
class HealthUpcomingItem {
  const HealthUpcomingItem({
    required this.pet,
    required this.title,
    required this.dueAt,
    required this.isVaccine,
  });

  final HealthPet pet;
  final String title;
  final DateTime dueAt;
  final bool isVaccine;
}

/// Taille maximale d'une pièce jointe : un document Firestore est limité à 1 Mio.
const maxAttachmentBytes = 900 * 1024;

/// Nombre maximal de pièces jointes par soin.
const maxAttachments = 3;

/// Carnet de santé et traitements, sous la fiche animal du module 1, par l'API REST PetCare :
///
/// - `pets/{petId}/healthEntries/{id}` : visites, vaccins, examens, allergies, notes ;
/// - `pets/{petId}/healthEntries/{id}/files/{index}` : pièces jointes (octets) ;
/// - `pets/{petId}/treatments/{id}` : traitements et prises notées.
///
/// Si le serveur est éteint ou injoignable, tout passe directement par Firestore : les règles de
/// sécurité sont les mêmes, l'application reste utilisable.
///
/// Comme ces données sont dans des sous-collections, elles ne suivent pas une copie de la fiche
/// vers un adoptant : le carnet de santé n'est pas transmis à l'adoption.
class HealthRepository {
  HealthRepository({FirebaseFirestore? firestore, FirebaseAuth? auth, ApiClient? api})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance,
        _api = api ?? ApiClient();

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final ApiClient _api;

  /// Le quota Firestore gratuit est limité : 60 s entre deux lectures, plus une mise à jour
  /// immédiate après chaque modification ([notifyApiDataChanged]).
  static const _refresh = Duration(seconds: 60);

  /// Photos déjà chargées, pour ne pas relire la galerie à chaque mise à jour de la fiche.
  static final _photoCache = <String, Uint8List?>{};

  DocumentReference<Map<String, dynamic>> _pet(String petId) => _firestore.collection('pets').doc(petId);
  CollectionReference<Map<String, dynamic>> _entries(String petId) => _pet(petId).collection('healthEntries');
  CollectionReference<Map<String, dynamic>> _treatments(String petId) => _pet(petId).collection('treatments');

  String _health(String petId) => '/api/pets/$petId/health';

  String get _uid {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw const HealthException('Connectez-vous pour accéder au carnet de santé.');
    return uid;
  }

  static String _iso(DateTime d) => d.toUtc().toIso8601String();

  /// Lit par l'API ; si le serveur est éteint, [viaFirestore] prend le relais.
  /// Un refus du serveur devient une erreur affichable.
  Future<T> _read<T>(Future<T> Function() viaApi, Future<T> Function() viaFirestore) async {
    try {
      return await viaApi();
    } on ApiException catch (e) {
      if (e.isUnreachable) return viaFirestore();
      throw HealthException(e.message);
    }
  }

  /// Écrit par l'API, ou par Firestore si le serveur est éteint, puis rafraîchit les écrans.
  Future<void> _write(Future<void> Function() viaApi, Future<void> Function() viaFirestore) async {
    try {
      await _read(viaApi, viaFirestore);
    } on FirebaseException catch (e) {
      throw HealthException(e.message ?? e.code);
    }
    notifyApiDataChanged();
  }

  // ------------------------------------------------------------------ Animal

  /// La fiche de l'animal (module 1) avec sa première photo.
  Stream<HealthPet?> watchPet(String petId) => poll(
        () => _read<HealthPet?>(
          () async {
            final Map<String, dynamic> json;
            try {
              json = await _api.get('/api/pets/$petId') as Map<String, dynamic>;
            } on ApiException catch (e) {
              if (e.statusCode == 404) return null;
              rethrow;
            }
            return HealthPet.fromJson(json, photo: await _firstPhoto(petId));
          },
          () async {
            final doc = await _pet(petId).get();
            return doc.exists ? HealthPet.fromFirestore(doc, photo: await _firstPhoto(petId)) : null;
          },
        ),
        every: _refresh,
      );

  Future<Uint8List?> _firstPhoto(String petId) async {
    if (_photoCache.containsKey(petId)) return _photoCache[petId];
    try {
      return _photoCache[petId] = await _read<Uint8List?>(
        () async {
          final json = await _api.get('/api/pets/$petId/cover');
          return json == null ? null : base64Decode((json as Map<String, dynamic>)['data'] as String);
        },
        () async {
          final snap = await _pet(petId).collection('photos').orderBy('sortOrder').limit(1).get();
          final data = snap.docs.isEmpty ? null : snap.docs.first.data()['data'];
          return data is Blob ? data.bytes : null;
        },
      );
    } on Exception {
      // La photo n'est qu'un ornement : sans elle, l'initiale s'affiche.
      return null;
    }
  }

  /// Les deux dernières pesées (module 1), pour « + Poids » et l'écart affiché dans le carnet.
  Future<(double?, double?)> latestWeights(String petId) async {
    try {
      final weights = await _read<List<double?>>(
        () async => [
          for (final item in await _api.get('/api/pets/$petId/weights?limit=2') as List<dynamic>)
            ((item as Map<String, dynamic>)['weightKg'] as num?)?.toDouble(),
        ],
        () async {
          final snap = await _pet(petId).collection('weights').orderBy('measuredOn', descending: true).limit(2).get();
          return [for (final doc in snap.docs) (doc.data()['weightKg'] as num?)?.toDouble()];
        },
      );
      return (weights.elementAtOrNull(0), weights.elementAtOrNull(1));
    } on Exception {
      return (null, null);
    }
  }

  // ------------------------------------------------------------------ Synthèse (onglet Santé)

  /// Résumé de tous les animaux de l'utilisateur en un appel (`GET /api/health/summary`).
  /// Serveur éteint : le même résumé est construit à partir de Firestore.
  Stream<HealthSummary> watchSummary(String uid) => poll(
        () => _read(
          () async => HealthSummary.fromJson(await _api.get('/api/health/summary') as Map<String, dynamic>),
          () => _summaryFirestore(uid),
        ),
        every: _refresh,
      );

  Future<HealthSummary> _summaryFirestore(String uid) async {
    final pets = await _firestore.collection('pets').where('ownerId', isEqualTo: uid).get();
    final summaries = await Future.wait(pets.docs.map((pet) async {
      final results = await Future.wait([_entries(pet.id).get(), _treatments(pet.id).get()]);
      return PetHealthSummary.fromRecords(
        id: pet.id,
        pet: pet.data(),
        entries: results[0].docs.map(HealthEntry.fromFirestore).toList(),
        treatments: results[1].docs.map(Treatment.fromFirestore).toList(),
      );
    }));
    return HealthSummary(pets: summaries..sort((a, b) => a.name.compareTo(b.name)));
  }

  static HealthPet _petOf(PetHealthSummary p) =>
      HealthPet(id: p.id, name: p.name, species: p.species, breed: p.breed, archived: p.archived);

  /// Animaux actifs de l'utilisateur (sans photo), pour l'Accueil. Lu dans la synthèse.
  Stream<List<HealthPet>> watchMyPets(String uid) => watchSummary(uid).map(
        (s) => [for (final p in s.pets) if (!p.archived) _petOf(p)],
      );

  /// Rappels vaccinaux et prochaines prises de tous les animaux actifs, triés par date. Lu dans la synthèse.
  Stream<List<HealthUpcomingItem>> watchUpcoming(String uid) => watchSummary(uid).map((summary) {
        final now = DateTime.now();
        return <HealthUpcomingItem>[
          for (final p in summary.pets)
            if (!p.archived) ...[
              for (final v in p.pendingVaccines)
                HealthUpcomingItem(pet: _petOf(p), title: 'Rappel ${v.title}', dueAt: v.dueAt, isVaccine: true),
              for (final t in p.activeTreatments)
                if (t.nextDose(now) case final next?)
                  HealthUpcomingItem(pet: _petOf(p), title: t.name, dueAt: next, isVaccine: false),
            ],
        ]..sort((a, b) => a.dueAt.compareTo(b.dueAt));
      });

  // ------------------------------------------------------------------ Carnet

  /// Les soins du carnet, du plus récent au plus ancien.
  Stream<List<HealthEntry>> watchEntries(String petId) => poll(
        () => _read(
          () async => [
            for (final item in await _api.get('${_health(petId)}/entries') as List<dynamic>)
              HealthEntry.fromJson(item as Map<String, dynamic>),
          ],
          () async => (await _entries(petId).orderBy('date', descending: true).get())
              .docs
              .map(HealthEntry.fromFirestore)
              .toList(),
        ),
        every: _refresh,
      );

  /// Enregistre un soin et ses pièces jointes en une seule écriture.
  ///
  /// [nextReminderAt] : rappel d'un vaccin (obligatoire) ou prochain contrôle d'une visite (facultatif).
  Future<void> addEntry({
    required String petId,
    required HealthEntryType type,
    required String title,
    required DateTime date,
    String? description,
    String? practitioner,
    double? cost,
    String? vaccineName,
    String? batchNumber,
    DateTime? nextReminderAt,
    double? weightKg,
    double? weightDeltaKg,
    List<PendingAttachment> attachments = const [],
  }) async {
    final uid = _uid;
    if (title.trim().isEmpty) throw const HealthException('Le titre du soin est obligatoire.');
    if (date.isAfter(DateTime.now())) throw const HealthException('La date du soin ne peut pas être dans le futur.');
    final isVaccine = type == HealthEntryType.vaccine;
    // Seuls un vaccin (rappel) et une visite (prochain contrôle) gardent une date à venir.
    final reminder = isVaccine || type == HealthEntryType.visit ? nextReminderAt : null;
    if (isVaccine) {
      if ((vaccineName ?? '').trim().isEmpty) throw const HealthException('Indiquez le nom du vaccin.');
      if (reminder == null) throw const HealthException('Indiquez la date du prochain rappel.');
    }
    if (reminder != null && !reminder.isAfter(date)) {
      throw HealthException(isVaccine
          ? 'Le prochain rappel doit être après la date du vaccin.'
          : 'Le prochain contrôle doit être après la date de la visite.');
    }
    if (attachments.length > maxAttachments) {
      throw const HealthException('$maxAttachments pièces jointes au maximum.');
    }
    for (final file in attachments) {
      if (file.bytes.length > maxAttachmentBytes) {
        throw HealthException('« ${file.name} » dépasse 900 Ko. Choisissez un fichier plus léger.');
      }
    }

    String? clean(String? value) => (value ?? '').trim().isEmpty ? null : value!.trim();
    final fields = <String, dynamic>{
      'type': type.firestoreValue,
      'title': title.trim(),
      'description': clean(description),
      'practitioner': clean(practitioner),
      'cost': cost,
      'vaccineName': isVaccine ? clean(vaccineName) : null,
      'batchNumber': isVaccine ? clean(batchNumber) : null,
      'weightKg': weightKg,
      'weightDeltaKg': weightDeltaKg,
    };

    await _write(
      () => _api.post('${_health(petId)}/entries', {
        ...fields,
        'date': _iso(date),
        'nextReminderAt': reminder == null ? null : _iso(reminder),
        'attachments': [
          for (final file in attachments)
            {'name': file.name, 'mimeType': file.mimeType, 'data': base64Encode(file.bytes)},
        ],
      }),
      () => _addEntryFirestore(uid, petId, {
        ...fields,
        'date': Timestamp.fromDate(date),
        'nextReminderAt': reminder == null ? null : Timestamp.fromDate(reminder),
      }, attachments),
    );
  }

  /// Même écriture que `POST /entries`, directement dans Firestore (serveur éteint).
  Future<void> _addEntryFirestore(
    String uid,
    String petId,
    Map<String, dynamic> fields,
    List<PendingAttachment> attachments,
  ) async {
    final doc = _entries(petId).doc();
    final batch = _firestore.batch()
      ..set(doc, {
        ...fields,
        'ownerId': uid,
        'reminderDone': false,
        'attachments': [
          for (final file in attachments)
            HealthAttachment(name: file.name, mimeType: file.mimeType, size: file.bytes.length).toMap(),
        ],
        'createdAt': FieldValue.serverTimestamp(),
      });
    for (var i = 0; i < attachments.length; i++) {
      batch.set(doc.collection('files').doc('$i'), {
        'name': attachments[i].name,
        'mimeType': attachments[i].mimeType,
        'data': Blob(attachments[i].bytes),
      });
    }
    await batch.commit();
  }

  /// Bouton ✓✓ de la carte « Prochain rappel vaccinal » : le rappel est déjà fait.
  Future<void> markReminderDone(String petId, String entryId) => _write(
        () => _api.patch('${_health(petId)}/entries/$entryId/reminder-done'),
        () => _entries(petId).doc(entryId).update({'reminderDone': true}),
      );

  /// Octets d'une pièce jointe, pour l'afficher ou l'enregistrer sur le téléphone.
  Future<Uint8List> loadAttachment(String petId, String entryId, int index) => _read(
        () async {
          final json = await _api.get('${_health(petId)}/entries/$entryId/files/$index') as Map<String, dynamic>;
          return base64Decode(json['data'] as String);
        },
        () async {
          final doc = await _entries(petId).doc(entryId).collection('files').doc('$index').get();
          final data = doc.data()?['data'];
          if (data is! Blob) throw const HealthException('Pièce jointe introuvable.');
          return data.bytes;
        },
      );

  // ------------------------------------------------------------------ Traitements

  Stream<List<Treatment>> watchTreatments(String petId) => poll(
        () => _read(
          () async => [
            for (final item in await _api.get('${_health(petId)}/treatments') as List<dynamic>)
              Treatment.fromJson(item as Map<String, dynamic>),
          ],
          () async => (await _treatments(petId).orderBy('startDate', descending: true).get())
              .docs
              .map(Treatment.fromFirestore)
              .toList(),
        ),
        every: _refresh,
      );

  Future<void> addTreatment({
    required String petId,
    required String category,
    required String name,
    required String posology,
    required DateTime startDate,
    required DateTime endDate,
    String? subtitle,
    TreatmentForm form = TreatmentForm.other,
    String? practitioner,
    List<String> doseTimes = const [],
    DateTime? renewalAt,
    String? scheduleNote,
  }) async {
    final uid = _uid;
    if (name.trim().isEmpty) throw const HealthException('Le nom du médicament est obligatoire.');
    if (posology.trim().isEmpty) throw const HealthException('Recopiez la posologie prescrite.');
    if (endDate.isBefore(startDate)) throw const HealthException('La date de fin doit être après la date de début.');
    if (renewalAt != null && !renewalAt.isAfter(endDate)) {
      throw const HealthException('Le renouvellement doit être après la fin du traitement.');
    }

    String? clean(String? value) => (value ?? '').trim().isEmpty ? null : value!.trim();
    final fields = <String, dynamic>{
      'category': category.trim().isEmpty ? 'Autre' : category.trim(),
      'name': name.trim(),
      'subtitle': clean(subtitle),
      'form': form.firestoreValue,
      'practitioner': clean(practitioner),
      'posology': posology.trim(),
      'doseTimes': ([...doseTimes]..sort()),
      'scheduleNote': clean(scheduleNote),
    };

    await _write(
      () => _api.post('${_health(petId)}/treatments', {
        ...fields,
        'startDate': _iso(startDate),
        'endDate': _iso(endDate),
        'renewalAt': renewalAt == null ? null : _iso(renewalAt),
      }),
      () => _treatments(petId).add({
        ...fields,
        'ownerId': uid,
        'startDate': Timestamp.fromDate(startDate),
        'endDate': Timestamp.fromDate(endDate),
        'doses': <Timestamp>[],
        'stoppedAt': null,
        'stopReason': null,
        'renewalAt': renewalAt == null ? null : Timestamp.fromDate(renewalAt),
        'createdAt': FieldValue.serverTimestamp(),
      }),
    );
  }

  /// « Noter la prise » : maintenant, ou à l'heure [at] du créneau coché dans le tableau du jour.
  /// Une prise notée ne s'annule pas (les règles n'acceptent qu'un ajout).
  Future<void> logDose(String petId, String treatmentId, {DateTime? at}) => _write(
        () => _api.post('${_health(petId)}/treatments/$treatmentId/doses', {if (at != null) 'at': _iso(at)}),
        () => _treatments(petId).doc(treatmentId).update({
          'doses': FieldValue.arrayUnion([at == null ? Timestamp.now() : Timestamp.fromDate(at)]),
        }),
      );

  /// Arrêt avant la date de fin prévue, avec la raison donnée par le praticien.
  Future<void> stopTreatment(String petId, String treatmentId, String reason) async {
    if (reason.trim().isEmpty) throw const HealthException("Indiquez la raison de l'arrêt.");
    await _write(
      () => _api.post('${_health(petId)}/treatments/$treatmentId/stop', {'reason': reason.trim()}),
      () => _treatments(petId).doc(treatmentId).update({
        'stoppedAt': FieldValue.serverTimestamp(),
        'stopReason': reason.trim(),
      }),
    );
  }
}
