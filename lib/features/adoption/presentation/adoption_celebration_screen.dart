import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../data/adoption_application.dart';
import '../data/adoption_listing.dart';
import 'widgets/adoption_widgets.dart';

/// « Nala a trouvé sa famille ! » : affiché à l'annonceur après la confirmation.
class AdoptionCelebrationScreen extends StatelessWidget {
  const AdoptionCelebrationScreen({
    super.key,
    required this.listing,
    required this.application,
    required this.othersInformed,
  });

  final AdoptionListing listing;
  final AdoptionApplication application;
  final int othersInformed;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final time = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
          children: [
            const Center(
              child: CircleAvatar(
                radius: 44,
                backgroundColor: AdoptionColors.peach,
                child: Icon(Icons.pets, size: 42, color: AdoptionColors.brown),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '${listing.name} a trouvé sa famille ! 🎉',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700, letterSpacing: -0.5),
            ),
            const SizedBox(height: 8),
            Text(
              'L\'adoption a été officialisée avec ${application.applicantName}. '
              'Merci d\'offrir à ${listing.name} un nouveau départ rempli d\'amour.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 15, height: 1.5, color: AdoptionColors.textMuted),
            ),
            const SizedBox(height: 24),
            AdoptionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AspectRatio(
                    aspectRatio: 1.5,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        PetPhoto(
                          bytes: listing.cover,
                          species: listing.species,
                          emojiSize: 72,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        const Positioned(
                          top: 10,
                          right: 10,
                          child: StatusPill(label: 'Adopté 🎉', tone: PillTone.adopted, icon: Icons.verified_outlined),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(listing.name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
                  Text('${listing.breed.isEmpty ? listing.species.label : listing.breed} • ${listing.ageLabel}',
                      style: const TextStyle(color: AppColors.textSecondary)),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: AdoptionColors.blueSurface, borderRadius: BorderRadius.circular(14)),
                    child: Column(
                      children: [
                        _Line(icon: Icons.person_outline, label: 'Adoptant(e)', value: application.applicantName),
                        _Line(icon: Icons.home_work_outlined, label: 'Structure', value: listing.publisherName),
                        _Line(icon: Icons.event_outlined, label: 'Officialisation', value: "Aujourd'hui, $time"),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            TipBanner(
              icon: Icons.diversity_1_outlined,
              title: 'Transition éthique assurée',
              text: othersInformed == 0
                  ? 'Aucune autre candidature n\'était en attente.'
                  : 'Les $othersInformed autre${othersInformed > 1 ? 's' : ''} candidat${othersInformed > 1 ? 's' : ''} '
                      'ont reçu un message bienveillant.',
            ),
            const SizedBox(height: 12),
            const TipBanner(
              tone: TipTone.coral,
              icon: Icons.auto_stories_outlined,
              text: "L'adoptant(e) peut maintenant partager son Happy Tail depuis « Mes candidatures ».",
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Retour aux candidatures'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AdoptionColors.tealDeep),
          const SizedBox(width: 8),
          Text(label),
          const Spacer(),
          Flexible(child: Text(value, textAlign: TextAlign.end, style: const TextStyle(fontWeight: FontWeight.w700))),
        ],
      ),
    );
  }
}
