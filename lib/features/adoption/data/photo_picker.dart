import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';

/// Photos réduites et compressées avant l'envoi.
///
/// Les photos sont enregistrées dans Firestore (pas de Firebase Storage sur le plan gratuit) :
/// chaque photo doit rester petite, d'où la taille maximale et la compression JPEG.
class PhotoPicker {
  PhotoPicker({ImagePicker? picker}) : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  static const maxWidth = 900.0;
  static const quality = 60;

  /// Taille maximale d'une photo après compression (un document Firestore est limité à 1 Mo).
  static const maxBytes = 350 * 1024;

  /// Renvoie les photos choisies (au plus [limit]) ; lève [PhotoTooLargeException] si une photo
  /// reste trop lourde.
  Future<List<Uint8List>> pickMany({required int limit}) async {
    if (limit <= 0) return const [];
    final files = await _picker.pickMultiImage(
      maxWidth: maxWidth,
      imageQuality: quality,
      limit: limit > 1 ? limit : null,
    );
    final photos = <Uint8List>[];
    for (final file in files.take(limit)) {
      photos.add(await _read(file));
    }
    return photos;
  }

  Future<Uint8List?> pickOne() async {
    final file = await _picker.pickImage(source: ImageSource.gallery, maxWidth: maxWidth, imageQuality: quality);
    return file == null ? null : _read(file);
  }

  Future<Uint8List> _read(XFile file) async {
    final bytes = await file.readAsBytes();
    if (bytes.length > maxBytes) throw const PhotoTooLargeException();
    return bytes;
  }
}

class PhotoTooLargeException implements Exception {
  const PhotoTooLargeException();

  String get message => 'Cette photo est trop lourde. Choisissez une image plus petite (JPG ou PNG).';
}
