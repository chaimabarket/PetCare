# PetCare

Application mobile Flutter de **PetCare Community** : gérer ses animaux, trouver des services, publier des annonces d'animaux perdus ou trouvés et faciliter les adoptions. Le cahier des charges est dans `PetCare_Flutter_Version_Equipe.docx`, les maquettes Stitch dans `maquettes/`.

## Lancer l'application

### Vue téléphone dans VS Code, sans installation Android

1. Ouvrir ce dossier (`PetCare`) dans VS Code et installer les extensions recommandées.
2. Dans **Exécuter et déboguer**, choisir **PetCare - Phone Preview**, puis appuyer sur **F5**.
3. Attendre que Flutter affiche l'adresse `http://localhost:7357`.
4. Ouvrir la palette (**Ctrl+Maj+P**) et lancer **Mobile Viewer: Open Preview**.
5. Saisir `http://localhost:7357` dans Mobile Viewer, puis choisir **Pixel 7** ou un autre téléphone.

Cette vue affiche la version web de Flutter dans un cadre de téléphone ; elle ne simule pas Android.
Utiliser le bouton de rechargement de Mobile Viewer pour actualiser la vue. **Maj+F5** arrête le serveur
lancé avec F5. Les points d'arrêt Dart ne sont pas activés dans cette configuration de prévisualisation.

### Sur un appareil Android

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
