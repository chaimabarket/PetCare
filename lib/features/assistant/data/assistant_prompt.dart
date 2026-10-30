/// Texte fixe de l'assistant IA : consignes du modèle, questions recommandées et détection
/// des questions d'adoption.
library;

import 'assistant_pet.dart';

/// Modèle Gemini gratuit (Gemini Developer API, plan Spark).
/// Vérifier le nom dans la console Firebase (AI Logic) : Google renomme parfois ses modèles.
const kAssistantModel = 'gemini-2.5-flash-lite';

/// Messages par utilisateur connecté et par jour (protège le quota gratuit). Même valeur dans firestore.rules.
const kAssistantDailyLimit = 30;

/// Longueur maximale d'une question.
const kAssistantQuestionMax = 500;

/// Nombre de messages précédents envoyés au modèle.
const kAssistantHistoryLength = 10;

/// Nombre maximal d'animaux proposés dans une réponse.
const kAssistantMaxSuggestions = 3;

/// Nombre maximal de rappels proposés dans une réponse.
const kAssistantMaxReminders = 2;

/// Conversations gardées dans l'historique.
const kAssistantHistoryChats = 10;

const kAssistantSystemPrompt = '''
Tu es « Assistant PetCare », l'assistant de l'application PetCare Community (Tunisie).
Règles :
- Réponds toujours en français, avec un ton chaleureux, clair et court (5 phrases ou une liste de 5 points maximum).
- Sujets autorisés : soins des animaux de compagnie, alimentation, comportement, éducation, hygiène,
  adoption, et utilisation de l'application PetCare. Pour tout autre sujet, dis poliment que tu ne peux
  parler que des animaux et de PetCare.
- Tu n'es pas vétérinaire : ne pose jamais de diagnostic et ne donne pas de dosage de médicament.
  Pour un problème de santé, conseille de consulter un vétérinaire.
- Urgence (saignement, poison avalé, difficulté à respirer, convulsions, animal qui ne bouge plus) :
  commence par « ⚠️ Urgence : contactez immédiatement un vétérinaire. »
- ANIMAL SÉLECTIONNÉ : si ce bloc est fourni, adapte ta réponse à cet animal (espèce, âge, poids, notes,
  carnet de santé) et appelle-le par son nom.
- Rappels : seulement si un ANIMAL SÉLECTIONNÉ est fourni et que tu conseilles un soin à faire à une date
  précise ou de façon régulière (vermifuge, antiparasitaire, vaccin, contrôle vétérinaire, toilettage,
  coupe des griffes…), ajoute à la fin au plus 2 tags [[rappel:Intitulé court|AAAA-MM-JJ]] avec la
  prochaine date conseillée, calculée à partir de la DATE DU JOUR. L'intitulé contient le nom de l'animal
  (ex. [[rappel:Vermifuger Rocky|2027-01-30]]). Sans animal sélectionné, n'ajoute jamais ce tag.
- Annonces d'adoption : tu ne peux proposer QUE des animaux présents dans la liste ANNONCES fournie.
  N'invente jamais d'animal. Pour chaque animal proposé, ajoute le tag [[annonce:ID]] avec son identifiant
  exact, et explique en une phrase pourquoi il correspond. Propose 3 animaux maximum.
  Si aucun ne correspond, dis-le et propose d'élargir les critères.
  Si aucune liste ANNONCES n'est fournie, ne propose aucun animal précis.
  Rappelle que la décision finale revient au refuge ou au propriétaire de l'annonce.
- N'utilise pas de Markdown sauf des listes à puces avec « - ».
''';

/// Consignes de « Rédiger avec l'IA » (formulaire d'annonce d'adoption).
const kListingWriterPrompt = '''
Tu rédiges la description d'une annonce d'adoption pour l'application PetCare Community.
- En français, 3 à 5 phrases chaleureuses, à la première personne du refuge ou du propriétaire.
- Utilise uniquement les informations fournies : n'invente ni histoire, ni maladie, ni détail.
- Mets en avant le caractère et le type de foyer idéal. Pas de Markdown, pas d'emoji, pas de titre.
''';

/// Question recommandée ; [adoption] joint les annonces disponibles.
typedef AssistantSuggestion = ({String label, String question, bool adoption});

AssistantSuggestion _q(String emoji, String question, {bool adoption = false}) =>
    (label: '$emoji $question', question: question, adoption: adoption);

final _findCompanion = (
  label: '🐾 Trouver mon compagnon idéal',
  question: 'Aide-moi à trouver un animal à adopter qui correspond à mon mode de vie.',
  adoption: true,
);

/// 5 questions recommandées selon le contexte : visiteur, utilisateur, ou animal sélectionné.
List<AssistantSuggestion> recommendedQuestions({required bool signedIn, AssistantPet? pet, DateTime? now}) {
  if (pet != null) return _petQuestions(pet, now);
  if (!signedIn) {
    return [
      _findCompanion,
      _q('🏠', "Comment préparer la maison pour l'arrivée d'un animal adopté ?"),
      _q('🐶', 'Chien ou chat : lequel choisir pour un appartement ?'),
      _q('💰', 'Quel budget prévoir pour un premier animal ?'),
      _q('📋', "Comment se passe une adoption sur PetCare ?"),
    ];
  }
  return [
    _findCompanion,
    _q('🍖', 'Comment bien nourrir mon animal ?'),
    _q('🐱', 'Mon chat griffe le canapé, que faire ?'),
    _q('✈️', 'Comment faire garder mon animal pendant les vacances ?'),
    _q('🌡️', 'Comment protéger mon animal de la chaleur en été ?'),
  ];
}

List<AssistantSuggestion> _petQuestions(AssistantPet pet, DateTime? now) {
  final n = pet.name;
  final young = pet.isYoung(now);
  final senior = pet.isSenior(now);
  return switch (pet.species) {
    'dog' when young => [
        _q('💉', 'Quels vaccins pour $n et à quelles dates ?'),
        _q('🍖', 'Combien de repas par jour pour $n ?'),
        _q('🏠', 'Comment apprendre la propreté à $n ?'),
        _q('🐕', 'Comment bien socialiser $n ?'),
        _q('🪱', 'Quand vermifuger $n ?'),
      ],
    'dog' when senior => [
        _q('🦴', 'Comment prendre soin des articulations de $n ?'),
        _q('🩺', 'Quel suivi vétérinaire pour $n à son âge ?'),
        _q('🍖', 'Quelle alimentation pour $n, chien senior ?'),
        _q('🚶', "Combien d'exercice pour $n ?"),
        _q('🦷', 'Comment entretenir les dents de $n ?'),
      ],
    'dog' => [
        _q('🪱', 'Quel calendrier de vermifuge et antiparasitaire pour $n ?'),
        _q('🍖', 'Quelle quantité de croquettes pour $n ?'),
        _q('🚶', "Combien d'activité par jour pour $n ?"),
        _q('🦷', 'Comment entretenir les dents de $n ?'),
        _q('💉', 'Quand faire le rappel de vaccin de $n ?'),
      ],
    'cat' when young => [
        _q('💉', 'Quels vaccins pour $n et à quelles dates ?'),
        _q('🍖', 'Combien de repas par jour pour $n ?'),
        _q('🪣', "Comment habituer $n à la litière ?"),
        _q('✂️', 'À quel âge stériliser $n ?'),
        _q('🪱', 'Quand vermifuger $n ?'),
      ],
    'cat' when senior => [
        _q('🩺', 'Quel suivi vétérinaire pour $n à son âge ?'),
        _q('💧', 'Comment faire boire davantage $n ?'),
        _q('🍖', 'Quelle alimentation pour $n, chat senior ?'),
        _q('🦷', 'Comment surveiller les dents de $n ?'),
        _q('🛋️', 'Comment adapter la maison au confort de $n ?'),
      ],
    'cat' => [
        _q('🪱', 'Quel calendrier de vermifuge et antiparasitaire pour $n ?'),
        _q('⚖️', 'Quel est le poids idéal pour $n ?'),
        _q('🐱', 'Comment éviter que $n griffe les meubles ?'),
        _q('🧶', 'Comment occuper $n en appartement ?'),
        _q('💉', 'Quand faire le rappel de vaccin de $n ?'),
      ],
    _ => [
        _q('🥕', 'Quelle alimentation pour $n ?'),
        _q('🏠', "Quel habitat idéal pour $n ?"),
        _q('🩺', 'Quels signes de bonne santé surveiller chez $n ?'),
        _q('🧼', "Comment entretenir l'espace de $n ?"),
        _q('🎾', 'Comment occuper et stimuler $n ?'),
      ],
  };
}

const _adoptionKeywords = [
  'adopt',
  'compagnon',
  'quel animal',
  'quel chien',
  'quel chat',
  'quelle race',
  'me convien',
  'me correspond',
  'disponible',
  'annonce',
  'refuge',
];

/// Vrai si la question concerne le choix d'un animal à adopter : on joint alors les annonces.
bool isAdoptionQuestion(String question) {
  final q = question.toLowerCase();
  return _adoptionKeywords.any(q.contains);
}

/// « 2026-10-30 », pour la DATE DU JOUR et les identifiants de jour.
String isoDay(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
