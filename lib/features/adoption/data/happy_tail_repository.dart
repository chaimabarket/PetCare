import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../profile/data/user_profile.dart';
import 'adoption_enums.dart';
import 'adoption_listing.dart';
import 'happy_tail.dart';

/// Happy Tails : une histoire par adoption, publiée par l'adoptant ; les autres peuvent aimer.
class HappyTailRepository {
  HappyTailRepository({FirebaseFirestore? firestore}) : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _tails => _firestore.collection('happyTails');
  CollectionReference<Map<String, dynamic>> _likes(String uid) =>
      _firestore.collection('users').doc(uid).collection('likedHappyTails');

  Stream<List<HappyTail>> watchAll() => _tails.snapshots().map((snap) => snap.docs.map(HappyTail.fromFirestore).toList()
    ..sort((a, b) => (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0))));

  Stream<HappyTail?> watch(String listingId) =>
      _tails.doc(listingId).snapshots().map((doc) => doc.exists ? HappyTail.fromFirestore(doc) : null);

  /// Nombre d'adoptions réussies affiché en tête de page.
  Future<int> countAdopted() async {
    final snap = await _firestore
        .collection('adoptions')
        .where('status', isEqualTo: ListingStatus.adopted.firestoreValue)
        .count()
        .get();
    return snap.count ?? 0;
  }

  Stream<Set<String>> watchLikedIds(String uid) =>
      _likes(uid).snapshots().map((snap) => {for (final d in snap.docs) d.id});

  /// Publie ou met à jour l'histoire de l'adoptant (identifiant = annonce adoptée).
  Future<void> save({
    required AdoptionListing listing,
    required UserProfile author,
    required String title,
    required String story,
    required Uint8List after,
    required bool exists,
  }) {
    final data = {
      'listingId': listing.id,
      'authorId': author.uid,
      'authorName': author.fullName,
      'publisherName': listing.publisherName,
      'animalName': listing.name,
      'species': listing.species.firestoreValue,
      'breed': listing.breed,
      'title': title.trim(),
      'story': story.trim(),
      'before': listing.cover == null ? null : base64Encode(listing.cover!),
      'after': base64Encode(after),
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (exists) return _tails.doc(listing.id).update(data);
    return _tails.doc(listing.id).set({...data, 'likeCount': 0, 'createdAt': FieldValue.serverTimestamp()});
  }

  Future<void> setLiked({required String uid, required String tailId, required bool liked}) {
    final batch = _firestore.batch();
    if (liked) {
      batch.set(_likes(uid).doc(tailId), {'createdAt': FieldValue.serverTimestamp()});
    } else {
      batch.delete(_likes(uid).doc(tailId));
    }
    batch.update(_tails.doc(tailId), {'likeCount': FieldValue.increment(liked ? 1 : -1)});
    return batch.commit();
  }
}
