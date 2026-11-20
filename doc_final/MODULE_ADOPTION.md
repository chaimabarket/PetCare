# Module 5 : Adoption (onglet Communauté)

Ce document décrit le module Adoption tel qu'il est dans `main` (novembre 2026). Vue d'ensemble du projet :
[reflexion.md](reflexion.md).

---

## 1. Fonctionnalités

- **Fil d'adoption** (public, visible sans compte) avec recherche et filtres : espèce, âge, sexe, taille, ville,
  badges de personnalité, « Adopte-moi » (annonces urgentes).
- **Annonce** : jusqu'à 5 photos, badges (calme, joueur, affectueux, ok enfants…), compatibilités (enfants, chats,
  chiens, jardin), niveau d'énergie, temps seul accepté, besoins et conditions d'adoption. Brouillon, publication et
  archivage. Seuls les **propriétaires** et les **refuges** publient.
- **« Rédiger avec l'IA »** dans le formulaire d'annonce : l'assistant écrit la description à partir des champs
  remplis (voir [MODULE_ASSISTANT_IA.md](MODULE_ASSISTANT_IA.md)).
- **Favoris**.
- **Candidature en 4 étapes** : logement, foyer, mode de vie, récapitulatif. Une seule candidature par personne et
  par annonce.
- **Score de compatibilité** (sur 100) entre les besoins de l'animal et les réponses du candidat, avec le détail des
  points positifs et des points de vigilance. L'annonceur voit les candidatures reçues, du meilleur score au moins bon.
- **Suivi** : Envoyée → En étude → Acceptée → Adoptée, ou Refusée (avec un motif facultatif) ou Retirée par le
  candidat.
- **Happy Tails** : l'adoptant publie une histoire avant / après, que les membres peuvent aimer.
- **Signalements** d'une annonce ou d'une Happy Tail, lus par l'administrateur.
- Chaque décision envoie une notification au candidat concerné.

## 2. Règles métier

| Règle | Détail |
|---|---|
| Une candidature acceptée à la fois | Accepter passe l'annonce en **Réservée** ; une transaction empêche deux acceptations simultanées |
| Adoption | Seulement depuis « Réservée » ; l'annonce passe **Adoptée** avec l'adoptant, les autres candidats sont refusés et notifiés |
| Retrait | Le candidat accepté qui retire sa candidature rend l'animal **Disponible** |
| Archivage | Impossible si l'annonce est réservée ; les candidatures ouvertes sont refusées |
| Pas de suppression | Une annonce s'archive, une candidature se retire ou se refuse |
| Happy Tail | Publiée uniquement par l'adoptant de l'annonce |

### Score de compatibilité

On part de 100 et on retire des points pour chaque incompatibilité :

| Critère vérifié | Points retirés |
|---|---|
| L'animal a besoin d'un extérieur, le foyer n'en a pas | 20 |
| Enfants au foyer, animal non compatible avec les enfants | 25 |
| Chat au foyer, animal non compatible avec les chats | 20 |
| Chien au foyer, animal non compatible avec les chiens | 20 |
| Énergie de l'animal et rythme du foyer opposés | 15 |
| Absences plus longues que ce que l'animal supporte | 15 |
| Locataire sans accord du propriétaire | 30 |
| Allergies dans le foyer | 10 |
| Premier animal | 5 |

Le calcul est écrit à l'identique en JavaScript (`backend/src/adoption/compatibility.js`) et en Dart
(`lib/features/adoption/data/compatibility.dart`). C'est le serveur qui calcule le score enregistré : il ne dépend
donc pas du téléphone qui envoie la candidature.

## 3. Architecture et fichiers

```
lib/features/adoption/
  data/          adoption_repository.dart, adoption_listing.dart, adoption_application.dart, adoption_enums.dart,
                 adoption_filters.dart, compatibility.dart, happy_tail*.dart, photo_picker.dart
  presentation/  adoption_feed_screen.dart, listing_detail_screen.dart, listing_form_screen.dart,
                 application_form_screen.dart, application_review_screen.dart, received_applications_screen.dart,
                 my_applications_screen.dart, my_listings_screen.dart, favorites_screen.dart,
                 happy_tails_screen.dart, share_happy_tail_screen.dart, adoption_celebration_screen.dart, widgets/
lib/features/community/  onglet Communauté (Adoption, Happy Tails)

backend/src/adoption/    routes.js → service.js → repository.js, validation.js, enums.js, filters.js, compatibility.js
```

## 4. Données (Cloud Firestore)

| Chemin | Contenu |
|---|---|
| `adoptions/{id}` | Annonce ; `status` : `brouillon`, `disponible`, `reservee`, `adoptee`, `archivee` ; `publisherId`, `acceptedApplicationId`, `adopterId` |
| `adoptions/{id}/photos/{0-4}` | Photos compressées (base64) |
| `adoptionApplications/{annonce}_{uid}` | Candidature : réponses, score, détail, `status` (`envoyee`, `en_etude`, `acceptee`, `adoptee`, `refusee`, `retiree`), `refusalReason` |
| `happyTails/{annonce}` | Histoire de l'adoptant : titre, texte, photos avant / après, `likeCount` |
| `users/{uid}/adoptionFavorites`, `users/{uid}/likedHappyTails` | Favoris et « j'aime » |
| `reports/{id}` | Signalements, lisibles seulement par l'administrateur |

L'identifiant `{annonce}_{uid}` garantit, sans requête, une seule candidature par personne et par annonce. Les règles
Firestore vérifient chaque transition de statut, qui a le droit de la faire, et que le compteur de « j'aime » ne
bouge que de 1, en même temps que le « j'aime » de l'utilisateur.

## 5. API REST

| Méthode | Route | Rôle |
|---|---|---|
| GET | `/api/adoptions` | Fil public, avec filtres |
| GET | `/api/adoptions/{id}`, `/photos` | Détail et photos |
| GET | `/api/adoptions/mine` | Mes annonces |
| POST / PUT | `/api/adoptions[/{id}]` | Créer ou modifier une annonce (`publish: false` pour un brouillon) |
| POST | `/api/adoptions/{id}/archive` | Archiver |
| GET / PUT / DELETE | `/api/adoptions/favorites`, `/api/adoptions/{id}/favorite` | Favoris |
| POST | `/api/adoptions/{id}/applications` | Candidater (score calculé par le serveur) |
| GET | `/api/adoptions/{id}/applications/me`, `/api/applications/mine`, `/api/applications/received` | Ma candidature, mes candidatures, candidatures reçues |

Les décisions de l'annonceur (étude, acceptation, refus, adoption), le retrait, les Happy Tails et les signalements
sont écrits par l'application directement dans Firestore, dans des transactions et des lots atomiques contrôlés
par les règles de sécurité (statuts autorisés, auteur de la décision).

## 6. Décisions

| Décision | Raison |
|---|---|
| Score calculé par le serveur et par l'application, avec le même code | Score fiable (non modifiable par le téléphone) et affiché aussi hors ligne |
| Identifiant de candidature `{annonce}_{uid}` | Doublons impossibles, vérifiés par les règles |
| Transaction pour l'acceptation | Jamais deux candidats acceptés pour le même animal |
| Photos en base64 dans Firestore | Plan Spark sans Cloud Storage |
| Fil lisible sans compte | Un visiteur découvre les animaux avant de s'inscrire |
| Carnet de santé non transmis à l'adoption | Il appartient à l'ancien propriétaire (sous-collection de sa fiche) |

## 7. Tests

- `backend/test/adoption.test.js`, `adoption.service.test.js` : validation, filtres, score, règles du service.
- `test/adoption_compatibility_test.dart` : même score côté Flutter.
- `test/adoption_api_json_test.dart` : lecture des réponses de l'API.

## 8. Démonstration

Voir [DONNEES_DEMO.md](DONNEES_DEMO.md).
- `refuge@petcare.test` (Refuge Espoir Animal) : **Oscar** et **Pirouette** disponibles, **Nina** réservée,
  **Tango** adopté, **Kiwi** en brouillon. Candidatures reçues classées par score.
- `sarra@petcare.test` : une candidature dans chaque état (Oscar en étude, Nina envoyée, Pirouette refusée avec un
  motif, Tango refusée car adopté), 2 favoris, un « j'aime » sur la Happy Tail de Tango, et sa propre annonce
  **Caramel** qui a reçu la candidature de Youssef.
- `youssef@petcare.test` : candidature acceptée pour Nina, adoption de Tango confirmée, Happy Tail « Tango, le roi
  de la plage ».

Scénario en direct : avec `refuge@petcare.test`, ouvrir la candidature de Sarra pour Oscar et l'accepter. Oscar
passe en Réservé et Sarra reçoit la notification.
