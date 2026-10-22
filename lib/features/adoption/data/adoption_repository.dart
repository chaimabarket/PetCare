import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../auth/data/user_role.dart';
import '../../notifications/data/app_notification.dart';
import '../../notifications/data/notification_service.dart';
import '../../profile/data/user_profile.dart';
import 'adoption_application.dart';
import 'adoption_enums.dart';
import 'adoption_listing.dart';
import 'compatibility.dart';

/// Erreur métier affichable telle quelle à l'utilisateur.
class AdoptionException implements Exception {
  const AdoptionException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Annonces, candidatures et favoris du module Adoption.
///
/// Les règles du cahier des charges sont appliquées ici (transactions) et vérifiées par
/// `firestore.rules` : une seule candidature acceptée à la fois, annonce réservée après
/// acceptation puis adoptée, autres candidatures refusées à l'adoption.
class AdoptionRepository {
  AdoptionRepository({FirebaseFirestore? firestore, NotificationService? notifications})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _notifications = notifications ?? NotificationService(firestore: firestore);

  final FirebaseFirestore _firestore;
  final NotificationService _notifications;

  static const maxPhotos = 5;

  CollectionReference<Map<String, dynamic>> get _listings => _firestore.collection('adoptions');
  CollectionReference<Map<String, dynamic>> get _applications => _firestore.collection('adoptionApplications');
  CollectionReference<Map<String, dynamic>> _photos(String listingId) =>
      _listings.doc(listingId).collection('photos');
  CollectionReference<Map<String, dynamic>> _favorites(String uid) =>
      _firestore.collection('users').doc(uid).collection('adoptionFavorites');

  static int _newestFirst(DateTime? a, DateTime? b) => (b ?? DateTime(0)).compareTo(a ?? DateTime(0));

  // ---------------------------------------------------------------- Annonces

  /// Fil d'adoption : annonces disponibles et réservées. Le tri se fait ici pour éviter un index composite.
  Stream<List<AdoptionListing>> watchPublicListings() => _listings
      .where('status', whereIn: [ListingStatus.available.firestoreValue, ListingStatus.reserved.firestoreValue])
      .snapshots()
      .map((snap) => snap.docs.map(AdoptionListing.fromFirestore).toList()
        ..sort((a, b) => _newestFirst(a.createdAt, b.createdAt)));

  Stream<AdoptionListing?> watchListing(String id) =>
      _listings.doc(id).snapshots().map((doc) => doc.exists ? AdoptionListing.fromFirestore(doc) : null);

  Stream<List<AdoptionListing>> watchMyListings(String uid) => _listings
      .where('publisherId', isEqualTo: uid)
      .snapshots()
      .map((snap) => snap.docs.map(AdoptionListing.fromFirestore).toList()
        ..sort((a, b) => _newestFirst(a.createdAt, b.createdAt)));

  Future<List<Uint8List>> fetchPhotos(String listingId) async {
    final snap = await _photos(listingId).get();
    final docs = snap.docs.toList()..sort((a, b) => int.parse(a.id).compareTo(int.parse(b.id)));
    return [for (final d in docs) base64Decode(d.data()['data'] as String)];
  }

  /// Crée ou modifie une annonce. [publish] = faux enregistre un brouillon.
  Future<String> saveListing({
    String? id,
    required ListingDraft draft,
    required UserProfile publisher,
    required bool publish,
    ListingStatus? currentStatus,
  }) async {
    if (publisher.role == UserRole.provider) {
      throw const AdoptionException('Seuls les propriétaires et les refuges peuvent publier une annonce.');
    }
    final doc = id == null ? _listings.doc() : _listings.doc(id);
    final batch = _firestore.batch();

    // Une annonce réservée ou adoptée garde son statut quand on corrige son texte.
    final keepsStatus = currentStatus == ListingStatus.reserved || currentStatus == ListingStatus.adopted;
    final status = keepsStatus
        ? currentStatus!
        : (publish ? ListingStatus.available : ListingStatus.draft);

    batch.set(
      doc,
      {
        ...draft.toFirestore(),
        'publisherId': publisher.uid,
        'publisherName': publisher.fullName,
        'publisherIsShelter': publisher.role == UserRole.shelter,
        'status': status.firestoreValue,
        'updatedAt': FieldValue.serverTimestamp(),
        if (id == null) 'createdAt': FieldValue.serverTimestamp(),
        if (id == null) 'acceptedApplicationId': null,
      },
      SetOptions(merge: true),
    );

    for (var i = 0; i < maxPhotos; i++) {
      final photo = _photos(doc.id).doc('$i');
      if (i < draft.photos.length) {
        batch.set(photo, {'data': base64Encode(draft.photos[i])});
      } else if (id != null) {
        batch.delete(photo);
      }
    }

    await batch.commit();
    return doc.id;
  }

  /// Archive une annonce (jamais supprimée). Impossible pendant une réservation.
  Future<void> archive(AdoptionListing listing) async {
    if (listing.status == ListingStatus.reserved) {
      throw const AdoptionException(
          "Annulez d'abord l'acceptation en cours : une annonce réservée ne peut pas être archivée.");
    }
    final open = await _openApplications(listing);
    final batch = _firestore.batch();
    batch.update(_listings.doc(listing.id), {
      'status': ListingStatus.archived.firestoreValue,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    for (final app in open) {
      batch.update(_applications.doc(app.id), {
        'status': ApplicationStatus.refused.firestoreValue,
        'refusalReason': "L'annonce de ${listing.name} a été retirée.",
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
    for (final app in open) {
      await _notify(app.applicantId, 'Annonce retirée', "L'annonce de ${listing.name} n'est plus en ligne.");
    }
  }

  // ------------------------------------------------------------ Candidatures

  Future<AdoptionApplication?> findMyApplication(String listingId, String uid) async {
    final doc = await _applications.doc(AdoptionApplication.idFor(listingId, uid)).get();
    return doc.exists ? AdoptionApplication.fromFirestore(doc) : null;
  }

  /// Envoie une candidature. Le score est calculé ici puis stocké avec le dossier.
  Future<AdoptionApplication> apply({
    required AdoptionListing listing,
    required ApplicationAnswers answers,
    required UserProfile applicant,
  }) async {
    if (listing.publisherId == applicant.uid) {
      throw const AdoptionException('Vous ne pouvez pas candidater à votre propre annonce.');
    }
    if (listing.status != ListingStatus.available && listing.status != ListingStatus.reserved) {
      throw AdoptionException("${listing.name} n'est plus proposé(e) à l'adoption.");
    }
    final doc = _applications.doc(AdoptionApplication.idFor(listing.id, applicant.uid));
    final result = computeCompatibility(listing, answers);

    await _firestore.runTransaction((tx) async {
      final existing = await tx.get(doc);
      if (existing.exists) {
        throw const AdoptionException('Vous avez déjà envoyé une candidature pour cet animal.');
      }
      tx.set(doc, {
        'listingId': listing.id,
        'listingName': listing.name,
        'listingSpecies': listing.species.firestoreValue,
        'publisherId': listing.publisherId,
        'publisherName': listing.publisherName,
        'applicantId': applicant.uid,
        'applicantName': applicant.fullName,
        'answers': answers.toMap(),
        'score': result.score,
        'points': [for (final p in result.points) p.toMap()],
        'status': ApplicationStatus.pending.firestoreValue,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });

    await _notify(listing.publisherId, 'Nouvelle candidature',
        '${applicant.fullName} souhaite adopter ${listing.name}.');
    return AdoptionApplication.fromFirestore(await doc.get());
  }

  Stream<List<AdoptionApplication>> watchMyApplications(String uid) => _applications
      .where('applicantId', isEqualTo: uid)
      .snapshots()
      .map((snap) => snap.docs.map(AdoptionApplication.fromFirestore).toList()
        ..sort((a, b) => _newestFirst(a.createdAt, b.createdAt)));

  /// Candidatures reçues par l'annonceur, éventuellement pour une seule annonce.
  Stream<List<AdoptionApplication>> watchReceivedApplications(String publisherId, {String? listingId}) {
    Query<Map<String, dynamic>> query = _applications.where('publisherId', isEqualTo: publisherId);
    if (listingId != null) query = query.where('listingId', isEqualTo: listingId);
    return query.snapshots().map((snap) => snap.docs.map(AdoptionApplication.fromFirestore).toList()
      ..sort((a, b) => b.score.compareTo(a.score)));
  }

  Stream<AdoptionApplication?> watchApplication(String id) => _applications
      .doc(id)
      .snapshots()
      .map((doc) => doc.exists ? AdoptionApplication.fromFirestore(doc) : null);

  /// L'annonceur ouvre un nouveau dossier : il passe « En cours d'étude ».
  Future<void> markReviewing(AdoptionApplication app) async {
    if (app.status != ApplicationStatus.pending) return;
    await _applications.doc(app.id).update({
      'status': ApplicationStatus.reviewing.firestoreValue,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Accepte une candidature : l'annonce devient réservée. La transaction garantit
  /// qu'une seule candidature est acceptée, même si deux acceptations arrivent en même temps.
  Future<void> accept(AdoptionApplication app) async {
    final listingRef = _listings.doc(app.listingId);
    final appRef = _applications.doc(app.id);

    await _firestore.runTransaction((tx) async {
      final listing = AdoptionListing.fromFirestore(await tx.get(listingRef));
      final current = AdoptionApplication.fromFirestore(await tx.get(appRef));
      if (listing.status != ListingStatus.available || listing.acceptedApplicationId != null) {
        throw AdoptionException('Une autre candidature est déjà acceptée pour ${listing.name}.');
      }
      if (current.status != ApplicationStatus.pending && current.status != ApplicationStatus.reviewing) {
        throw const AdoptionException("Cette candidature n'est plus en attente.");
      }
      tx.update(appRef, {
        'status': ApplicationStatus.accepted.firestoreValue,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      tx.update(listingRef, {
        'status': ListingStatus.reserved.firestoreValue,
        'acceptedApplicationId': app.id,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });

    await _notify(app.applicantId, 'Candidature acceptée 🎉',
        '${app.publisherName} a accepté votre demande pour ${app.listingName}.');
  }

  /// Annule une acceptation : le dossier repasse en étude et l'animal redevient disponible.
  Future<void> cancelAcceptance(AdoptionApplication app) async {
    final batch = _firestore.batch();
    batch.update(_applications.doc(app.id), {
      'status': ApplicationStatus.reviewing.firestoreValue,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    batch.update(_listings.doc(app.listingId), {
      'status': ListingStatus.available.firestoreValue,
      'acceptedApplicationId': null,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await batch.commit();
    await _notify(app.applicantId, 'Acceptation annulée',
        '${app.publisherName} a remis votre dossier pour ${app.listingName} en cours d\'étude.');
  }

  /// Refuse une candidature. Si elle était acceptée, l'annonce redevient disponible.
  Future<void> refuse(AdoptionApplication app, {String? reason}) async {
    final batch = _firestore.batch();
    batch.update(_applications.doc(app.id), {
      'status': ApplicationStatus.refused.firestoreValue,
      'refusalReason': (reason == null || reason.trim().isEmpty) ? null : reason.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    if (app.status == ApplicationStatus.accepted) {
      batch.update(_listings.doc(app.listingId), {
        'status': ListingStatus.available.firestoreValue,
        'acceptedApplicationId': null,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
    await _notify(app.applicantId, 'Candidature non retenue',
        'Votre demande pour ${app.listingName} n\'a pas été retenue.');
  }

  /// Le candidat retire sa candidature (définitif). Une acceptation retirée libère l'animal.
  Future<void> withdraw(AdoptionApplication app) async {
    final batch = _firestore.batch();
    batch.update(_applications.doc(app.id), {
      'status': ApplicationStatus.withdrawn.firestoreValue,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    if (app.status == ApplicationStatus.accepted) {
      batch.update(_listings.doc(app.listingId), {
        'status': ListingStatus.available.firestoreValue,
        'acceptedApplicationId': null,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
    await _notify(app.publisherId, 'Candidature retirée',
        '${app.applicantName} a retiré sa candidature pour ${app.listingName}.');
  }

  /// Confirme la remise de l'animal : annonce adoptée, autres candidatures refusées et informées.
  ///
  /// Le carnet de santé n'est pas transmis. Module 1 : copier ici la fiche de l'animal vers
  /// l'adoptant (`adopterId`) quand la collection des animaux existera.
  Future<int> confirmAdoption(AdoptionListing listing, AdoptionApplication app) async {
    if (listing.status != ListingStatus.reserved || listing.acceptedApplicationId != app.id) {
      throw const AdoptionException("Acceptez d'abord cette candidature avant de confirmer l'adoption.");
    }
    final others = (await _openApplications(listing)).where((a) => a.id != app.id).toList();

    final batch = _firestore.batch();
    batch.update(_listings.doc(listing.id), {
      'status': ListingStatus.adopted.firestoreValue,
      'adopterId': app.applicantId,
      'adopterName': app.applicantName,
      'adoptedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    batch.update(_applications.doc(app.id), {
      'status': ApplicationStatus.adopted.firestoreValue,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    for (final other in others) {
      batch.update(_applications.doc(other.id), {
        'status': ApplicationStatus.refused.firestoreValue,
        'refusalReason': '${listing.name} a trouvé une famille.',
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();

    await _notify(app.applicantId, 'Adoption confirmée 🐾',
        '${listing.name} fait maintenant partie de votre famille. Partagez votre Happy Tail !');
    for (final other in others) {
      await _notify(other.applicantId, '${listing.name} a trouvé une famille',
          "Merci pour votre candidature. D'autres compagnons attendent un foyer.");
    }
    return others.length;
  }

  Future<List<AdoptionApplication>> _openApplications(AdoptionListing listing) async {
    final snap = await _applications
        .where('publisherId', isEqualTo: listing.publisherId)
        .where('listingId', isEqualTo: listing.id)
        .get();
    return snap.docs.map(AdoptionApplication.fromFirestore).where((a) => a.status.isOpen).toList();
  }

  // ---------------------------------------------------------------- Favoris

  Stream<Set<String>> watchFavoriteIds(String uid) =>
      _favorites(uid).snapshots().map((snap) => {for (final d in snap.docs) d.id});

  Future<void> setFavorite(String uid, String listingId, bool favorite) => favorite
      ? _favorites(uid).doc(listingId).set({'createdAt': FieldValue.serverTimestamp()})
      : _favorites(uid).doc(listingId).delete();

  Future<List<AdoptionListing>> fetchListings(Iterable<String> ids) async {
    final listings = <AdoptionListing>[];
    for (final id in ids) {
      try {
        final doc = await _listings.doc(id).get();
        if (doc.exists) listings.add(AdoptionListing.fromFirestore(doc));
      } on FirebaseException {
        // Annonce archivée par son auteur : elle n'est plus lisible, on l'ignore.
      }
    }
    return listings;
  }

  // ------------------------------------------------------------ Signalement

  /// Signalement traité par l'administrateur (annonce d'adoption ou Happy Tail).
  Future<void> report({
    required String reporterId,
    required String targetType,
    required String targetId,
    required String reason,
  }) =>
      _firestore.collection('reports').add({
        'reporterId': reporterId,
        'targetType': targetType,
        'targetId': targetId,
        'reason': reason,
        'createdAt': FieldValue.serverTimestamp(),
      });

  Future<void> _notify(String uid, String title, String body) async {
    try {
      await _notifications.send(
        toUserId: uid,
        title: title,
        body: body,
        category: NotificationCategory.adoption,
      );
    } on FirebaseException {
      // La notification est un complément : l'action principale a déjà réussi.
    }
  }
}
