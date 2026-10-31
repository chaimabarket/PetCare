# API REST PetCare : module Utilisateurs

Serveur Node.js (Express) qui donne accès au profil et aux notifications de l'utilisateur connecté.
Il lit et écrit dans Firestore **avec le jeton de l'utilisateur** : les règles de `firestore.rules`
s'appliquent à chaque appel et le serveur ne détient aucune clé secrète.

## Lancer

```bash
cd backend
npm install
npm start
```

Le serveur écoute sur `http://localhost:3000` (variable `PORT` pour changer). Vérification :
`curl http://localhost:3000/api/health` renvoie `{"status":"ok"}`.

Tests : `npm test`.

## Connexion

La connexion et l'inscription restent faites par Firebase Authentication. L'application envoie ensuite
le jeton de l'utilisateur dans chaque requête : `Authorization: Bearer <idToken>`.

Obtenir un jeton pour tester avec `curl` :

```bash
curl -s "https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=<CLE_WEB_FIREBASE>" \
  -H "Content-Type: application/json" \
  -d '{"email":"vous@exemple.com","password":"...","returnSecureToken":true}'
```

La clé web est dans `lib/firebase_options.dart` (`apiKey` de `web`). Le champ `idToken` de la réponse est le jeton.

## Routes

| Méthode | Route | Rôle |
|---|---|---|
| GET | `/api/health` | Le serveur répond |
| POST | `/api/users/me` | Crée le profil après l'inscription : `fullName`, `city`, `role` (`proprietaire`, `prestataire`, `refuge`), `phone` facultatif |
| GET | `/api/users/me` | Lit son profil |
| PUT | `/api/users/me` | Modifie `fullName`, `city`, `phone` (le rôle et l'e-mail ne changent pas) |
| GET | `/api/users/me/notifications?limit=50` | Notifications, les plus récentes d'abord |
| GET | `/api/users/me/notifications/unread-count` | `{"count": 3}` |
| PATCH | `/api/users/me/notifications/{id}/read` | Marque une notification comme lue (204) |
| POST | `/api/users/me/notifications/read-all` | Marque tout comme lu |

### Module Adoption (étape 1)

Le fil et les fiches d'annonces sont publics : un visiteur sans jeton peut les lire. Le reste exige un jeton.

| Méthode | Route | Rôle |
|---|---|---|
| GET | `/api/adoptions` | Fil : annonces disponibles et réservées, récentes d'abord. Filtres facultatifs : `q`, `species=chat,chien`, `age=baby,young,adult,senior`, `sex`, `size`, `city`, `badges`, `urgent=1` |
| GET | `/api/adoptions/{id}` | Détail d'une annonce |
| GET | `/api/adoptions/{id}/photos` | `{"photos": ["<base64>", ...]}` dans l'ordre de l'annonce |
| GET | `/api/adoptions/mine` | Mes annonces (brouillons et archivées comprises) |
| POST | `/api/adoptions` | Crée une annonce ; `publish: false` pour un brouillon, `photos` : 5 images base64 de 350 Ko maximum |
| PUT | `/api/adoptions/{id}` | Modifie mon annonce (une annonce réservée ou adoptée garde son statut) |
| POST | `/api/adoptions/{id}/archive` | Archive l'annonce et refuse ses candidatures ouvertes (impossible si elle est réservée) |
| GET | `/api/adoptions/favorites` | `{"ids": [...]}` |
| PUT / DELETE | `/api/adoptions/{id}/favorite` | Ajoute ou retire un favori |
| POST | `/api/adoptions/{id}/applications` | Envoie une candidature ; le serveur calcule le score de compatibilité |
| GET | `/api/adoptions/{id}/applications/me` | Ma candidature pour cette annonce, ou `null` |
| GET | `/api/applications/mine` | Mes candidatures |
| GET | `/api/applications/received?listingId=` | Candidatures reçues, meilleur score d'abord |
| GET | `/api/applications/{id}` | Une candidature |

Les décisions de l'annonceur (en étude, accepter, refuser, retirer, confirmer l'adoption), les signalements et les
Happy Tails ne sont pas encore dans l'API (étape 2) : l'application les écrit directement dans Firestore.

### Module Rendez-vous et rappels

Toutes les routes exigent un jeton. Les dates sont des textes ISO 8601 (`2026-11-12T09:30:00.000Z`).

| Méthode | Route | Rôle |
|---|---|---|
| GET | `/api/appointments` | Mon agenda : les rendez-vous de mes animaux et, pour un prestataire, ceux qu'il a reçus, triés par date |
| GET | `/api/appointments/{id}` | Un rendez-vous |
| POST | `/api/appointments` | Crée un rendez-vous : `petName`, `title`, `type`, `startsAt`, `durationMinutes`, `place`, `location`, `notes`, `reminderMinutes`. Sans `providerId` il démarre « confirmé » ; avec `providerId`, `providerName` et `serviceId` c'est une réservation « en attente » (module Services). Refusé (409) si l'animal a déjà un rendez-vous actif sur ce créneau |
| POST | `/api/appointments/{id}/confirm` | Le prestataire confirme une réservation en attente |
| POST | `/api/appointments/{id}/reschedule` | Reporte avant le début : `startsAt` et `reason` obligatoires ; même durée, l'ancien horaire va dans l'historique |
| POST | `/api/appointments/{id}/cancel` | Annule avant le début : `reason` facultatif ; définitif |
| POST | `/api/appointments/{id}/complete` | Termine un rendez-vous confirmé, après son heure de fin |
| PUT | `/api/appointments/{id}/reminder` | `minutes` avant le début (0 = sans rappel) |
| PUT | `/api/appointments/{id}/reminder-done` | `done` : bouton « Fait » de la liste des rappels |
| GET | `/api/reminders` | Mes rappels de soins, par échéance |
| POST | `/api/reminders` | Crée un rappel : `petName`, `title`, `category`, `dueAt`, `description` et `detail` facultatifs |
| PATCH | `/api/reminders/{id}` | `{"done": true}` ou `false` |
| DELETE | `/api/reminders/{id}` | Supprime un rappel (204) |

Chaque action sur un rendez-vous envoie la `version` affichée par l'application. Si le rendez-vous a changé
entre-temps, l'API répond 409 au lieu d'écraser la modification de l'autre personne (RG-20). Une action
impossible dans l'état actuel (report après le début, rendez-vous déjà annulé…) répond aussi 409.

`AppointmentRepository` et `ReminderRepository` appellent ces routes, et passent directement par Firestore si le serveur
est éteint.

### Module Profils des animaux

Toutes les routes exigent un jeton ; chaque fiche est privée à son propriétaire. Un animal archivé se lit et se
restaure, mais toute autre modification renvoie `409`.

| Méthode | Route | Rôle |
|---|---|---|
| GET | `/api/pets` | Mes animaux, récents d'abord ; `?status=active` ou `archived` pour filtrer |
| POST | `/api/pets` | Crée la fiche : `name`, `species`, `sex`, `birthDate`, `breed`, `birthDateEstimated`, `chipNumber`, `sterilized`, `notes`, `photos` (`[{"data": "<base64>"}]`, 5 images de 750 Ko maximum), `weight` facultatif |
| GET | `/api/pets/{id}` | Lit une fiche |
| PUT | `/api/pets/{id}` | Modifie la fiche ; `photos` remplace la galerie dans l'ordre (`{"id": "..."}` garde une photo, `{"data": "..."}` en ajoute une) ; `weight` enregistre la pesée du jour |
| PATCH | `/api/pets/{id}` | Modifie seulement `notes`, `favorite` ou `contacts` (5 maximum) |
| POST | `/api/pets/{id}/archive` | Archive l'animal (jamais de suppression, 204) |
| POST | `/api/pets/{id}/restore` | Restaure l'animal (204) |
| GET | `/api/pets/{id}/photos` | `[{"id", "data", "sortOrder"}]`, la photo principale d'abord |
| GET | `/api/pets/{id}/cover` | Photo principale seule, ou `null` |
| POST | `/api/pets/{id}/photos` | Ajoute `{"data": "<base64>"}` en fin de galerie (`409` au-delà de 5) |
| DELETE | `/api/pets/{id}/photos/{photoId}` | Supprime une photo et recompacte l'ordre |
| POST | `/api/pets/{id}/photos/{photoId}/cover` | Choisit la photo principale |
| GET | `/api/pets/{id}/weights?limit=` | Pesées, la plus récente d'abord |
| POST | `/api/pets/{id}/weights` | Ajoute une pesée : `date` (AAAA-MM-JJ), `measuredOn` (minuit local en ISO), `weightKg`, `note` (`409` si ce jour a déjà une pesée) |
| PUT | `/api/pets/{id}/weights/{entryId}` | Corrige `weightKg` et `note` (la date ne change pas) |
| DELETE | `/api/pets/{id}/weights/{entryId}` | Supprime une pesée |

Pour une espèce `other`, `breed` est obligatoire et contient l'animal saisi librement (ours, tigre, tortue…).

Firestore garde les photos d'animaux en octets (`bytesValue`) ; l'API les échange en base64.

Le blocage des animaux archivés est appliqué par l'API : les écritures directes à Firestore (serveur éteint) ne
passent pas par ce contrôle, l'application masque alors simplement les actions.

### Module Services

Les annuaires sont publics ; le reste exige un jeton. Un prestataire est identifié par l'uid de son compte
(`serviceProviders/{uid}`). Un nouveau profil est « en attente » jusqu'à la validation d'un administrateur.

| Méthode | Route | Rôle |
|---|---|---|
| GET | `/api/services/providers` | Annuaire : prestataires publiés. Filtres : `category`, `city`, `q` |
| GET | `/api/services/providers/pending` | Profils en attente (administrateur) |
| PUT | `/api/services/providers/me` | Crée ou modifie mon profil ; un profil refusé qui est corrigé repart en validation |
| PUT | `/api/services/providers/{id}/status` | L'administrateur valide ou refuse : `published`, `rejected`, `pending` |
| GET | `/api/services/providers/{id}` | Un prestataire |
| GET | `/api/services/providers/{id}/services` | Ses prestations publiées (`?all=1` : toutes, pour son propriétaire) |
| GET | `/api/services/providers/{id}/availability` | `{"1": {"enabled": true, "ranges": [{"start": "09:00", "end": "12:00"}]}}` (1 = lundi … 7 = dimanche) |
| GET | `/api/services/providers/me/services` | Mes prestations, archivées comprises |
| POST / PUT | `/api/services/providers/me/services[/{id}]` | Crée ou modifie une prestation : `name`, `category`, `durationMinutes` (5-1440, une pension se compte à la nuit), `price`, `status` (`published`, `archived`), `description` |
| PUT | `/api/services/providers/me/availability/{jour}` | `enabled` et `ranges` au format HH:MM |
| GET | `/api/services/bookings?as=client\|provider` | Mes réservations, ou celles que j'ai reçues |
| POST | `/api/services/bookings` | Demande de réservation : `providerId`, `serviceId`, `animalName`, `dateTime` (à venir), `notes` |
| PATCH | `/api/services/bookings/{id}/status` | Le prestataire confirme ou refuse (`confirmed`, `declined`), le client annule (`cancelled`) ; seulement une demande en attente |

Les réservations de ce module sont dans `serviceBookings`. Elles ne créent pas encore de rendez-vous dans l'agenda du
module Rendez-vous (`appointments`).

Erreurs : JSON `{"error": "message en français"}` avec le code HTTP `400` (champ invalide), `401` (jeton manquant
ou expiré), `403` (refusé par les règles), `404`, `409` (état incompatible : profil déjà créé, animal archivé…).

Exemples :

```bash
curl -H "Authorization: Bearer $TOKEN" http://localhost:3000/api/users/me

curl -X PUT -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
  -d '{"fullName":"Lina Ben","city":"Tunis","phone":"+216 20 123 456"}' \
  http://localhost:3000/api/users/me
```

## Côté Flutter

`lib/core/api/api_client.dart` appelle ces routes ; `ProfileRepository`, `NotificationService`, `PetRepository`
et `AuthService.register` l'utilisent. Si le serveur est éteint, ils passent directement par Firestore
(même résultat, mêmes règles).

Le serveur n'autorise pas les appels d'un navigateur (pas de CORS) : l'API se teste sur l'émulateur ou un téléphone.
Dans Chrome, l'application passe par Firestore.

L'adresse par défaut est `http://10.0.2.2:3000` : c'est le PC vu depuis l'émulateur Android. Pour un
téléphone réel sur le même Wi-Fi :

```bash
flutter run --dart-define=API_URL=http://192.168.1.20:3000
```

(remplacez par l'adresse IP du PC). Le trafic `http` non chiffré n'est autorisé qu'en mode debug
(`android/app/src/debug/AndroidManifest.xml`) ; une version release utiliserait l'accès direct à Firestore,
ou une adresse `https` si le serveur est hébergé.

## Envoi de notifications

`NotificationService.send` écrit directement dans Firestore : les autres modules l'appellent avec le compte de
l'expéditeur pour un destinataire différent, ce que l'API « `/me` » ne couvre pas.
