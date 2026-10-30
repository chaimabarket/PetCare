import 'dart:async';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'health_entry.dart';
import 'health_pet.dart';
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

/// Carnet de santé et traitements, sous la fiche animal du module 1 :
///
/// - `pets/{petId}/healthEntries/{id}` : visites, vaccins, examens, allergies, notes ;
/// - `pets/{petId}/healthEntries/{id}/files/{index}` : pièces jointes (octets) ;
/// - `pets/{petId}/treatments/{id}` : traitements et prises notées.
///
/// Comme ces données sont dans des sous-collections, elles ne suivent pas une copie de la fiche
/// vers un adoptant : le carnet de santé n'est pas transmis à l'adoption.
class HealthRepository {
  HealthRepository({FirebaseFirestore? firestore, FirebaseAuth? auth})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  /// Photos déjà chargées, pour ne pas relire la galerie à chaque mise à jour de la fiche.
  static final _photoCache = <String, Uint8List?>{};

  DocumentReference<Map<String, dynamic>> _pet(String petId) => _firestore.collection('pets').doc(petId);
  CollectionReference<Map<String, dynamic>> _entries(String petId) => _pet(petId).collection('healthEntries');
  CollectionReference<Map<String, dynamic>> _treatments(String petId) => _pet(petId).collection('treatments');

  String get _uid {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw const HealthException('Connectez-vous pour accéder au carnet de santé.');
    return uid;
  }

  // ------------------------------------------------------------------ Animal

  /// La fiche de l'animal avec sa première photo.
  Stream<HealthPet?> watchPet(String petId) => _pet(petId).snapshots().asyncMap((doc) async {
        if (!doc.exists) return null;
        return HealthPet.fromFirestore(doc, photo: await _firstPhoto(petId));
      });

  Future<Uint8List?> _firstPhoto(String petId) async {
    if (_photoCache.containsKey(petId)) return _photoCache[petId];
    try {
      final snap = await _pet(petId).collection('photos').orderBy('sortOrder').limit(1).get();
      final data = snap.docs.isEmpty ? null : snap.docs.first.data()['data'];
      return _photoCache[petId] = data is Blob ? data.bytes : null;
    } on FirebaseException {
      return null;
    }
  }

  /// Animaux actifs de l'utilisateur (sans photo), pour l'Accueil.
  Stream<List<HealthPet>> watchMyPets(String uid) => _firestore
      .collection('pets')
      .where('ownerId', isEqualTo: uid)
      .snapshots()
      .map((snap) => [
            for (final doc in snap.docs)
              if (doc.data()['status'] != 'archived') HealthPet.fromFirestore(doc),
          ]..sort((a, b) => a.name.compareTo(b.name)));

  /// Les deux dernières pesées (module 1), pour « + Poids » et l'écart affiché dans le carnet.
  Future<(double?, double?)> latestWeights(String petId) async {
    try {
      final snap = await _pet(petId).collection('weights').orderBy('measuredOn', descending: true).limit(2).get();
      double? at(int i) => i < snap.docs.length ? (snap.docs[i].data()['weightKg'] as num?)?.toDouble() : null;
      return (at(0), at(1));
    } on FirebaseException {
      return (null, null);
    }
  }

  // ------------------------------------------------------------------ Carnet

  /// Les soins du carnet, du plus récent au plus ancien.
  Stream<List<HealthEntry>> watchEntries(String petId) => _entries(petId)
      .orderBy('date', descending: true)
      .snapshots()
      .map((snap) => snap.docs.map(HealthEntry.fromFirestore).toList());

  /// Enregistre un soin et ses pièces jointes en une seule écriture.
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
    if (type == HealthEntryType.vaccine) {
      if ((vaccineName ?? '').trim().isEmpty) throw const HealthException('Indiquez le nom du vaccin.');
      if (nextReminderAt == null) throw const HealthException('Indiquez la date du prochain rappel.');
      if (!nextReminderAt.isAfter(date)) {
        throw const HealthException('Le prochain rappel doit être après la date du vaccin.');
      }
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

    final doc = _entries(petId).doc();
    final batch = _firestore.batch()
      ..set(doc, {
        'ownerId': uid,
        'type': type.firestoreValue,
        'title': title.trim(),
        'date': Timestamp.fromDate(date),
        'description': clean(description),
        'practitioner': clean(practitioner),
        'cost': cost,
        'vaccineName': type == HealthEntryType.vaccine ? clean(vaccineName) : null,
        'batchNumber': type == HealthEntryType.vaccine ? clean(batchNumber) : null,
        'nextReminderAt': type == HealthEntryType.vaccine ? Timestamp.fromDate(nextReminderAt!) : null,
        'reminderDone': false,
        'weightKg': weightKg,
        'weightDeltaKg': weightDeltaKg,
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
  Future<void> markReminderDone(String petId, String entryId) =>
      _entries(petId).doc(entryId).update({'reminderDone': true});

  /// Octets d'une pièce jointe, pour l'afficher ou l'enregistrer sur le téléphone.
  Future<Uint8List> loadAttachment(String petId, String entryId, int index) async {
    final doc = await _entries(petId).doc(entryId).collection('files').doc('$index').get();
    final data = doc.data()?['data'];
    if (data is! Blob) throw const HealthException('Pièce jointe introuvable.');
    return data.bytes;
  }

  // ------------------------------------------------------------------ Traitements

  Stream<List<Treatment>> watchTreatments(String petId) => _treatments(petId)
      .orderBy('startDate', descending: true)
      .snapshots()
      .map((snap) => snap.docs.map(Treatment.fromFirestore).toList());

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

    await _treatments(petId).add({
      'ownerId': uid,
      'category': category.trim().isEmpty ? 'Autre' : category.trim(),
      'name': name.trim(),
      'subtitle': clean(subtitle),
      'form': form.firestoreValue,
      'practitioner': clean(practitioner),
      'posology': posology.trim(),
      'startDate': Timestamp.fromDate(startDate),
      'endDate': Timestamp.fromDate(endDate),
      'doseTimes': ([...doseTimes]..sort()),
      'doses': <Timestamp>[],
      'stoppedAt': null,
      'stopReason': null,
      'renewalAt': renewalAt == null ? null : Timestamp.fromDate(renewalAt),
      'scheduleNote': clean(scheduleNote),
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// « Noter la prise » : ajoute l'heure actuelle aux prises du traitement.
  Future<void> logDose(String petId, String treatmentId) => _treatments(petId).doc(treatmentId).update({
        'doses': FieldValue.arrayUnion([Timestamp.now()]),
      });

  /// Arrêt avant la date de fin prévue, avec la raison donnée par le praticien.
  Future<void> stopTreatment(String petId, String treatmentId, String reason) async {
    if (reason.trim().isEmpty) throw const HealthException("Indiquez la raison de l'arrêt.");
    await _treatments(petId).doc(treatmentId).update({
      'stoppedAt': FieldValue.serverTimestamp(),
      'stopReason': reason.trim(),
    });
  }

  // ------------------------------------------------------------------ Accueil

  /// Rappels vaccinaux et prochaines prises de tous les animaux de l'utilisateur, triés par date.
  Stream<List<HealthUpcomingItem>> watchUpcoming(String uid) {
    late final StreamController<List<HealthUpcomingItem>> controller;
    StreamSubscription<List<HealthPet>>? petsSub;
    final petSubs = <String, List<StreamSubscription<Object?>>>{};
    final entriesByPet = <String, List<HealthEntry>>{};
    final treatmentsByPet = <String, List<Treatment>>{};
    var pets = <HealthPet>[];

    void emit() {
      final now = DateTime.now();
      final items = <HealthUpcomingItem>[
        for (final pet in pets) ...[
          for (final entry in entriesByPet[pet.id] ?? const <HealthEntry>[])
            if (entry.hasPendingReminder)
              HealthUpcomingItem(
                pet: pet,
                title: 'Rappel ${entry.vaccineName ?? entry.title}',
                dueAt: entry.nextReminderAt!,
                isVaccine: true,
              ),
          for (final treatment in treatmentsByPet[pet.id] ?? const <Treatment>[])
            if (treatment.nextDose(now) case final next?)
              HealthUpcomingItem(pet: pet, title: treatment.name, dueAt: next, isVaccine: false),
        ],
      ]..sort((a, b) => a.dueAt.compareTo(b.dueAt));
      if (!controller.isClosed) controller.add(items);
    }

    void listenPets(List<HealthPet> next) {
      pets = next;
      final ids = next.map((p) => p.id).toSet();
      for (final id in petSubs.keys.where((id) => !ids.contains(id)).toList()) {
        for (final sub in petSubs.remove(id)!) {
          sub.cancel();
        }
        entriesByPet.remove(id);
        treatmentsByPet.remove(id);
      }
      for (final id in ids.where((id) => !petSubs.containsKey(id))) {
        petSubs[id] = [
          watchEntries(id).listen((e) {
            entriesByPet[id] = e;
            emit();
          }, onError: (Object _) {}),
          watchTreatments(id).listen((t) {
            treatmentsByPet[id] = t;
            emit();
          }, onError: (Object _) {}),
        ];
      }
      emit();
    }

    controller = StreamController<List<HealthUpcomingItem>>(
      onListen: () => petsSub = watchMyPets(uid).listen(listenPets, onError: controller.addError),
      onCancel: () async {
        await petsSub?.cancel();
        for (final subs in petSubs.values) {
          for (final sub in subs) {
            await sub.cancel();
          }
        }
      },
    );
    return controller.stream;
  }
}
