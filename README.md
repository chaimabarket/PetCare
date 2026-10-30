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

## Assistant IA (branche `chatbot`)

Code dans `lib/features/assistant/`. Gemini via **Firebase AI Logic** (Gemini Developer API, plan gratuit Spark) : aucune clé dans l'application.

- Visiteur : questions générales et suggestions d'animaux à adopter (cartes vers les annonces).
- Connecté : choix d'un de ses animaux (fiche `pets` et carnet de santé joints), 5 questions recommandées selon l'animal, « Créer un rappel » depuis une réponse (module Rendez-vous et rappels), historique des 10 dernières conversations, 👍 / 👎, copier. 30 messages par jour.
- Formulaire d'annonce d'adoption : bouton « Rédiger avec l'IA ».

Mise en route (une fois, sur la console Firebase) : **AI Logic → Get started → Gemini Developer API** (pas Vertex AI), puis vérifier le nom du modèle gratuit dans `assistant_prompt.dart` (`kAssistantModel`).

Pour le module 2 : `AssistantPetRepository.fetchHealthSummary` renvoie quelques lignes du carnet de santé ; elles sont ajoutées automatiquement aux réponses sur l'animal.

| Collection | Contenu |
|---|---|
| `users/{uid}/assistantUsage/{AAAA-MM-JJ}` | compteur de messages du jour |
| `users/{uid}/assistantChats/{id}` et `/messages` | historique privé, avis 👍 / 👎 |
