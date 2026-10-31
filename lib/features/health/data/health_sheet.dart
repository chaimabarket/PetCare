import 'package:cloud_firestore/cloud_firestore.dart';

/// Catégorie d'une fiche (puces de l'écran « Fiches Santé & Conseils »).
enum HealthSheetCategory {
  parasites('parasites', 'Parasites'),
  nutrition('alimentation', 'Alimentation'),
  vaccines('vaccins', 'Vaccins'),
  behavior('comportement', 'Comportement'),
  products('produits', 'Produits'),
  emergency('urgences', 'Urgences');

  const HealthSheetCategory(this.firestoreValue, this.label);

  final String firestoreValue;
  final String label;

  static HealthSheetCategory fromFirestore(String? value) =>
      values.firstWhere((c) => c.firestoreValue == value, orElse: () => HealthSheetCategory.products);
}

/// Un intertitre et son paragraphe dans le corps de la fiche.
class HealthSheetSection {
  const HealthSheetSection({required this.heading, required this.body});

  factory HealthSheetSection.fromMap(Map<String, dynamic> map) =>
      HealthSheetSection(heading: map['heading'] as String? ?? '', body: map['body'] as String? ?? '');

  final String heading;
  final String body;
}

/// Fiche santé publique (information générale, ne remplace pas un vétérinaire).
///
/// Stockée dans `healthSheets/{id}` (écriture réservée à l'administrateur). Les fiches de
/// départ de [starterHealthSheets] s'affichent tant que la collection ne les remplace pas.
class HealthSheet {
  const HealthSheet({
    required this.id,
    required this.title,
    required this.summary,
    required this.category,
    required this.species,
    required this.author,
    required this.organization,
    required this.readMinutes,
    required this.sections,
    required this.source,
    this.imageAsset,
    this.imageUrl,
    this.featured = false,
  });

  factory HealthSheet.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const {};
    return HealthSheet(
      id: doc.id,
      title: data['title'] as String? ?? '',
      summary: data['summary'] as String? ?? '',
      category: HealthSheetCategory.fromFirestore(data['category'] as String?),
      species: [for (final s in (data['species'] as List?) ?? const []) if (s is String) s],
      author: data['author'] as String? ?? '',
      organization: data['organization'] as String? ?? '',
      readMinutes: (data['readMinutes'] as num?)?.toInt() ?? 3,
      sections: [
        for (final s in (data['sections'] as List?) ?? const [])
          if (s is Map) HealthSheetSection.fromMap(Map<String, dynamic>.from(s)),
      ],
      source: data['source'] as String? ?? '',
      imageUrl: data['imageUrl'] as String?,
      featured: data['featured'] as bool? ?? false,
    );
  }

  final String id;
  final String title;
  final String summary;
  final HealthSheetCategory category;

  /// Étiquettes d'espèce : « Chien », « Chat », « Chiot »…
  final List<String> species;
  final String author;
  final String organization;
  final int readMinutes;
  final List<HealthSheetSection> sections;

  /// Ligne « Source : » en bas de la fiche.
  final String source;
  final String? imageAsset;
  final String? imageUrl;

  /// Mise en avant dans « À la une ».
  final bool featured;

  /// Texte utilisé par la recherche : titre, résumé, espèces, catégorie et corps.
  String get searchText => [
        title,
        summary,
        category.label,
        ...species,
        for (final s in sections) ...[s.heading, s.body],
      ].join(' ').toLowerCase();
}
