import '../../adoption/data/adoption_enums.dart';
import '../../adoption/data/adoption_listing.dart';

/// Nombre maximal d'annonces envoyées au modèle.
const kListingContextMax = 30;

/// Bloc « ANNONCES » joint aux questions d'adoption : une ligne courte par animal disponible,
/// sans aucune donnée personnelle de l'annonceur.
String buildListingContext(Iterable<AdoptionListing> listings) {
  final available = listings.where((l) => l.status == ListingStatus.available).take(kListingContextMax).toList();
  if (available.isEmpty) return 'ANNONCES (animaux disponibles) : aucune pour le moment.';

  String yesNo(bool v) => v ? 'oui' : 'non';
  final lines = [
    for (final l in available)
      [
        '- id=${l.id}',
        _clean(l.name),
        l.species.label.toLowerCase(),
        if (l.breed.trim().isNotEmpty) _clean(l.breed),
        l.sex.label.toLowerCase(),
        l.ageLabel,
        'taille ${l.size.label.toLowerCase()}',
        _clean(l.city),
        'énergie ${l.energy.label.toLowerCase()}',
        'seul ${l.okAloneHours} h max',
        if (l.badges.isNotEmpty) 'badges: ${l.badges.map((b) => b.label.toLowerCase()).join(', ')}',
        'ok enfants: ${yesNo(l.goodWithKids)}, ok chiens: ${yesNo(l.goodWithDogs)}, ok chats: ${yesNo(l.goodWithCats)}',
        'jardin nécessaire: ${yesNo(l.needsGarden)}',
      ].join(' | '),
  ];
  return 'ANNONCES (animaux disponibles) :\n${lines.join('\n')}';
}

/// Retire les retours à la ligne et les séparateurs pour garder une ligne par annonce.
String _clean(String value) => value.replaceAll(RegExp(r'[\s|]+'), ' ').trim();
