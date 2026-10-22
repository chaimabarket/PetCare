import 'adoption_enums.dart';
import 'adoption_listing.dart';

/// Filtres du fil d'adoption (recherche + feuille « Filtres d'adoption »).
///
/// Le filtrage se fait sur l'appareil : le fil ne contient que les annonces en ligne.
class AdoptionFilters {
  const AdoptionFilters({
    this.query = '',
    this.species = const {},
    this.ages = const {},
    this.sex,
    this.sizes = const {},
    this.city,
    this.badges = const {},
    this.urgentOnly = false,
  });

  final String query;
  final Set<Species> species;
  final Set<AgeGroup> ages;
  final Sex? sex;
  final Set<PetSize> sizes;
  final String? city;
  final Set<PersonalityBadge> badges;
  final bool urgentOnly;

  /// Nombre de filtres actifs (pastille du bouton « Filtres »), hors recherche et espèces.
  int get activeCount =>
      ages.length + (sex == null ? 0 : 1) + sizes.length + (city == null ? 0 : 1) + badges.length + (urgentOnly ? 1 : 0);

  bool matches(AdoptionListing l) {
    if (species.isNotEmpty && !species.contains(l.species)) return false;
    if (ages.isNotEmpty && !ages.contains(l.ageGroup)) return false;
    if (sex != null && l.sex != sex) return false;
    if (sizes.isNotEmpty && !sizes.contains(l.size)) return false;
    if (city != null && l.city.toLowerCase() != city!.toLowerCase()) return false;
    // Un animal doit avoir tous les badges demandés.
    if (!badges.every(l.badges.contains)) return false;
    if (urgentOnly && !l.isUrgent) return false;

    final q = _normalize(query.trim());
    if (q.isEmpty) return true;
    return [l.name, l.breed, l.city, l.species.label, l.publisherName].any((field) => _normalize(field).contains(q));
  }

  List<AdoptionListing> apply(Iterable<AdoptionListing> listings) => listings.where(matches).toList();

  AdoptionFilters copyWith({
    String? query,
    Set<Species>? species,
    Set<AgeGroup>? ages,
    Sex? Function()? sex,
    Set<PetSize>? sizes,
    String? Function()? city,
    Set<PersonalityBadge>? badges,
    bool? urgentOnly,
  }) =>
      AdoptionFilters(
        query: query ?? this.query,
        species: species ?? this.species,
        ages: ages ?? this.ages,
        sex: sex == null ? this.sex : sex(),
        sizes: sizes ?? this.sizes,
        city: city == null ? this.city : city(),
        badges: badges ?? this.badges,
        urgentOnly: urgentOnly ?? this.urgentOnly,
      );

  /// Garde la recherche et les espèces, efface le reste (« Réinitialiser »).
  AdoptionFilters cleared() => AdoptionFilters(query: query, species: species);

  static String _normalize(String s) {
    const accents = {'à': 'a', 'â': 'a', 'ä': 'a', 'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e', 'î': 'i', 'ï': 'i',
      'ô': 'o', 'ö': 'o', 'ù': 'u', 'û': 'u', 'ü': 'u', 'ç': 'c'};
    final lower = s.toLowerCase();
    final buffer = StringBuffer();
    for (final ch in lower.split('')) {
      buffer.write(accents[ch] ?? ch);
    }
    return buffer.toString();
  }
}
