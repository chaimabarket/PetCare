import 'health_sheet.dart';

/// Fiches de départ, affichées avant que l'administrateur publie ses propres fiches.
///
/// Information générale tirée des sources citées ; elle ne remplace pas l'avis d'un vétérinaire.
const starterHealthSheets = <HealthSheet>[
  HealthSheet(
    id: 'tiques-puces-printemps',
    title: 'Comment protéger votre compagnon contre les tiques et puces au printemps ?',
    summary:
        "Colliers répulsifs, pipettes spot-on et comprimés : comparez les modes d'action, spectres de couverture et fréquences d'administration.",
    category: HealthSheetCategory.parasites,
    species: ['Chien', 'Chat'],
    author: 'Rédaction PetCare',
    organization: "D'après l'ESCCAP",
    readMinutes: 4,
    imageAsset: 'assets/images/health/featured.jpg',
    featured: true,
    source: "ESCCAP – Guide n°3 « Contrôle des ectoparasites chez le chien et le chat ».",
    sections: [
      HealthSheetSection(
        heading: 'Pourquoi le printemps ?',
        body:
            "Les tiques redeviennent actives dès que les températures remontent, et les puces se multiplient avec la chaleur et l'humidité. Dans un logement chauffé, les puces restent toutefois présentes toute l'année : la protection ne s'arrête pas en hiver.",
      ),
      HealthSheetSection(
        heading: 'Les trois modes de protection',
        body:
            "Pipettes spot-on : appliquées sur la peau entre les omoplates, elles protègent en général un mois. Colliers : certains agissent plusieurs mois. Comprimés : ils protègent d'un à trois mois selon le produit, mais la tique doit commencer à se nourrir pour être éliminée. Respectez toujours l'espèce et le poids indiqués sur la boîte.",
      ),
      HealthSheetSection(
        heading: 'Attention aux chats',
        body:
            "N'appliquez jamais à un chat un produit pour chien contenant de la perméthrine : cette molécule est très toxique pour le chat, parfois mortelle. Demandez conseil à votre vétérinaire si chien et chat vivent ensemble.",
      ),
      HealthSheetSection(
        heading: 'Après chaque promenade',
        body:
            "Inspectez la tête, les oreilles, les aisselles et l'espace entre les doigts. Une tique retirée rapidement avec un tire-tique transmet beaucoup moins de maladies.",
      ),
    ],
  ),
  HealthSheet(
    id: 'tiques-maladie-de-lyme',
    title: 'Tiques et maladie de Lyme : symptômes, retrait et prévention',
    summary: "Repérer les signes précoces d'infection, technique du tire-tique et protection pendant toute la saison.",
    category: HealthSheetCategory.parasites,
    species: ['Chien', 'Chat'],
    author: 'Rédaction PetCare',
    organization: "D'après l'ESCCAP",
    readMinutes: 3,
    imageAsset: 'assets/images/health/lyme.jpg',
    source: 'ESCCAP – Guide n°3 (ectoparasites) et Guide n°5 (maladies vectorielles du chien et du chat).',
    sections: [
      HealthSheetSection(
        heading: 'La maladie',
        body:
            "La borréliose de Lyme est transmise par certaines tiques. Chez le chien, l'infection passe souvent inaperçue. Quand des signes apparaissent, quelques semaines à quelques mois après la morsure, on observe de la fièvre, un abattement, une boiterie qui change de patte et des articulations gonflées. La maladie est rare chez le chat.",
      ),
      HealthSheetSection(
        heading: 'Retirer une tique',
        body:
            "Utilisez un tire-tique : glissez-le sous la tique, tournez doucement sans tirer, puis désinfectez et lavez-vous les mains. N'appliquez ni éther ni alcool avant le retrait. La bactérie se transmet surtout après 24 à 48 heures de fixation : un retrait rapide réduit fortement le risque.",
      ),
      HealthSheetSection(
        heading: 'Prévenir',
        body:
            "Un antiparasitaire actif contre les tiques, renouvelé pendant toute la saison, reste la meilleure protection. Un vaccin existe pour le chien : son intérêt dépend de la région, parlez-en à votre vétérinaire.",
      ),
    ],
  ),
  HealthSheet(
    id: 'alimentation-sans-cereales',
    title: 'Alimentation sans céréales : bienfaits et contre-indications',
    summary: 'Ce que disent les études, les vraies allergies alimentaires et les précautions avant de changer de croquettes.',
    category: HealthSheetCategory.nutrition,
    species: ['Chien'],
    author: 'Rédaction PetCare',
    organization: "D'après la FEDIAF et la FDA",
    readMinutes: 5,
    imageAsset: 'assets/images/health/nutrition.jpg',
    source:
        "FEDIAF – Nutritional Guidelines for Complete and Complementary Pet Food ; FDA – enquête sur le lien possible entre certains régimes et la cardiomyopathie dilatée du chien.",
    sections: [
      HealthSheetSection(
        heading: 'Les céréales ne sont pas un problème en soi',
        body:
            "Bien cuites, les céréales sont digestes et apportent de l'énergie. Les allergies alimentaires du chien concernent plus souvent des protéines (bœuf, produits laitiers, poulet, blé) que les céréales dans leur ensemble.",
      ),
      HealthSheetSection(
        heading: 'En cas de suspicion d\'allergie',
        body:
            "Démangeaisons, otites à répétition ou troubles digestifs se confirment par un régime d'éviction d'environ huit semaines, avec une protéine nouvelle ou hydrolysée, prescrit et suivi par le vétérinaire.",
      ),
      HealthSheetSection(
        heading: 'Une précaution',
        body:
            "En 2018, l'agence américaine FDA a ouvert une enquête sur un lien possible entre certains régimes sans céréales riches en légumineuses (pois, lentilles) et la cardiomyopathie dilatée du chien. Le lien n'est pas démontré, mais demandez l'avis de votre vétérinaire avant d'adopter ce type d'aliment.",
      ),
      HealthSheetSection(
        heading: "Changer d'aliment",
        body: 'Faites toujours une transition progressive sur environ sept jours en mélangeant ancien et nouvel aliment.',
      ),
    ],
  ),
  HealthSheet(
    id: 'protocole-vaccinal-chiot-chaton',
    title: 'Protocole vaccinal du chiot et chaton : le calendrier complet',
    summary: 'Premières injections, rappels et vaccins essentiels expliqués étape par étape.',
    category: HealthSheetCategory.vaccines,
    species: ['Chiot', 'Chaton'],
    author: 'Rédaction PetCare',
    organization: "D'après la WSAVA",
    readMinutes: 6,
    imageAsset: 'assets/images/health/vaccins.jpg',
    source: 'WSAVA – Guidelines for the Vaccination of Dogs and Cats (2024).',
    sections: [
      HealthSheetSection(
        heading: 'Pourquoi plusieurs injections ?',
        body:
            "Les anticorps transmis par la mère protègent le jeune animal mais neutralisent aussi le vaccin. On vaccine donc en série jusqu'à ce que ces anticorps aient disparu.",
      ),
      HealthSheetSection(
        heading: 'Chiot',
        body:
            "Vaccins essentiels : maladie de Carré, hépatite de Rubarth et parvovirose. Première injection vers 6 à 8 semaines, puis toutes les 2 à 4 semaines jusqu'à 16 semaines au moins, et un rappel entre 6 mois et 1 an. La leptospirose demande deux injections puis un rappel annuel. La rage est obligatoire dans de nombreux pays et pour voyager.",
      ),
      HealthSheetSection(
        heading: 'Chaton',
        body:
            "Vaccins essentiels : typhus (panleucopénie) et coryza. Même rythme : dès 6 à 8 semaines, toutes les 2 à 4 semaines jusqu'à 16 semaines au moins, puis un rappel entre 6 mois et 1 an. La leucose féline est conseillée aux chats qui sortent.",
      ),
      HealthSheetSection(
        heading: 'Ensuite',
        body:
            "Les rappels des vaccins essentiels se font en général tous les trois ans chez l'adulte, ceux des autres vaccins souvent chaque année. Notez chaque vaccin et son numéro de lot dans le carnet de santé.",
      ),
    ],
  ),
  HealthSheet(
    id: 'coup-de-chaleur',
    title: "Reconnaître les signes du coup de chaleur chez l'animal",
    summary: 'Les signes qui doivent alerter et les gestes à faire en attendant le vétérinaire.',
    category: HealthSheetCategory.emergency,
    species: ['Chien', 'Chat'],
    author: 'Rédaction PetCare',
    organization: "D'après la RSPCA",
    readMinutes: 2,
    imageAsset: 'assets/images/health/chaleur.jpg',
    source: 'RSPCA – Dogs and heatstroke ; AVMA – Pets in vehicles.',
    sections: [
      HealthSheetSection(
        heading: 'Les signes',
        body:
            "Halètement intense, gencives rouge foncé, bave abondante, faiblesse, démarche titubante, vomissements, puis convulsions ou perte de connaissance. Les races à nez court, les animaux âgés ou en surpoids sont les plus exposés.",
      ),
      HealthSheetSection(
        heading: 'Que faire tout de suite',
        body:
            "Mettez l'animal à l'ombre, mouillez-le avec de l'eau fraîche (pas glacée), ventilez et proposez-lui de l'eau sans le forcer. Appelez immédiatement un vétérinaire et rendez-vous à la clinique, même si l'animal semble aller mieux.",
      ),
      HealthSheetSection(
        heading: 'Prévenir',
        body:
            "Ne laissez jamais un animal dans une voiture, même fenêtre entrouverte. Promenez-le tôt le matin ou le soir et laissez toujours de l'eau fraîche et de l'ombre à disposition.",
      ),
    ],
  ),
];
