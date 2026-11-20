# Module 2 : Santé et dossier médical

Ce document décrit le module Santé tel qu'il est dans `main` (novembre 2026) : fonctionnalités, architecture,
données, API et règles. Vue d'ensemble du projet : [PROJET_PETCARE.md](PROJET_PETCARE.md).

---

## 1. Fonctionnalités

- **Onglet Santé** (3e onglet) : une carte par animal actif (prochain vaccin à jour, bientôt dû ou en retard,
  traitements en cours, dernière visite, allergies). Les animaux qui demandent une action passent en premier ; les
  animaux archivés sont dans une section repliée, en lecture seule.
- **Tableau du jour** : les prises de médicaments de tous les animaux à cocher, et les vaccins en retard ou dus dans
  les 30 jours. Une prise notée ne s'annule pas.
- **Carnet de santé** d'un animal : visites, vaccins, examens, allergies (avec gravité) et notes, historique
  filtrable, prochain rappel vaccinal, jusqu'à 3 pièces jointes par soin (PDF ou photo, 900 Ko chacune).
- **Vaccins** : nom, numéro de lot et date du prochain rappel obligatoires ; « rappel déjà fait » ; création d'un
  rappel ou d'un rendez-vous (module 3) depuis le vaccin.
- **Traitements** : en cours, terminés ou arrêtés (avec une raison), heures de prise, prises notées, date de
  renouvellement, forme (comprimé, gouttes, injection, pipette, autre).
- **Fiches Santé & Conseils** : fiches publiques (recherche, catégories, marque-pages). 5 fiches de départ sont
  intégrées à l'application ; l'administrateur peut en publier d'autres.
- **Export PDF** du carnet (enregistrer ou partager) : profil, vaccins, visites, examens, allergies, traitements.
  Les e-mails et numéros de téléphone écrits dans le texte libre sont masqués.
- **Scan d'ordonnance ou de vignette** (Android et iOS) : le texte est lu sur le téléphone par Google ML Kit, puis
  le formulaire est pré-rempli (nom du vaccin ou du médicament, date, numéro de lot, vétérinaire). Jamais de
  posologie ni de diagnostic, et rien n'est enregistré sans vérification de l'utilisateur.
- **Accueil** : carte « Vaccins & traitements », lue dans la même synthèse que l'onglet Santé.

## 2. Architecture et fichiers

```
lib/features/health/
  data/
    health_repository.dart       API REST + repli Firestore
    health_entry.dart, treatment.dart, health_pet.dart, health_summary.dart   modèles
    health_pdf.dart              contenu et mise en page du PDF
    prescription_parser.dart     lecture du texte scanné (règles, sans IA générative)
    text_scanner*.dart           ML Kit sur mobile, version vide sur le web et l'ordinateur
    health_sheet*.dart           fiches santé et fiches de départ
  presentation/
    health_tab_screen.dart       onglet Santé
    health_record_screen.dart    carnet d'un animal
    medical_entry_form_screen.dart, treatment_form_screen.dart, treatments_screen.dart
    health_sheets_screen.dart, health_sheet_detail_screen.dart
    widgets/                     tableau du jour, carte Accueil, scan, pièces jointes

backend/src/health/              routes.js → service.js → repository.js, validation.js, enums.js
```

`GET /api/health/summary` renvoie en un seul appel tout ce dont l'onglet Santé, le tableau du jour et l'Accueil ont
besoin. Le serveur la garde 30 secondes par utilisateur et la vide à chaque écriture santé : beaucoup moins de
lectures Firestore qu'une lecture par animal.

## 3. Données (Cloud Firestore)

| Chemin | Contenu |
|---|---|
| `pets/{petId}/healthEntries/{id}` | `type` (`visite`, `vaccin`, `examen`, `allergie`, `note`), `title`, `date`, `description`, `practitioner`, `cost`, `vaccineName`, `batchNumber`, `nextReminderAt`, `reminderDone`, `weightKg`, `attachments` |
| `pets/{petId}/healthEntries/{id}/files/{0-2}` | Pièces jointes en octets (PDF ou image) |
| `pets/{petId}/treatments/{id}` | `category`, `name`, `subtitle`, `form`, `posology`, `startDate`, `endDate`, `doseTimes`, `doses`, `stoppedAt`, `stopReason`, `renewalAt` |
| `healthSheets/{id}` | Fiches publiques écrites par l'administrateur |
| `users/{uid}/healthBookmarks/{sheetId}` | Fiches enregistrées |

Règles principales (`firestore.rules`) :
- carnet et traitements lisibles seulement par le propriétaire de l'animal ;
- le carnet d'un animal **archivé** se lit mais ne se modifie plus (`petOwnerActive`) ;
- pas de soin daté dans le futur ; un vaccin a toujours un nom et une date de rappel postérieure au soin ;
- un soin enregistré ne change que par « rappel déjà fait » ;
- un traitement change seulement par l'ajout d'une prise (une à la fois) ou par son arrêt (une seule fois, avec une
  raison).

Le carnet est une sous-collection de la fiche de l'animal : il n'est pas transmis lors d'une adoption.

## 4. API REST

| Méthode | Route | Rôle |
|---|---|---|
| GET | `/api/health/summary` | Synthèse de tous mes animaux |
| GET / POST | `/api/pets/{petId}/health/entries` | Soins du carnet / ajouter un soin (avec pièces jointes) |
| GET / DELETE | `/api/pets/{petId}/health/entries/{id}` | Un soin / le supprimer |
| PATCH | `/api/pets/{petId}/health/entries/{id}/reminder-done` | Rappel vaccinal déjà fait |
| GET | `/api/pets/{petId}/health/entries/{id}/files/{index}` | Une pièce jointe |
| GET / POST | `/api/pets/{petId}/health/treatments` | Traitements / ajouter un traitement |
| POST | `/api/pets/{petId}/health/treatments/{id}/doses` | Noter une prise (pas dans le futur, pendant le traitement) |
| POST | `/api/pets/{petId}/health/treatments/{id}/stop` | Arrêter un traitement (raison obligatoire) |

Codes d'erreur : `400` champ invalide, `403` refusé par les règles, `404`, `409` animal archivé, prise déjà notée
ou traitement déjà arrêté.

## 5. Décisions

| Décision | Raison |
|---|---|
| Carnet en sous-collection de la fiche | Accès réservé au propriétaire ; carnet non transmis à l'adoptant |
| Synthèse en un seul appel, gardée 30 s | Moins de lectures Firestore (quota gratuit) et un onglet qui s'affiche vite |
| Pièces jointes en octets dans Firestore | Plan Spark sans Cloud Storage |
| Prises et arrêts non annulables | Historique médical fiable, contrôlé aussi par les règles |
| Scan par ML Kit sur le téléphone | Hors ligne, gratuit, sans quota ; aucune donnée médicale envoyée à un serveur |
| Pas de posologie lue par le scan | Une erreur de lecture sur une dose serait dangereuse : l'utilisateur la saisit lui-même |
| PDF sans coordonnées | Le carnet peut être partagé sans exposer de données personnelles |

## 6. Tests

- `backend/test/health.test.js`, `health.service.test.js` : routes et règles du service avec un faux dépôt.
- `test/health_rules_test.dart`, `health_summary_test.dart`, `health_today_test.dart` : statuts des vaccins, synthèse,
  tableau du jour.
- `test/health_pdf_test.dart` : contenu du PDF et masquage des coordonnées.
- `test/prescription_parser_test.dart`, `scan_prescription_test.dart` : lecture du texte scanné.

## 7. Démonstration

Compte `sarra@petcare.test` ([DONNEES_DEMO.md](DONNEES_DEMO.md)) :
- **Rocky** : vaccin Rage à refaire dans environ 5 semaines, vaccin CHPPiL **en retard**, visite pour perte
  d'appétit (contrôle dans 7 jours), prise de sang, allergie aux puces, note sur l'alimentation ; traitement
  **en cours** (Amoxicilline, matin et soir, 3 prises déjà notées : celles du jour sont dans le tableau du jour) et
  antiparasitaire terminé, avec un renouvellement prévu.
- **Mimi** : vaccin Typhus dû dans 10 jours, contrôle annuel, allergie au poulet ; collyre **terminé** et malt
  **arrêté** (avec sa raison).
- **Félix** (archivé) : carnet en lecture seule.
- Export PDF : depuis le carnet de Rocky. Le scan se montre avec une photo d'ordonnance sur un vrai téléphone ou
  sur l'émulateur.
