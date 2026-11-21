# Module 3 : Rendez-vous et rappels

Ce document décrit le module Rendez-vous et rappels tel qu'il est dans `main` (novembre 2026). Vue d'ensemble du
projet : [reflexion.md](reflexion.md).

---

## 1. Fonctionnalités

- **Agenda** en vue semaine et mois, avec des filtres par animal et par statut, et l'ajout d'un rendez-vous à
  Google Agenda.
- **Détail d'un rendez-vous**, avec une vue client et une vue prestataire, et l'historique des changements.
- **Nouveau rendez-vous** : animal, intitulé, type (vaccin, vétérinaire, toilettage, soin, éducation, garde, autre),
  date, durée, lieu (domicile, extérieur, autre), adresse, notes, rappel avant le début.
- **Actions** : confirmer (prestataire), reporter (avec une raison), annuler, terminer, modifier le rappel.
- **Rappels de soins** créés à la main (médicament, soin, vétérinaire, traitement, hygiène, contrôle), à cocher
  « fait ».
- **Accueil** : les 2 prochains rendez-vous et la carte « Rappels de soins ».
- Liens avec les autres modules : un vaccin du carnet (module 2) peut créer un rappel ou ouvrir le formulaire de
  rendez-vous, et l'assistant IA peut préparer un rendez-vous ou un rappel.

## 2. Règles métier (cahier des charges, RG-12 à RG-21)

| Règle | Détail |
|---|---|
| Statut de départ | Un rendez-vous personnel démarre **confirmé** ; une réservation auprès d'un prestataire démarre **en attente** |
| Confirmation | Seul le prestataire confirme une réservation en attente, avant son début |
| Report et annulation | Seulement avant le début ; « Reporté » est une action de l'historique, pas un statut ; l'ancien horaire est conservé |
| Terminé | Seulement depuis « confirmé », après l'heure de fin |
| Définitif | Un rendez-vous terminé ou annulé ne change plus |
| Chevauchement | Un animal ne peut pas avoir deux rendez-vous actifs qui se chevauchent (`409`) |
| Version | Chaque modification envoie la version affichée ; si quelqu'un a changé le rendez-vous entre-temps, l'écriture est refusée (`409`) au lieu d'écraser son changement |
| Historique | Pas de suppression : un rendez-vous s'annule |

Ces règles sont écrites deux fois : `backend/src/appointments/rules.js` et `lib/features/appointments/data/appointment.dart`
(utilisé quand le serveur est éteint). Les tests des deux côtés utilisent les mêmes cas. Les règles Firestore
vérifient aussi les statuts, la version et qui a le droit de confirmer.

## 3. Architecture et fichiers

```
lib/features/appointments/
  data/          appointment.dart (modèle et règles), appointment_repository.dart, reminder*.dart, pet_option.dart
  presentation/  agenda_screen.dart, appointment_detail_screen.dart, appointment_form_screen.dart,
                 appointment_actions.dart, reminders_screen.dart, widgets/

backend/src/appointments/   routes.js → service.js → repository.js, rules.js, validation.js
```

## 4. Données (Cloud Firestore)

| Chemin | Contenu |
|---|---|
| `appointments/{id}` | `ownerId`, `petName` (+ `petId`, `petBreed`), `title`, `type`, `startsAt`, `endsAt`, `status` (`planned`, `confirmed`, `completed`, `cancelled`), `providerId` (null pour un rendez-vous personnel), `providerName`, `serviceId`, `price`, `place`, `location`, `notes`, `reminderMinutes`, `reminderDoneAt`, `cancelReason`, `version`, `changes` (historique) |
| `reminders/{id}` | `ownerId`, `petName`, `title`, `category`, `dueAt`, `description`, `done` |

Un rendez-vous est lisible par son client et, pour une réservation, par le prestataire. Les rappels ne sont visibles
que par leur propriétaire.

## 5. API REST

| Méthode | Route | Rôle |
|---|---|---|
| GET | `/api/appointments` | Mon agenda (et, pour un prestataire, les rendez-vous reçus) |
| GET | `/api/appointments/{id}` | Un rendez-vous |
| POST | `/api/appointments` | Créer (avec `providerId` : réservation en attente) |
| POST | `/api/appointments/{id}/confirm` | Le prestataire confirme |
| POST | `/api/appointments/{id}/reschedule` | Reporter (`startsAt`, `reason`) |
| POST | `/api/appointments/{id}/cancel` | Annuler |
| POST | `/api/appointments/{id}/complete` | Terminer |
| PUT | `/api/appointments/{id}/reminder`, `/reminder-done` | Rappel avant le début, rappel fait |
| GET / POST | `/api/reminders` | Mes rappels de soins / en créer un |
| PATCH / DELETE | `/api/reminders/{id}` | Fait ou non fait / supprimer |

## 6. Décisions

| Décision | Raison |
|---|---|
| « Reporté » est une action, pas un statut | Le rendez-vous reste actif ; l'historique garde l'ancien horaire et la raison |
| Version incrémentée à chaque modification | Deux personnes (client et prestataire) peuvent agir sur le même rendez-vous : pas d'écrasement silencieux |
| Règles en double (serveur et application), mêmes cas de test | L'application applique les mêmes règles quand le serveur est éteint |
| Annulation plutôt que suppression | L'historique est conservé |

## 7. Tests

- `backend/test/appointments.test.js` : transitions, chevauchements, versions.
- `test/appointment_rules_test.dart` : mêmes règles côté Flutter.
- `test/reschedule_navigation_test.dart` : retour à l'agenda après un report.

## 8. Démonstration

Compte `sarra@petcare.test` ([DONNEES_DEMO.md](DONNEES_DEMO.md)) :
- **confirmés** : contrôle de Rocky demain, vaccin de Mimi dans 10 jours, séance d'éducation de Rocky dans 2 semaines ;
- **reporté** : toilettage de Mimi, avec la raison et l'ancien horaire dans l'historique ;
- **annulé** : coupe des griffes de Coco ;
- **terminé** : bain de Speedy (historique) ;
- **rappels** : vermifuge de Rocky, brossage de Mimi aujourd'hui, pesée de contrôle de Rocky, et un rappel déjà fait.

Compte `youssef@petcare.test` : réservation « Bilan de santé Tango » **en attente** chez le vétérinaire de
démonstration, que `veto@petcare.test` peut confirmer.
