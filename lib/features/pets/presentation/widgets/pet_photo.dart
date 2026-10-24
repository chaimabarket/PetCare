import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../l10n/app_localizations.dart';
import '../../data/pet_media.dart';
import '../../data/pet_repository.dart';
import '../pet_style.dart';

/// Taille maximale d'une photo compressée (un document Firestore est limité à 1 Mo).
const _maxPhotoBytes = 700 * 1024;

/// Demande la source (galerie ou appareil photo), puis renvoie l'image compressée.
Future<Uint8List?> pickPetPhoto(BuildContext context) async {
  final l = AppLocalizations.of(context);
  final source = await showModalBottomSheet<ImageSource>(
    context: context,
    backgroundColor: PetColors.surfaceLowest,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.photo_library_outlined, color: PetColors.primary),
            title: Text(l.petsPhotoFromGallery, style: PetText.labelLg),
            onTap: () => Navigator.of(context).pop(ImageSource.gallery),
          ),
          ListTile(
            leading: const Icon(Icons.photo_camera_outlined, color: PetColors.primary),
            title: Text(l.petsPhotoFromCamera, style: PetText.labelLg),
            onTap: () => Navigator.of(context).pop(ImageSource.camera),
          ),
        ],
      ),
    ),
  );
  if (source == null) return null;

  final file = await ImagePicker().pickImage(source: source, maxWidth: 1080, maxHeight: 1080, imageQuality: 70);
  if (file == null) return null;
  final bytes = await file.readAsBytes();
  if (bytes.length > _maxPhotoBytes) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.petsPhotoTooLarge)),
      );
    }
    return null;
  }
  return bytes;
}

/// Image en mémoire, ou silhouette neutre si l'animal n'a pas de photo.
class PetImage extends StatelessWidget {
  const PetImage({super.key, required this.bytes, this.iconSize = 32});

  final Uint8List? bytes;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final data = bytes;
    if (data == null || data.isEmpty) {
      return ColoredBox(
        color: PetColors.surfaceContainer,
        child: Center(child: Icon(Icons.pets, size: iconSize, color: PetColors.primaryFixedDim)),
      );
    }
    return Image.memory(data, fit: BoxFit.cover, gaplessPlayback: true);
  }
}

/// Photo principale de l'animal, chargée en direct depuis sa galerie.
class PetCoverImage extends StatefulWidget {
  const PetCoverImage({super.key, required this.petId, this.iconSize = 32});

  final String petId;
  final double iconSize;

  @override
  State<PetCoverImage> createState() => _PetCoverImageState();
}

class _PetCoverImageState extends State<PetCoverImage> {
  late final Stream<PetPhoto?> _cover = PetRepository().watchCover(widget.petId);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<PetPhoto?>(
      stream: _cover,
      builder: (context, snapshot) => PetImage(bytes: snapshot.data?.bytes, iconSize: widget.iconSize),
    );
  }
}
