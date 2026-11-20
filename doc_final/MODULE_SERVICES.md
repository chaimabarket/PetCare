# Module 6 : Services (onglet Services)

Ce document décrit le module Services tel qu'il est dans `main` (novembre 2026). Vue d'ensemble du projet :
[reflexion.md](reflexion.md).

---

## 1. Fonctionnalités

**Côté client (propriétaire, ou visiteur pour l'annuaire)**
- **Annuaire** des professionnels publiés, avec recherche, filtre par catégorie (Vétérinaires, Toiletteurs,
  Promeneurs, Pensions, Boutiques, Éducateurs canins, Autres) et par ville.
- **Fiche d'un prestataire** : description, adresse, téléphone, prestations (durée, prix) et horaires de la semaine.
- **Réservation** : choix de la prestation, de l'animal, du jour et d'une heure de début (09:00, 10:30, 12:00, 14:00,
  15:30 ou 17:00), proposée seulement si la prestation tient dans les horaires du jour. Notes facultatives.
- **Mes réservations** : en attente, confirmée, refusée ou annulée ; le client peut annuler une demande en attente.
- L'assistant IA peut préparer une réservation à partir des prestations publiées (voir
  [MODULE_ASSISTANT_IA.md](MODULE_ASSISTANT_IA.md)).

**Côté prestataire** (espace en 4 onglets)
- **Profil** : nom, catégorie, ville, adresse, téléphone, e-mail, description, et l'état de la validation (en
  attente, publié, refusé).
- **Prestations** : nom, durée (de 5 minutes à 24 heures ; une pension se compte à la nuit), prix, description,
  publiée ou archivée.
- **Disponibilités** : pour chaque jour de la semaine, ouvert ou fermé et plusieurs plages horaires.
- **Réservations reçues** : confirmer ou refuser une demande en attente.

**Côté administrateur**
- **Validation des prestataires** : publier ou refuser un profil. Un profil refusé puis corrigé repart en validation.
- **Catégories** de l'annuaire : ajout, modification, ordre.

## 2. Règles métier

| Règle | Détail |
|---|---|
| Publication | Un profil n'apparaît dans l'annuaire qu'après validation par un administrateur |
| Propriété | Un profil appartient au compte qui l'a créé (`serviceProviders/{uid}`) |
| Réservation | Seulement pour un prestataire et une prestation publiés, à une date future ; un prestataire ne crée pas de réservation |
| Décision | Seule une demande **en attente** change : le prestataire la confirme ou la refuse, le client l'annule |
| Historique | Pas de suppression d'une réservation |

## 3. Architecture et fichiers

```
lib/features/services/
  data/          service_models.dart (modèles, heures de réservation, availabilityAllows), service_repository.dart
  presentation/  service_directory_screen.dart (annuaire), service_detail_screen.dart (fiche et réservation),
                 provider_screens.dart (espace prestataire et validation par l'administrateur)

backend/src/services/   routes.js → service.js → repository.js, validation.js, categories.js
backend/scripts/seed-services.js   annuaire de démonstration (12 professionnels)
```

## 4. Données (Cloud Firestore)

| Chemin | Contenu |
|---|---|
| `serviceCategories/{id}` | `name`, `icon`, `order` ; gérées par l'administrateur |
| `serviceProviders/{uid}` | `name`, `category`, `city`, `address`, `phone`, `email`, `description`, `photoUrl`, `status` (`pending`, `published`, `rejected`) |
| `serviceProviders/{uid}/services/{id}` | `name`, `category`, `durationMinutes`, `price`, `status` (`published`, `archived`), `description` |
| `serviceProviders/{uid}/availability/{1-7}` | `enabled`, `ranges` (`start`, `end` au format HH:MM) ; 1 = lundi |
| `serviceBookings/{id}` | `clientUid`, `clientName`, `providerUid`, `providerName`, `serviceId`, `serviceName`, `animalName`, `dateTime`, `notes`, `status` (`pending`, `confirmed`, `declined`, `cancelled`) |

Une réservation n'est lisible que par le client, le prestataire et l'administrateur. Les règles vérifient à la
création que le prestataire et la prestation sont publiés.

## 5. API REST

| Méthode | Route | Rôle |
|---|---|---|
| GET | `/api/services/categories` | Catégories (POST / PUT par l'administrateur) |
| GET | `/api/services/providers` | Annuaire (filtres `category`, `city`, `q`) |
| GET | `/api/services/providers/pending` | Profils en attente (administrateur) |
| PUT | `/api/services/providers/me` | Créer ou modifier mon profil |
| PUT | `/api/services/providers/{id}/status` | Publier, refuser ou remettre en attente (administrateur) |
| GET | `/api/services/providers/{id}`, `/services`, `/availability` | Fiche, prestations, horaires |
| GET / POST / PUT | `/api/services/providers/me/services[/{id}]` | Mes prestations |
| PUT | `/api/services/providers/me/availability/{jour}` | Mes horaires |
| GET | `/api/services/bookings?as=client\|provider` | Mes réservations, ou celles que j'ai reçues |
| POST | `/api/services/bookings` | Demander une réservation |
| PATCH | `/api/services/bookings/{id}/status` | Confirmer, refuser ou annuler |

## 6. Décisions

| Décision | Raison |
|---|---|
| Validation par un administrateur | L'annuaire ne montre que des professionnels vérifiés |
| Profil identifié par l'uid du compte | Un compte = un profil, sans requête de recherche |
| Heures de début fixes, vérifiées avec les horaires | Interface simple ; même contrôle dans le formulaire et dans l'assistant IA |
| Pension comptée à la nuit (1 440 min) | Une seule notion de durée pour toutes les prestations |

## 7. Tests

- `backend/test/services.test.js`, `services.service.test.js` : routes, validation, règles du service.
- `test/services_api_json_test.dart` : lecture des réponses de l'API.
- `test/assistant_services_test.dart` : catalogue des prestations et créneaux proposés par l'assistant.

## 8. Démonstration

Voir [DONNEES_DEMO.md](DONNEES_DEMO.md).
- **Annuaire** : 10 professionnels publiés et 2 en attente (comptes de l'équipe, `seed-services.js`).
- `sarra@petcare.test` : réservations **en attente** au Salon Pattes Propres (Mimi) et à la Pension Les Câlins
  (Rocky), et une réservation **annulée**.
- `veto@petcare.test` (Cabinet Vétérinaire Dr Amine Gharbi, publié) : 4 prestations, horaires du lundi au samedi,
  réservations reçues confirmée, refusée et 3 en attente (Sarra et Youssef).
- Scénario en direct : réserver une consultation avec Sarra, puis la confirmer avec `veto@petcare.test`. Avec le
  compte administrateur, montrer l'écran de validation (2 profils de l'équipe en attente).
