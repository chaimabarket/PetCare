# Lancer PetCare sur mobile (Android)

PetCare est une application **mobile** : elle se lance sur un téléphone ou un émulateur **Android**.
N'utilisez pas `flutter run -d chrome` ni `-d windows`.

Le projet contient les modules **Utilisateurs**, **Adoption** et **Rendez-vous**. Les autres onglets
(Mes animaux, Services) affichent « Bientôt disponible ».

## 1. Installer les outils (une seule fois)

| Outil | Remarque |
|---|---|
| [Flutter](https://docs.flutter.dev/get-started/install) (canal stable) | Version testée : 3.47.7 (Dart 3.13.5). Chemin sans espace, par exemple `C:\flutter`. |
| Android SDK | Soit Android Studio, soit les « command-line tools ». |
| JDK 17 | Gradle compile le projet en Java 17. |
| Git | Pour récupérer le code. |
| VS Code + extensions **Flutter** et **Dart** | Facultatif mais pratique. |

Sous **Windows**, activez le **Mode développeur** (`start ms-settings:developers`) : Flutter en a besoin
pour installer les paquets Firebase.

Vérifiez l'installation :

```bash
flutter doctor
```

La ligne **Android toolchain** doit être cochée. Si Flutter demande d'accepter les licences :
`flutter doctor --android-licenses`.

## 2. Récupérer le projet

```bash
git clone https://github.com/chaimabarket/PetCare.git
cd PetCare
git checkout main
flutter pub get
```

## 3. Préparer un appareil Android

### Option A : l'émulateur (téléphone virtuel)

1. Créez un appareil dans Android Studio (**Device Manager → Create Device**), par exemple un **Pixel 7**
   avec l'image système **API 36, Google APIs, x86_64**.
2. Démarrez-le. Si l'application affiche **« Pas de connexion internet »**, relancez l'émulateur en lui
   imposant des DNS (le DNS du PC ou du VPN est parfois inutilisable) :

```bash
emulator -avd NOM_DE_VOTRE_APPAREIL -dns-server 8.8.8.8,1.1.1.1
```

L'émulateur demande environ **3 Go de mémoire** : fermez Chrome et les programmes inutiles avant de le démarrer.

### Option B : un vrai téléphone Android

1. **Paramètres → À propos du téléphone** : appuyez 7 fois sur **Numéro de build** pour activer le mode développeur.
2. **Options pour les développeurs** : activez **Débogage USB**.
3. Branchez le téléphone avec un câble de données et acceptez la fenêtre « Autoriser le débogage USB ».

## 4. Lancer l'application

```bash
flutter devices
```

L'appareil Android doit apparaître (par exemple `emulator-5554` ou le nom de votre téléphone). Puis :

```bash
flutter run -d emulator-5554
```

Remplacez `emulator-5554` par l'identifiant affiché par `flutter devices`. La première compilation
prend plusieurs minutes (Gradle télécharge ses dépendances) ; les suivantes sont bien plus rapides.

Pendant que l'application tourne : `r` recharge le code, `R` redémarre, `q` quitte.

Dans VS Code, vous pouvez aussi choisir l'appareil en bas à droite, puis appuyer sur **F5**.

## 5. Se connecter

Le backend est le projet Firebase **petcare-communit** (déjà configuré dans le code).
Au premier lancement, créez un compte depuis **Inscription** (choisissez un rôle : propriétaire,
prestataire ou refuge), ou utilisez **Continuer en visiteur** pour consulter sans compte.

Pour tester l'adoption, il faut **deux comptes** (un qui publie, un qui candidate). Pour les e-mails de
test, utilisez une adresse qui vous appartient ou une fausse adresse en `@exemple.com`.

## 6. Règles Firestore

Les règles de sécurité sont dans `firestore.rules`. Après chaque changement de ce fichier, un membre
ayant accès au projet Firebase les publie :

```bash
firebase login
firebase deploy --only firestore:rules
```

Si les règles ne sont pas à jour, certains écrans (annonces d'adoption, agenda) affichent
**« Vous n'avez pas accès à ces informations pour le moment »**.

## 7. Générer l'APK à installer

```bash
flutter build apk --release
```

Le fichier se trouve dans `build/app/outputs/flutter-apk/app-release.apk`. Pour l'installer sur un
appareil branché : `adb install -r build/app/outputs/flutter-apk/app-release.apk`.

## Problèmes fréquents

| Symptôme | Solution |
|---|---|
| `flutter devices` ne liste aucun appareil Android | Démarrez l'émulateur, ou rebranchez le téléphone et acceptez le débogage USB. |
| « Pas de connexion internet » sur l'émulateur | Relancez-le avec `-dns-server 8.8.8.8,1.1.1.1` (étape 3). |
| Gradle s'arrête avec une erreur de mémoire | Fermez Chrome et les programmes lourds, puis relancez `flutter run`. |
| Erreur Kotlin « Could not close incremental caches » | `flutter clean`, puis `flutter run` (la compilation incrémentale est déjà désactivée dans `android/gradle.properties`). |
| « Please enable Developer Mode » (Windows) | `start ms-settings:developers`, activez le Mode développeur. |
| L'émulateur reste bloqué au démarrage | Vérifiez la mémoire libre, et que le projet et le SDK ne sont pas sur un disque externe instable. |
