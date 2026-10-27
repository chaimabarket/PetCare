/// Valeurs fixes du module Adoption, enregistrées dans Firestore par leur [firestoreValue].
library;

/// Retrouve une valeur d'enum par sa valeur Firestore, avec une valeur par défaut.
T _parse<T extends Enum>(List<T> values, String? value, String Function(T) key, T fallback) =>
    values.firstWhere((v) => key(v) == value, orElse: () => fallback);

enum Species {
  cat('chat', 'Chat', '🐱'),
  dog('chien', 'Chien', '🐶'),
  rabbit('lapin', 'Lapin', '🐰'),
  bird('oiseau', 'Oiseau', '🦜'),
  rodent('rongeur', 'Rongeur', '🐹'),
  other('autre', 'Autre', '🐾');

  const Species(this.firestoreValue, this.label, this.emoji);

  final String firestoreValue;
  final String label;
  final String emoji;

  static Species fromFirestore(String? value) => _parse(values, value, (s) => s.firestoreValue, Species.other);
}

enum Sex {
  male('male', 'Mâle', '♂'),
  female('femelle', 'Femelle', '♀');

  const Sex(this.firestoreValue, this.label, this.symbol);

  final String firestoreValue;
  final String label;
  final String symbol;

  static Sex fromFirestore(String? value) => _parse(values, value, (s) => s.firestoreValue, Sex.male);
}

enum PetSize {
  small('petit', 'Petit', '< 10 kg'),
  medium('moyen', 'Moyen', '10 - 25 kg'),
  large('grand', 'Grand', '> 25 kg');

  const PetSize(this.firestoreValue, this.label, this.hint);

  final String firestoreValue;
  final String label;
  final String hint;

  static PetSize fromFirestore(String? value) => _parse(values, value, (s) => s.firestoreValue, PetSize.medium);
}

/// Tranches d'âge du filtre (maquette « Filtres d'adoption »).
enum AgeGroup {
  baby('Bébé', '< 1 an'),
  young('Jeune', '1 - 3 ans'),
  adult('Adulte', '3 - 8 ans'),
  senior('Senior', '8 ans et +');

  const AgeGroup(this.label, this.hint);

  final String label;
  final String hint;

  static AgeGroup ofMonths(int months) {
    if (months < 12) return baby;
    if (months < 36) return young;
    if (months < 96) return adult;
    return senior;
  }
}

enum EnergyLevel {
  low('faible', 'Faible', 'Tranquille & siestes'),
  medium('moyen', 'Moyen', 'Jeux modérés'),
  high('eleve', 'Élevé', 'Grandes sorties');

  const EnergyLevel(this.firestoreValue, this.label, this.hint);

  final String firestoreValue;
  final String label;
  final String hint;

  static EnergyLevel fromFirestore(String? value) =>
      _parse(values, value, (e) => e.firestoreValue, EnergyLevel.medium);
}

/// Badges de personnalité : liste fixe pour pouvoir filtrer.
enum PersonalityBadge {
  calm('calme', 'Calme', '🛋️'),
  energetic('energique', 'Énergique', '⚡'),
  affectionate('affectueux', 'Affectueux', '🤗'),
  playful('joueur', 'Joueur', '🎾'),
  shy('timide', 'Timide', '🙈'),
  goodWithKids('ok_enfants', 'OK enfants', '👶'),
  goodWithCats('ok_chats', 'OK chats', '🐱'),
  goodWithDogs('ok_chiens', 'OK chiens', '🐶'),
  indoor('interieur', 'Intérieur', '🏠'),
  outdoor('exterieur', "Besoin d'extérieur", '🌳'),
  trained('eduque', 'Éduqué', '🎓'),
  specialCare('soins', 'Soins spécifiques', '💊');

  const PersonalityBadge(this.firestoreValue, this.label, this.emoji);

  final String firestoreValue;
  final String label;
  final String emoji;

  static PersonalityBadge? tryParse(String? value) {
    for (final b in values) {
      if (b.firestoreValue == value) return b;
    }
    return null;
  }
}

/// Cycle de vie d'une annonce : brouillon → disponible → réservée → adoptée (ou archivée).
enum ListingStatus {
  draft('brouillon', 'Brouillon'),
  available('disponible', 'Disponible'),
  reserved('reservee', 'Réservé'),
  adopted('adoptee', 'Adopté'),
  archived('archivee', 'Archivé');

  const ListingStatus(this.firestoreValue, this.label);

  final String firestoreValue;
  final String label;

  static ListingStatus fromFirestore(String? value) =>
      _parse(values, value, (s) => s.firestoreValue, ListingStatus.draft);
}

/// Cycle de vie d'une candidature.
enum ApplicationStatus {
  pending('envoyee', 'Nouveau'),
  reviewing('en_etude', "En cours d'étude"),
  accepted('acceptee', 'Acceptée'),
  adopted('adoptee', 'Adoptée'),
  refused('refusee', 'Non retenue'),
  withdrawn('retiree', 'Retirée');

  const ApplicationStatus(this.firestoreValue, this.label);

  final String firestoreValue;
  final String label;

  bool get isOpen => this == pending || this == reviewing || this == accepted;

  static ApplicationStatus fromFirestore(String? value) =>
      _parse(values, value, (s) => s.firestoreValue, ApplicationStatus.pending);
}

enum HousingType {
  apartment('appartement', 'Appartement', 'Balcon ou étage'),
  house('maison', 'Maison', 'Individuelle / Mitoyenne');

  const HousingType(this.firestoreValue, this.label, this.hint);

  final String firestoreValue;
  final String label;
  final String hint;

  static HousingType fromFirestore(String? value) =>
      _parse(values, value, (h) => h.firestoreValue, HousingType.apartment);
}

enum Tenure {
  owner('proprietaire', 'Propriétaire', 'Résidence principale'),
  tenant('locataire', 'Locataire', "Bail d'habitation");

  const Tenure(this.firestoreValue, this.label, this.hint);

  final String firestoreValue;
  final String label;
  final String hint;

  static Tenure fromFirestore(String? value) => _parse(values, value, (t) => t.firestoreValue, Tenure.owner);
}

enum Lifestyle {
  calm('calme', 'Calme & feutré', 'Repos, télétravail, rythme doux'),
  moderate('modere', 'Modéré', 'Sorties quotidiennes, amis réguliers'),
  dynamic('dynamique', 'Très dynamique', 'Passages fréquents, enfants vifs');

  const Lifestyle(this.firestoreValue, this.label, this.hint);

  final String firestoreValue;
  final String label;
  final String hint;

  static Lifestyle fromFirestore(String? value) =>
      _parse(values, value, (l) => l.firestoreValue, Lifestyle.moderate);
}

enum Experience {
  first('premiere_fois', 'Première fois', 'Débutant bienveillant'),
  some('familier', 'Familier', 'Déjà eu un animal'),
  expert('connaisseur', 'Connaisseur', 'Grande expérience');

  const Experience(this.firestoreValue, this.label, this.hint);

  final String firestoreValue;
  final String label;
  final String hint;

  static Experience fromFirestore(String? value) =>
      _parse(values, value, (e) => e.firestoreValue, Experience.some);
}

/// Tranches d'âge des enfants (étape « Votre foyer »).
const kidsAgeRanges = ['0 - 5 ans', '6 - 12 ans', '13+ ans'];
