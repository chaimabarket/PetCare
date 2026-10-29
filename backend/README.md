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

Erreurs : JSON `{"error": "message en français"}` avec le code HTTP `400` (champ invalide), `401` (jeton manquant
ou expiré), `403` (refusé par les règles), `404`, `409` (profil déjà créé).

Exemples :

```bash
curl -H "Authorization: Bearer $TOKEN" http://localhost:3000/api/users/me

curl -X PUT -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
  -d '{"fullName":"Lina Ben","city":"Tunis","phone":"+216 20 123 456"}' \
  http://localhost:3000/api/users/me
```

## Côté Flutter

`lib/core/api/api_client.dart` appelle ces routes ; `ProfileRepository`, `NotificationService` et
`AuthService.register` l'utilisent. Si le serveur est éteint, ils passent directement par Firestore
(même résultat, mêmes règles).

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
