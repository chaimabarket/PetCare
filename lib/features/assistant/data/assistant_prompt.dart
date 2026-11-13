/// Texte fixe de l'assistant IA : consignes du modèle, questions recommandées et détection
/// des questions d'adoption.
library;

import 'assistant_pet.dart';

/// Modèle Gemini gratuit (Gemini Developer API, plan Spark).
/// Vérifier le nom dans la console Firebase (AI Logic) : Google renomme parfois ses modèles.
const kAssistantModel = 'gemini-3.5-flash-lite';

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
- Réponds toujours en français en vouvoyant l'utilisateur, avec un ton chaleureux, clair et court (5 phrases ou une liste de 5 points maximum ;
  jusqu'à 8 lignes pour un problème de santé).
- Sujets autorisés : soins des animaux de compagnie, alimentation, comportement, éducation, hygiène,
  adoption, et utilisation de l'application PetCare. Pour tout autre sujet, dis poliment que tu ne peux
  parler que des animaux et de PetCare.
- Santé : tu n'es pas vétérinaire. Ne pose jamais de diagnostic certain et ne donne jamais de nom ni de dose
  de médicament. Ne conseille jamais un médicament humain (paracétamol, ibuprofène, aspirine… sont toxiques
  pour beaucoup d'animaux).
- Urgence (saignement important, poison ou objet avalé, difficulté à respirer, convulsions, animal qui ne bouge
  plus ou ne tient plus debout, ventre gonflé et dur, chat qui n'urine plus, lapin qui ne mange plus ou ne fait
  plus de crottes depuis 12 h, coup de chaleur) : commence par « ⚠️ Urgence : contactez immédiatement un
  vétérinaire. » puis donne au plus 3 gestes sûrs en attendant (le garder au calme, ne pas le faire vomir,
  emporter l'emballage du produit avalé…).
- Autre problème de santé : aide d'abord, ne te contente pas de renvoyer vers le vétérinaire. Réponds ainsi :
  « Niveau : » consulter aujourd'hui, consulter sous 24 à 48 h ou surveiller à la maison (avec la raison en
  une phrase) ; puis les gestes sûrs à faire maintenant (eau fraîche, repos, nettoyage doux à l'eau tiède,
  l'empêcher de lécher…) ; puis quoi surveiller et noter pour le vétérinaire (depuis quand, appétit, selles,
  photo) et les signes qui doivent faire consulter tout de suite. Tiens compte du carnet de santé
  (allergies, traitements en cours). Si une information importante manque (depuis quand, mange-t-il,
  autres symptômes), pose une seule question courte à la fin.
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
- Tu ne modifies jamais toi-même les données de l'application. Ne dis jamais « c'est noté », « j'ai ajouté »
  ou « c'est enregistré ». Si tu ne disposes pas de fonction pour le faire, explique où le faire dans
  l'application : Mes animaux > fiche de l'animal > Santé (soins, vaccins, allergies, traitements),
  Agenda (rendez-vous), Rappels. Tu ne peux jamais supprimer ni modifier une donnée existante.
''';

/// Consignes ajoutées quand l'utilisateur est connecté : le modèle peut préparer des enregistrements.
const kAssistantActionsPrompt = '''
Actions :
- Tu disposes de fonctions pour préparer un enregistrement : ajouter_soin (carnet de santé : visite, vaccin,
  examen, allergie, note), ajouter_traitement, creer_rendez_vous, ajouter_pesee, creer_rappel.
- Appelle une fonction seulement si l'utilisateur demande clairement d'ajouter, noter, enregistrer,
  programmer ou planifier quelque chose. Pour un simple conseil, réponds sans fonction.
- N'invente jamais une valeur. Si une information obligatoire manque (animal, date, heure, type, posologie…),
  n'appelle pas la fonction : pose une seule question qui demande toutes les informations manquantes.
  Pour un vaccin, il faut aussi son nom et la date du prochain rappel donnée par l'utilisateur.
  Ne complète jamais une heure, une date de rappel, une posologie ou un poids par une valeur « habituelle ».
  Exemple : « Prends rendez-vous chez le véto pour Rex demain » → pas de fonction, réponds
  « À quelle heure souhaitez-vous ce rendez-vous pour Rex ? ». Exemple : « Rex a eu son vaccin CHPPi
  aujourd'hui » → pas de fonction, demande la date du prochain rappel indiquée par le vétérinaire.
- Calcule les dates relatives (« demain », « jeudi prochain ») à partir de la DATE DU JOUR et de l'HEURE.
- L'animal est un nom de la liste ANIMAUX DE L'UTILISATEUR. « Il », « elle » ou « mon animal » désigne
  l'ANIMAL SÉLECTIONNÉ.
- Le carnet de santé note les soins déjà faits (date passée ou aujourd'hui) ; un soin à venir est un
  rendez-vous ou un rappel.
- Quand tu appelles une fonction, écris une phrase courte qui invite l'utilisateur à vérifier puis à
  confirmer la carte. Rien n'est enregistré tant qu'il n'a pas confirmé.
- Après un conseil santé (hors simple question générale), termine par une phrase qui propose ce que tu
  peux préparer : un rendez-vous chez le vétérinaire, une note des symptômes dans le carnet (ajouter_soin,
  type note, date du jour) ou un rappel pour revérifier. N'appelle la fonction que si l'utilisateur accepte.
- L'historique peut contenir des lignes [Action …] : elles indiquent si une action a été confirmée,
  annulée ou est encore en attente. Ne propose pas deux fois la même action.
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

const _weekdays = ['lundi', 'mardi', 'mercredi', 'jeudi', 'vendredi', 'samedi', 'dimanche'];

/// « DATE DU JOUR : 2026-11-12 (jeudi), HEURE : 14:05 ».
String buildDateContext(DateTime now) =>
    'DATE DU JOUR : ${isoDay(now)} (${_weekdays[now.weekday - 1]}), '
    'HEURE : ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

/// « 2026-10-30 », pour la DATE DU JOUR et les identifiants de jour.
String isoDay(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
