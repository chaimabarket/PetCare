# PetCare

Application mobile Flutter de **PetCare Community** : gérer ses animaux, trouver des services, publier des annonces d'animaux perdus ou trouvés et faciliter les adoptions. Le cahier des charges est dans `PetCare_Flutter_Version_Equipe.docx`, les maquettes Stitch dans `maquettes/`.

## Lancer l'application

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
