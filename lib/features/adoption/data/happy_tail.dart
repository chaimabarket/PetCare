import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';

import 'adoption_enums.dart';

/// Histoire d'adoption publiée par l'adoptant, stockée dans `happyTails/{listingId}`.
class HappyTail {
  const HappyTail({
    required this.id,
    required this.listingId,
    required this.authorId,
    required this.authorName,
    required this.publisherName,
    required this.animalName,
    required this.species,
    required this.breed,
    required this.title,
    required this.story,
    required this.likeCount,
    this.before,
    this.after,
    this.createdAt,
  });

  factory HappyTail.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const {};
    final before = data['before'] as String?;
    final after = data['after'] as String?;
    return HappyTail(
      id: doc.id,
      listingId: data['listingId'] as String? ?? doc.id,
      authorId: data['authorId'] as String? ?? '',
      authorName: data['authorName'] as String? ?? '',
      publisherName: data['publisherName'] as String? ?? '',
      animalName: data['animalName'] as String? ?? '',
      species: Species.fromFirestore(data['species'] as String?),
      breed: data['breed'] as String? ?? '',
      title: data['title'] as String? ?? '',
      story: data['story'] as String? ?? '',
      likeCount: (data['likeCount'] as num?)?.toInt() ?? 0,
      before: before == null ? null : base64Decode(before),
      after: after == null ? null : base64Decode(after),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  final String id;
  final String listingId;
  final String authorId;
  final String authorName;
  final String publisherName;
  final String animalName;
  final Species species;
  final String breed;
  final String title;
  final String story;
  final int likeCount;

  /// Photo de l'annonce (« Avant ») et photo dans le nouveau foyer (« Après »).
  final Uint8List? before;
  final Uint8List? after;
  final DateTime? createdAt;
}
