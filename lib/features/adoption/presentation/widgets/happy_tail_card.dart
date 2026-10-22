import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../profile/presentation/widgets/user_avatar.dart';
import '../../data/adoption_enums.dart';
import 'adoption_widgets.dart';

/// Carte d'histoire « Au refuge / Dans son foyer » (maquette « Happy Tails »),
/// utilisée dans le fil et dans l'aperçu du formulaire de partage.
class HappyTailCard extends StatefulWidget {
  const HappyTailCard({
    super.key,
    required this.authorName,
    required this.animalName,
    required this.species,
    required this.publisherName,
    required this.title,
    required this.story,
    required this.likeCount,
    required this.liked,
    this.breed = '',
    this.before,
    this.after,
    this.onLike,
    this.onReport,
  });

  final String authorName;
  final String animalName;
  final Species species;
  final String breed;
  final String publisherName;
  final String title;
  final String story;
  final int likeCount;
  final bool liked;
  final Uint8List? before;
  final Uint8List? after;
  final VoidCallback? onLike;
  final VoidCallback? onReport;

  @override
  State<HappyTailCard> createState() => _HappyTailCardState();
}

class _HappyTailCardState extends State<HappyTailCard> {
  var _expanded = false;

  String get _initials {
    final parts = widget.authorName.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    return (parts.first[0] + (parts.length > 1 ? parts.last[0] : '')).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final w = widget;
    final firstName = w.authorName.trim().split(' ').first;
    final story = w.story.isEmpty ? 'Votre récit apparaîtra ici…' : '« ${w.story} »';

    return AdoptionCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 4, 10),
            child: Row(
              children: [
                UserAvatar(initials: _initials, radius: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text.rich(
                        TextSpan(children: [
                          TextSpan(
                            text: w.animalName,
                            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                          ),
                          TextSpan(
                            text: ' · ${w.breed.isEmpty ? w.species.label : w.breed}',
                            style: const TextStyle(fontSize: 12, color: AdoptionColors.textMuted),
                          ),
                        ]),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'Adopté(e) par ${firstName.isEmpty ? '…' : firstName} · ${w.publisherName}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                if (w.onReport != null)
                  IconButton(
                    tooltip: 'Signaler',
                    onPressed: w.onReport,
                    icon: const Icon(Icons.outlined_flag, size: 20, color: AdoptionColors.textMuted),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: AspectRatio(
              aspectRatio: 1.6,
              child: Row(
                children: [
                  Expanded(child: _Half(bytes: w.before, species: w.species, label: 'Au refuge', warm: false)),
                  const SizedBox(width: 6),
                  Expanded(child: _Half(bytes: w.after, species: w.species, label: 'Dans son foyer ❤️', warm: true)),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (w.title.isNotEmpty) ...[
                  Text(w.title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, height: 1.3)),
                  const SizedBox(height: 4),
                ],
                Text(
                  story,
                  maxLines: _expanded ? null : 4,
                  overflow: _expanded ? TextOverflow.visible : TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 14, height: 1.5),
                ),
                if (w.story.length > 160)
                  TextButton(
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(0, 30),
                      foregroundColor: AdoptionColors.tealDeep,
                      textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    onPressed: () => setState(() => _expanded = !_expanded),
                    child: Text(_expanded ? 'Réduire' : 'Lire plus'),
                  ),
              ],
            ),
          ),
          const Divider(height: 20, color: AppColors.divider),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 0, 14, 12),
            child: Row(
              children: [
                Material(
                  color: AdoptionColors.blueSurface,
                  borderRadius: BorderRadius.circular(999),
                  child: InkWell(
                    onTap: w.onLike,
                    borderRadius: BorderRadius.circular(999),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      child: Row(
                        children: [
                          Icon(w.liked ? Icons.favorite : Icons.favorite_border, size: 18, color: AppColors.coralText),
                          const SizedBox(width: 6),
                          Text('${w.likeCount} coup${w.likeCount > 1 ? 's' : ''} de cœur',
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                        ],
                      ),
                    ),
                  ),
                ),
                const Spacer(),
                const Icon(Icons.verified_outlined, size: 15, color: AppColors.textSecondary),
                const SizedBox(width: 4),
                const Text('Adoption vérifiée', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Half extends StatelessWidget {
  const _Half({required this.bytes, required this.species, required this.label, required this.warm});

  final Uint8List? bytes;
  final Species species;
  final String label;
  final bool warm;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        PetPhoto(bytes: bytes, species: species, emojiSize: 40, borderRadius: BorderRadius.circular(12)),
        Positioned(
          left: 6,
          top: 6,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: warm ? AdoptionColors.peach : Colors.black54,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              label,
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: warm ? AdoptionColors.brown : Colors.white),
            ),
          ),
        ),
      ],
    );
  }
}
