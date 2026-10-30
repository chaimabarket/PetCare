# PetCare

Application mobile Flutter de **PetCare Community** : gérer ses animaux, trouver des services, publier des annonces d'animaux perdus ou trouvés et faciliter les adoptions. Le cahier des charges est dans `PetCare_Flutter_Version_Equipe.docx`, les maquettes Stitch dans `maquettes/`.

## Lancer l'application

Guide pas à pas (installation, émulateur ou téléphone, APK) : [docs/LANCER_SUR_MOBILE.md](docs/LANCER_SUR_MOBILE.md).

Prérequis : Flutter (canal stable), un émulateur Android ou un téléphone en mode développeur.

```bash
flutter pub get
flutter run
```

Sous Windows, activez le **Mode développeur** (`start ms-settings:developers`) avant `flutter pub get`.

Pour générer l'APK de démonstration :

```bash
flutter build apk --release
```

## API REST (module Utilisateurs)

Le profil et les notifications passent par une API REST Node.js dans [backend/](backend/README.md) :
`cd backend && npm install && npm start`, puis lancer l'application. Si le serveur est éteint,
l'application utilise Firestore directement.

## Backend : Firebase

Le projet utilise le projet Firebase `petcare-communit` (Authentication e-mail / mot de passe et Cloud Firestore). La configuration est déjà dans `lib/firebase_options.dart` et `android/app/google-services.json`.

Les règles de sécurité sont dans `firestore.rules`. Chaque module ajoute les règles de ses collections, puis :

```bash
firebase deploy --only firestore:rules
```

## Organisation du code

```
lib/
  core/            thème, routes, widgets communs
  features/
    auth/          connexion, inscription, mot de passe oublié, rôles
    profile/       Mon profil, modification du profil
    notifications/ notifications dans l'application
    home/          Accueil et barre de navigation (4 onglets)
    appointments/  agenda, rendez-vous, rappels (module 3)
    health/        carnet de santé, traitements, fiches santé (module 2)
```

## Module Utilisateurs (branche `Users`)

- Inscription avec choix du rôle (propriétaire, prestataire, refuge), connexion, mot de passe oublié, mode visiteur.
- Profil `users/{uid}` : `fullName`, `email`, `city`, `phone`, `role`, `createdAt`.
- Notifications `users/{uid}/notifications/{id}`.

### Pour les autres modules

Lire le rôle de l'utilisateur connecté :

```dart
ProfileRepository().watch(uid) // Stream<UserProfile?>, voir profile.role
```

Envoyer une notification à un utilisateur :

```dart
await NotificationService().send(
  toUserId: uid,
  title: 'Candidature acceptée',
  body: 'Le refuge a accepté votre demande pour Nala.',
  category: NotificationCategory.adoption,
);
```

L'Accueil (`lib/features/home/presentation/home_screen.dart`) contient des emplacements commentés pour les modules 1 (animaux), 2 (rappels de soins) et 3 (rendez-vous).

## Module Adoption (branche `Adoption`)

Code dans `lib/features/adoption/`, onglet Communauté dans `lib/features/community/`.

- Fil d'adoption avec recherche et filtres (espèce, âge, sexe, taille, ville, badges, « Adopte-moi »), favoris.
- Annonce : photos (5 max), badges de personnalité, compatibilités, besoins et conditions ; brouillon, publication, archivage.
- Candidature en 4 étapes (logement, foyer, mode de vie, récapitulatif) avec score de compatibilité visible par l'annonceur.
- Suivi : frise Envoyée → En étude → Acceptée → Adoptée. Une seule candidature acceptée (transaction) ; l'annonce passe Réservée puis Adoptée ; à l'adoption, les autres candidats sont refusés et notifiés.
- Happy Tails : l'adoptant publie une histoire Avant / Après, les membres peuvent aimer.

Collections Firestore :

| Collection | Contenu |
|---|---|
| `adoptions/{id}` | annonce ; `status` : `brouillon`, `disponible`, `reservee`, `adoptee`, `archivee` |
| `adoptions/{id}/photos/{0-4}` | photos compressées (base64, pas de Firebase Storage) |
| `adoptionApplications/{listingId}_{uid}` | candidature, réponses et score ; une seule par personne et par annonce |
| `happyTails/{listingId}` | histoire de l'adoptant |
| `users/{uid}/adoptionFavorites`, `users/{uid}/likedHappyTails` | favoris et « j'aime » |
| `reports/{id}` | signalements pour l'administrateur |

Pour le module 1 : `AdoptionRepository.confirmAdoption` est l'endroit où copier la fiche de l'animal vers l'adoptant (`adopterId`) ; le carnet de santé n'est pas transmis.

## Module Santé et dossier médical (branche `health_record`)

Écrans (maquettes Stitch, dossier `designs/stitch_petcare_flutter`) :

| Écran | Maquette | Route |
| --- | --- | --- |
| Carnet de santé (historique filtrable, prochain rappel vaccinal, urgences) | `carnet_de_sant_milo` | `AppRoutes.healthRecord` (argument : id de l'animal) |
| Ajouter un soin médical (visite, vaccin, examen, allergie, note, pièces jointes) | `ajouter_un_soin_m_dical_milo` | `AppRoutes.healthEntryForm` (id de l'animal) |
| Traitements (en cours / terminés / arrêtés, prises notées) | `traitements_milo` | `AppRoutes.treatments` (id de l'animal) |
| Nouveau traitement | pas de maquette, mêmes composants que « Ajouter un soin » | `AppRoutes.treatmentForm` (id de l'animal) |
| Fiches Santé & Conseils (recherche, catégories, marque-pages) | `fiches_sant_pr_vention_petcare_community_2` | `AppRoutes.healthSheets` |
| Détail d'une fiche | pas de maquette, consigne 2.5 de STITCH_PROMPTS.md | `AppRoutes.healthSheetDetail` (`HealthSheet`) |

L'Accueil affiche la carte « Vaccins & traitements » (prochains rappels et prises, accès au carnet de chaque animal
et aux fiches santé). Le vaccin peut créer une alerte dans les rappels du module 3 (« Créer une alerte dans l'agenda ») ;
« Prendre RDV rappel » ouvre le formulaire de rendez-vous du module 3.

Données Firestore (privées au propriétaire de l'animal, voir `firestore.rules`) :

| Collection | Contenu |
|---|---|
| `pets/{petId}/healthEntries/{id}` | `type` (`visite`, `vaccin`, `examen`, `allergie`, `note`), `title`, `date`, `description`, `practitioner`, `cost`, `vaccineName`, `batchNumber`, `nextReminderAt`, `reminderDone`, `weightKg`, `attachments` |
| `pets/{petId}/healthEntries/{id}/files/{0-2}` | pièces jointes en octets (PDF ou photo, 900 Ko max, pas de Firebase Storage) |
| `pets/{petId}/treatments/{id}` | `category`, `name`, `form`, `posology` (texte du vétérinaire), `startDate`, `endDate`, `doseTimes`, `doses`, `stoppedAt`, `stopReason`, `renewalAt` |
| `healthSheets/{id}` | fiches publiques, écrites par l'administrateur (`title`, `summary`, `category`, `species`, `sections`, `source`, `imageUrl`, `featured`, `published`) ; 5 fiches de départ sont intégrées à l'application |
| `users/{uid}/healthBookmarks/{sheetId}` | fiches enregistrées |

Le carnet et les traitements sont des sous-collections de la fiche : une copie de la fiche vers l'adoptant
(`AdoptionRepository.confirmAdoption`) ne transmet donc pas le carnet de santé.

### Pour les autres modules

Module 1 (Profils) — carte « Carnet de santé » de la fiche animal :

```dart
Navigator.of(context).pushNamed(AppRoutes.healthRecord, arguments: pet.id);
```

## Module Rendez-vous et rappels (branche `rendez-vous`)

Écrans (maquettes Stitch de la branche `Adoption`, dossier `designs/stitch_petcare_flutter`) :

| Écran | Maquette | Route |
| --- | --- | --- |
| Agenda (semaine / mois, filtres animal et statut) | `agenda_rendez_vous_petcare_community` | `AppRoutes.agenda` |
| Détail du rendez-vous (vue client et vue prestataire) | `d_tail_du_rendez_vous_toilettage` | `AppRoutes.appointmentDetail` (argument : id) |
| Nouveau rendez-vous / report | `nouveau_rendez_vous` | `AppRoutes.appointmentForm` (argument : `AppointmentFormArgs`) |
| Rappels & soins | `liste_des_rappels_petcare_community` | `AppRoutes.reminders` |

L'Accueil affiche les 2 prochains rendez-vous (« Voir l'agenda ») et la carte « Rappels de soins » ouvre la liste des rappels.

Données Firestore :

- `appointments/{id}` : `ownerId`, `petName` (+ `petId`, `petBreed`, `petPhotoUrl`), `title`, `type`, `startsAt`, `endsAt`,
  `status` (`planned`, `confirmed`, `completed`, `cancelled`), `providerId` (null pour un rendez-vous personnel),
  `providerName`, `providerAddress`, `providerPhone`, `serviceId`, `price`, `place`, `location`, `notes`,
  `reminderMinutes`, `pushReminder`, `reminderDoneAt`, `cancelReason`, `version`, `changes` (historique).
- `reminders/{id}` : rappels de soins créés à la main (`ownerId`, `petName`, `title`, `category`, `dueAt`, `done`…).

Règles métier appliquées dans `AppointmentRepository` et dans `firestore.rules` : un rendez-vous personnel démarre
confirmé, une réservation en attente ; report et annulation seulement avant le début ; « Terminé » seulement après
la fin ; « Reporté » est une action de l'historique ; une version obsolète est refusée ; un animal ne peut pas avoir
deux rendez-vous actifs qui se chevauchent.

### Pour les autres modules

Module 6 (Services) — créer une réservation depuis « Réserver un créneau » :

```dart
await AppointmentRepository().createBooking(
  petName: 'Milo', providerId: providerUid, providerName: 'Salon Amine',
  serviceId: serviceId, title: 'Toilettage', type: AppointmentType.grooming,
  startsAt: slotStart, duration: const Duration(minutes: 45), price: 35,
);
```

Module 1 (Profils) — ouvrir l'agenda filtré sur un animal :

```dart
Navigator.of(context).pushNamed(AppRoutes.agenda, arguments: pet.name);
```

Le choix de l'animal lit la collection `pets` (`ownerId`, `name`, `breed`, `photoUrl`, `status`) dès que le module 1
l'aura créée ; en attendant, « Autre compagnon » permet de saisir le nom.

Après un changement de `firestore.rules` : `firebase deploy --only firestore:rules`.
