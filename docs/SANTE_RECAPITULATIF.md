# Module Santé : récapitulatif du travail

Ce document retrace tout ce qui a été fait sur le module 2 « Santé et dossier médical » de PetCare : ce qui
existe, où c'est, ce qui a été vérifié et ce qui reste à faire.

## Les branches en bref

| Branche | État | Contenu |
|---|---|---|
| `health_record` | Poussée (commit `750a61f`), fusionnée ensuite dans `main` | Première version du module : écrans Stitch du carnet, des soins, des traitements et des fiches santé, sur Firestore |
| `health-features` | **Locale, non poussée** (5 commits, `10f3e6e` → `e024a45`) | API REST Santé, onglet Santé, tableau du jour, export PDF, scan d'ordonnance |
| `stash@{0}` | Mis de côté | Ancienne version de l'API REST écrite sur `health_record`. Tout ce qui servait a été repris dans `health-features` : on peut le supprimer (`git stash drop`) |

Rien n'a été déployé sur Firebase.

---

## 1. Première version du module (branche `health_record`)

Écrans faits d'après les maquettes Stitch du dossier `designs/stitch_petcare_flutter` :

| Écran | Maquette | Route |
|---|---|---|
| Carnet de santé (historique filtrable, prochain rappel vaccinal, urgences) | `carnet_de_sant_milo` | `AppRoutes.healthRecord` (id de l'animal) |
| Ajouter un soin médical (visite, vaccin, examen, allergie, note, pièces jointes) | `ajouter_un_soin_m_dical_milo` | `AppRoutes.healthEntryForm` |
| Traitements (en cours, terminés, arrêtés, prises notées) | `traitements_milo` | `AppRoutes.treatments` |
| Nouveau traitement | pas de maquette, mêmes composants | `AppRoutes.treatmentForm` |
| Fiches Santé & Conseils (recherche, catégories, marque-pages) | `fiches_sant_pr_vention_..._2` | `AppRoutes.healthSheets` |
| Détail d'une fiche | pas de maquette, consigne 2.5 de `STITCH_PROMPTS.md` | `AppRoutes.healthSheetDetail` |

- Données sous la fiche de l'animal : `pets/{petId}/healthEntries`, `.../files/{0-2}` (pièces jointes en
  octets), `pets/{petId}/treatments`. Le carnet ne suit donc pas une copie de la fiche vers un adoptant.
- Fiches santé publiques dans `healthSheets` (écrites par l'administrateur), 5 fiches de départ intégrées avec
  leurs sources (ESCCAP, WSAVA, FEDIAF/FDA, RSPCA).
- Carte « Vaccins & traitements » sur l'Accueil.
- Packages ajoutés : `material_symbols_icons` (icônes exactes des maquettes), `file_picker` (PDF en pièce jointe).

**Points signalés à l'époque, toujours d'actualité :** certains textes des maquettes ne sont pas vrais tels
quels (« chiffrées de bout en bout », « Validé par des docteurs vétérinaires »), le numéro d'urgence 3115 est
français et le coût est en € alors que le reste de l'application est en DT.

---

## 2. Branche `health-features`

Créée depuis `main` à jour. Cinq étapes, chacune vérifiée (`flutter analyze`, `flutter test`, `npm test`) puis
commitée.

### Étape A : API REST Santé (commit `10f3e6e`)

Nouveau module `backend/src/health/` (`enums.js`, `validation.js`, `routes.js`) sur le modèle de
`backend/src/pets/`. Le serveur appelle Firestore avec le jeton de l'utilisateur : les règles s'appliquent.

| Méthode | Route | Rôle |
|---|---|---|
| GET | `/api/health/summary` | Synthèse de tous mes animaux en **un seul appel** : vaccins à rappeler, dernière visite, allergies, traitements en cours. Gardée 30 s en mémoire par utilisateur, vidée à chaque écriture santé |
| GET / POST | `/api/pets/{petId}/health/entries` | Liste et ajout d'un soin (pièces jointes dans le même commit) |
| GET | `.../entries/{id}` et `.../entries/{id}/files/{index}` | Un soin, une pièce jointe |
| PATCH | `.../entries/{id}/reminder-done` | Rappel vaccinal fait |
| DELETE | `.../entries/{id}` | Supprime un soin et ses fichiers |
| GET / POST | `/api/pets/{petId}/health/treatments` | Liste et ajout d'un traitement |
| POST | `.../treatments/{id}/doses` | Noter une prise, maintenant ou à l'heure d'un créneau (`at`) |
| POST | `.../treatments/{id}/stop` | Arrêt avec raison |

- **Animal archivé** : le carnet se lit, toute écriture renvoie `409`.
- Le prochain contrôle d'une visite (`nextReminderAt`) est accepté.
- Routes documentées dans `backend/README.md`.

### Étape B : onglet Santé et carnet via l'API (commit `f03f2b6`)

- **5 onglets** : Accueil, Mes animaux, **Santé**, Communauté, Services. Liste et numéros partagés dans
  `lib/core/navigation/main_tabs.dart` (`MainTab`), utilisés par la structure principale, le module 3 et le
  module Santé. Libellés français et anglais.
- **Onglet Santé** (`health_tab_screen.dart`) : une carte par animal actif (photo, nom, espèce, vaccin « à jour »,
  « bientôt » ou « en retard » en rouge, traitements en cours et prises du jour, dernière visite, allergies), les
  animaux qui demandent une action en premier ; animaux archivés dans une section repliée ; cas visiteur et
  « aucun animal » (bouton « Ajouter un animal »).
- **Quota Firestore** : toute la page vient de la synthèse, relue toutes les 60 s et aussitôt après une
  modification. La carte de l'Accueil lit la même synthèse au lieu de 2 écoutes permanentes par animal.
- `HealthRepository` passe par l'API, avec repli sur Firestore si le serveur est éteint (comme `PetRepository`).
- **Lecture seule** des animaux archivés dans le carnet et les traitements (boutons masqués, bandeau).
- **Bug corrigé** : le prochain contrôle d'une visite n'était pas enregistré dans le carnet.
- `firestore.rules` : nouvelle fonction `petOwnerActive` qui refuse aussi l'écriture directe dans le carnet d'un
  animal archivé. **Non déployée.**

### Étape C : tableau du jour (commit `4bedc96`)

En haut de l'onglet Santé, construit à partir de la synthèse (aucun appel en plus) :

- toutes les prises du jour, tous animaux confondus, à cocher avec confirmation ; une prise notée ne s'annule pas
  (les règles n'acceptent qu'un ajout) ;
- un créneau passé est noté à son heure, un créneau dans moins de 3 h est noté maintenant, au-delà il est « À venir » ;
- vaccins en retard puis ceux des 30 prochains jours ; toucher une ligne ouvre le carnet.

### Étape D : export PDF du carnet (commit `3c51ca2`)

- Packages `pdf 3.13.1` et `printing 5.15.1` (même auteur, maintenus, compatibles Flutter 3.47).
- Contenu : profil, vaccins et rappels, visites et examens, allergies, traitements en cours et passés, pied de page
  « ne remplace pas un carnet vétérinaire officiel ». Les notes libres ne sont pas incluses.
- **Aucune coordonnée** : ni e-mail ni téléphone du propriétaire, et ceux écrits dans le texte libre sont masqués.
- Police Inter embarquée (`assets/fonts/`, 67 Ko par graisse, licence OFL) pour les accents, « œ », « € ».
- Dans le carnet : ⤓ enregistre le PDF, le bouton de partage ouvre la feuille de partage. Remplace l'ancien
  export texte.

### Étape E : scan d'ordonnance ou de vignette (commit `e024a45`)

- `google_mlkit_text_recognition 0.17.1` : texte lu sur le téléphone, hors ligne, sans quota.
- `prescription_parser.dart` (Dart pur, testé) : nom du vaccin ou du médicament, date du soin (péremption ignorée),
  prochain rappel, numéro de lot, vétérinaire sans téléphone ni e-mail. **Jamais de posologie ni de diagnostic.**
- Bouton « Scanner une vignette ou une ordonnance » dans « Ajouter un soin » et « Nouveau traitement » ; bandeau
  « vérifiez et corrigez avant d'enregistrer » ; rien n'est enregistré automatiquement.
- Bouton affiché seulement sur Android et iOS ; import conditionnel pour que la version web compile.

---

## 3. Fichiers modifiés

**Nouveaux** (`health-features`) : `backend/src/health/*`, `backend/test/health.test.js`,
`lib/core/navigation/main_tabs.dart`, `lib/features/health/data/health_summary.dart`, `health_pdf.dart`,
`prescription_parser.dart`, `text_scanner*.dart`, `lib/features/health/presentation/health_tab_screen.dart`,
`widgets/health_today_card.dart`, `widgets/scan_prescription.dart`, `assets/fonts/*`, 5 fichiers de tests.

**Fichiers du module Santé déjà existants, modifiés :**

| Fichier | Changement |
|---|---|
| `health_repository.dart` | API REST avec repli Firestore, synthèse, prise à une heure donnée, correction du prochain contrôle |
| `health_entry.dart`, `treatment.dart`, `health_pet.dart` | Lecture du JSON de l'API ; statut archivé et sexe de l'animal |
| `health_record_screen.dart`, `treatments_screen.dart` | Lecture seule des animaux archivés ; export PDF |
| `medical_entry_form_screen.dart`, `treatment_form_screen.dart` | Bouton de scan et pré-remplissage |
| `health_ui.dart`, `health_sheets_screen.dart`, `health_sheet_detail_screen.dart` | Barre du bas à 5 onglets, numéros `MainTab` |

**Hors du module :** `main_shell.dart`, `home_screen.dart`, `rdv_ui.dart` (module 3), `firestore.rules`,
fichiers de traduction (`lib/l10n`), `pubspec.yaml` et `pubspec.lock`, fichiers d'enregistrement des plugins
(macOS, Linux, Windows), `backend/src/app.js`, `README.md` et `backend/README.md`.

---

## 4. Vérifications

| Vérification | Résultat |
|---|---|
| `flutter analyze` | Aucun problème |
| `flutter test` | 85/85 |
| `cd backend; npm test` | 59/59 (dont 16 tests Santé avec un faux Firestore) |
| `flutter build web` | Réussi |
| PDF d'exemple généré et relu | Mise en page, accents et masquage corrects |
| `flutter build apk` | **Non vérifié** : le NDK Android 28.2 n'est pas installé (besoin déjà présent sur `main`) |
| Règles Firestore | **Non compilées** : pas d'émulateur Firestore sur le poste ; vérifiées au déploiement |
| Application sur l'émulateur | **Non testée** : voir la liste de tests manuels ci-dessous |

---

## 5. À faire

1. **Installer le NDK** : Android Studio → *SDK Manager* → *SDK Tools* → « Show Package Details » →
   *NDK (Side by side)* **28.2.13676358**, ou :
   ```powershell
   & "$env:LOCALAPPDATA\Android\sdk\cmdline-tools\latest\bin\sdkmanager.bat" "ndk;28.2.13676358"
   ```
2. **Déployer `firestore.rules`** après l'avoir comparé aux règles en ligne (Firebase remplace tout le fichier) :
   `firebase deploy --only firestore:rules --project petcare-communit`.
3. **Pousser `health-features`** quand les tests manuels sont faits, puis ouvrir une pull request vers `main`.
4. Supprimer `stash@{0}` (`git stash drop`) s'il ne sert plus.
5. Décider des textes des maquettes à corriger (chiffrement, validation vétérinaire, 3115, €).
6. Module 1 : depuis la fiche d'un animal, toucher un onglet dans la barre du carnet ramène seulement à la fiche
   (`pet_detail_screen.dart` ne transmet pas le numéro d'onglet).

---

## 6. Lancer et tester

```powershell
cd backend; npm install; npm start          # http://localhost:3000, l'émulateur l'atteint par 10.0.2.2:3000
flutter emulators --launch Medium_Phone_API_37.0
flutter run -d emulator-5554
```

Préparer deux animaux actifs (par exemple Milo et Nala) et un animal archivé.

### Barre du bas
- [ ] 5 onglets dans l'ordre, Santé en 3e ; « Health » en anglais.
- [ ] Depuis l'Agenda ou les Fiches santé, toucher Communauté ou Services ouvre le bon onglet.

### Onglet Santé
- [ ] Déconnecté : invitation à se connecter. Sans animal : bouton « Ajouter un animal ».
- [ ] Cartes complètes, ordre par action à faire, archivés repliés en bas.
- [ ] Toucher une carte ouvre le carnet ; un ajout dans le carnet se voit aussitôt au retour.
- [ ] Backend arrêté : l'onglet fonctionne encore.

### Tableau du jour
- [ ] Prises de tous les animaux actifs ; confirmation puis « Faite » ; « À venir » au-delà de 3 h ; pas de décoche.
- [ ] Vaccins en retard (rouge) et à venir (ambre) ; toucher une ligne ouvre le carnet.

### Carnet d'un animal actif
- [ ] Visite avec prochain contrôle : la date apparaît dans le carnet.
- [ ] ⤓ enregistre le PDF ; l'ouvrir : profil, tableaux, accents, aucune adresse ni numéro. Partage : feuille Android.

### Animal archivé
- [ ] Carnet et traitements avec bandeau, sans bouton d'ajout, de prise ni d'arrêt ; le PDF fonctionne.

### Traitements
- [ ] « Noter la prise » met à jour le compteur de l'onglet Santé ; arrêter avec une raison le classe dans « Arrêtés ».

### Scan
- [ ] Vignette dans « Ajouter un soin » : type Vaccin, champs remplis, bandeau ; rien n'est enregistré avant
  « Enregistrer le soin ».
- [ ] Ordonnance dans « Nouveau traitement » : nom, date de début, vétérinaire remplis ; **posologie vide**.
- [ ] Médicament scanné depuis « Ajouter un soin » (et vaccin depuis « Nouveau traitement ») : conseil affiché.
- [ ] Photo floue : « Aucune information utilisable ».

### Erreurs
- [ ] La même prise cochée deux fois : « Cette prise est déjà notée ».
- [ ] Après déploiement des règles, backend arrêté : écrire dans le carnet d'un animal archivé est refusé.
