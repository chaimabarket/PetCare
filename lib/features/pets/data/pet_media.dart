import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';

/// Photo de la galerie privée, stockée compressée dans `pets/{petId}/photos/{photoId}`.
///
/// Le projet Firebase est sur le plan Spark (sans Cloud Storage) : l'image est gardée en octets
/// dans Firestore, une photo par document pour rester sous la limite de 1 Mo.
class PetPhoto {
  const PetPhoto({required this.id, required this.bytes, required this.sortOrder});

  factory PetPhoto.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const {};
    return PetPhoto(
      id: doc.id,
      bytes: (data['data'] as Blob?)?.bytes ?? Uint8List(0),
      sortOrder: data['sortOrder'] as int? ?? 0,
    );
  }

  /// Photo renvoyée par l'API REST : l'image est en base64.
  factory PetPhoto.fromJson(Map<String, dynamic> json) => PetPhoto(
        id: json['id'] as String,
        bytes: base64Decode(json['data'] as String? ?? ''),
        sortOrder: json['sortOrder'] as int? ?? 0,
      );

  final String id;
  final Uint8List bytes;

  /// 0 = photo principale (couverture).
  final int sortOrder;
}

/// Pesée stockée dans `pets/{petId}/weights/{AAAA-MM-JJ}` : une seule mesure par jour.
class WeightEntry {
  const WeightEntry({required this.id, required this.measuredOn, required this.weightKg, this.note});

  factory WeightEntry.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const {};
    return WeightEntry(
      id: doc.id,
      measuredOn: (data['measuredOn'] as Timestamp).toDate(),
      weightKg: (data['weightKg'] as num).toDouble(),
      note: data['note'] as String?,
    );
  }

  /// Pesée renvoyée par l'API REST : la date est un texte ISO.
  factory WeightEntry.fromJson(Map<String, dynamic> json) => WeightEntry(
        id: json['id'] as String,
        measuredOn: DateTime.parse(json['measuredOn'] as String).toLocal(),
        weightKg: (json['weightKg'] as num).toDouble(),
        note: json['note'] as String?,
      );

  final String id;
  final DateTime measuredOn;
  final double weightKg;
  final String? note;

  static String idFor(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}
