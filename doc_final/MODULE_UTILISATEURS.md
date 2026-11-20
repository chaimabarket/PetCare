# Module Utilisateurs (comptes, profil, notifications, Accueil)

Ce document décrit le socle commun de PetCare : les comptes et les rôles, le profil, les notifications dans
l'application et l'écran d'Accueil. Il est à jour avec `main` (novembre 2026). Vue d'ensemble du projet :
[PROJET_PETCARE.md](PROJET_PETCARE.md).

---

## 1. Fonctionnalités

- **Inscription** par e-mail et mot de passe, avec le choix du rôle : **propriétaire**, **prestataire** ou **refuge**.
- **Connexion**, **mot de passe oublié** (e-mail de Firebase), **mode visiteur** (fil d'adoption, annuaire des
  services et assistant sans compte).
- **Profil** : nom, e-mail, ville, téléphone et rôle. Le nom, la ville et le téléphone se modifient ; le rôle et
  l'e-mail ne changent jamais.
- **Rôle administrateur** : jamais proposé à l'inscription, il est attribué à la main dans la console Firebase. Il
  valide les prestataires, gère les catégories de services, publie les fiches santé et lit les signalements.
- **Notifications dans l'application** : cloche de l'en-tête avec compteur de non lues, liste par catégorie
  (Santé & Soins, Rendez-vous, Adoptions, Communauté, Messages), « marquer comme lue » et « tout marquer comme lu ».
- **Accueil** : salutation, carte de l'assistant IA, mes animaux, 2 prochains rendez-vous, carte « Vaccins &
  traitements », rappels de soins, raccourcis Adoption et Perdus & trouvés ; carte d'inscription pour le visiteur.
- **Navigation** : barre du bas à 5 onglets (Accueil, Mes animaux, Santé, Communauté, Services) ; en-tête avec le
  choix de la langue, la cloche et le profil.
- **Langues** : français et anglais, choix mémorisé sur l'appareil.

## 2. Architecture et fichiers

```
lib/features/auth/            connexion, inscription, mot de passe oublié, validators.dart, user_role.dart
lib/features/profile/         ProfileRepository, UserProfile, écrans Mon profil et Modifier le profil
lib/features/notifications/   AppNotification, NotificationService, écran Notifications
lib/features/home/            HomeScreen (Accueil), MainShell (barre du bas)
lib/core/                     ApiClient, poll(), routes, thème, langue, onglets (main_tabs.dart)

backend/src/auth.js           vérification du jeton Firebase (requireAuth, optionalAuth)
backend/src/users/            routes.js, service.js, repository.js
backend/src/notifier.js       envoi de notifications par les autres modules du serveur
```

L'inscription se fait d'abord dans Firebase Authentication. L'application crée ensuite le profil par
`POST /api/users/me`, ou directement dans Firestore si le serveur est éteint. Le jeton Firebase de l'utilisateur est
envoyé dans chaque requête à l'API (`Authorization: Bearer <jeton>`).

## 3. Données (Cloud Firestore)

| Chemin | Contenu |
|---|---|
| `users/{uid}` | `fullName`, `email`, `city`, `phone`, `role` (`proprietaire`, `prestataire`, `refuge`, `admin`), `createdAt` |
| `users/{uid}/notifications/{id}` | `title`, `body`, `category` (`sante`, `rendezvous`, `adoption`, `communaute`, `message`), `read`, `createdAt` |

Règles (`firestore.rules`) :
- chacun ne lit et ne modifie que son propre profil ;
- le rôle choisi à la création ne peut pas être `admin`, et ni le rôle ni l'e-mail ne peuvent être modifiés ;
- n'importe quel membre connecté peut envoyer une notification à un autre (par exemple, un refuge qui accepte une
  candidature), mais elle arrive toujours non lue et avec uniquement les champs autorisés ;
- seul le destinataire la lit, la marque comme lue ou la supprime.

## 4. API REST

| Méthode | Route | Rôle |
|---|---|---|
| GET | `/api/health` | Le serveur répond |
| POST | `/api/users/me` | Crée le profil après l'inscription |
| GET / PUT | `/api/users/me` | Lit ou modifie son profil (ni le rôle ni l'e-mail) |
| GET | `/api/users/me/notifications?limit=50` | Notifications, les plus récentes d'abord |
| GET | `/api/users/me/notifications/unread-count` | Nombre de non lues |
| PATCH | `/api/users/me/notifications/{id}/read` | Marque une notification comme lue |
| POST | `/api/users/me/notifications/read-all` | Marque tout comme lu |

## 5. Décisions

| Décision | Raison |
|---|---|
| Firebase Authentication pour les comptes | Inscription, connexion et mot de passe oublié sûrs et prêts à l'emploi |
| Rôle fixé à l'inscription, admin attribué à la main | Personne ne peut se donner des droits d'administration |
| Notifications stockées dans Firestore | Pas de serveur de notifications push sur le plan gratuit ; la cloche suffit pour le projet |
| Tout membre peut notifier un autre membre | Les modules (adoption, services, alerte de poids) notifient sans passer par un serveur dédié |

## 6. Tests

- `backend/test/users.service.test.js`, `validation.test.js` : création et modification du profil, rôles refusés.
- `test/auth_validators_test.dart` : formulaires de connexion et d'inscription.
- `test/relative_time_test.dart`, `test/polling_test.dart`, `test/api_client_cache_test.dart` : dates relatives
  (« il y a 5 min »), interrogation régulière de l'API et regroupement des requêtes identiques.

## 7. Démonstration

Comptes du jeu de démonstration ([DONNEES_DEMO.md](DONNEES_DEMO.md)) : un compte par rôle. Se connecter avec
`sarra@petcare.test` pour voir l'Accueil rempli et les notifications non lues, puis avec `refuge@petcare.test` ou
`veto@petcare.test` pour voir les écrans propres à chaque rôle. Le mode visiteur se teste sans compte.
