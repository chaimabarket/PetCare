# Données de démonstration

Ce document liste les comptes et les données de démonstration de la base `petcare-communit`, et propose un
scénario pour montrer chaque fonctionnalité. Les données sont créées par
[backend/scripts/seed-demo-complet.js](../backend/scripts/seed-demo-complet.js).

---

## 1. Comptes

Mot de passe commun : celui passé au script dans `DEMO_PASSWORD` (communiqué à l'équipe, jamais écrit dans le dépôt).

| Compte | Rôle | Pour montrer |
|---|---|---|
| `sarra@petcare.test` | Propriétaire, **compte principal** | Animaux, alerte de poids, santé, agenda, candidatures, favoris, réservations, notifications, assistant |
| `youssef@petcare.test` | Propriétaire (adoptant) | Candidature acceptée, adoption confirmée, Happy Tail, candidature sur l'annonce de Sarra |
| `refuge@petcare.test` | Refuge | Annonces dans tous les états, candidatures reçues classées par score, décisions |
| `veto@petcare.test` | Prestataire | Espace prestataire : profil, prestations, horaires, réservations reçues |
| `admin@petcare.test` | Administrateur | Validation des prestataires, catégories, signalements. Le rôle `admin` se met à la main dans la console Firebase (`users/{uid}.role`) |

L'annuaire des services contient aussi les 12 professionnels de l'équipe (`seed-services.js`, comptes
`*@petcare.test` avec leur propre mot de passe).

## 2. Contenu par module

| Module | Données |
|---|---|
| Animaux | **Rocky** (berger allemand : 2 photos, puce, 2 contacts, favori, **perte de 11 % → alerte de poids**), **Mimi** (persane, poids stable), **Coco** (perroquet), **Speedy** (tortue, espèce « Autre », date de naissance estimée), **Félix** (archivé) |
| Santé | Vaccins à venir et **en retard**, visites, examen, allergies, note ; traitement **en cours** avec des prises du jour, traitement terminé avec renouvellement, traitement **arrêté** avec sa raison ; carnet en lecture seule pour Félix |
| Rendez-vous | Confirmés (demain, dans 10 jours, dans 2 semaines), **reporté** (avec historique), **annulé**, **terminé** ; 4 rappels dont un fait |
| Adoption | Refuge : Oscar et Pirouette disponibles, Nina **réservée**, Tango **adopté**, Kiwi en **brouillon**. Candidatures envoyée, en étude, acceptée, adoptée et refusées (avec motif). Annonce Caramel de Sarra avec une candidature reçue. Happy Tail de Tango avec un « j'aime ». 2 favoris |
| Services | Profil du Cabinet Vétérinaire Dr Amine Gharbi (4 prestations, horaires lundi-samedi). Réservations de Sarra en attente et annulée. Une fois le profil publié par l'administrateur : réservations confirmée, refusée et en attente chez le Dr Amine, et un rendez-vous à confirmer |
| Notifications | Alerte de poids de Rocky, décisions d'adoption, nouvelles annonces, résultats d'analyse |

## 3. Scénario de démonstration (environ 15 minutes)

1. **Connexion** avec `sarra@petcare.test` : Accueil rempli (animaux, prochains rendez-vous, vaccins et traitements,
   rappels), cloche avec des notifications non lues.
2. **Mes animaux** → badge d'alerte sur Rocky → fiche : bandeau « consultez un vétérinaire », courbe de poids,
   sources (VCA). Montrer l'onglet Archivés (Félix) et Speedy (espèce libre).
3. **Santé** : tableau du jour (cocher la prise de l'Amoxicilline), vaccin en retard de Rocky, carnet, export PDF,
   traitements en cours, terminé et arrêté.
4. **Agenda** : vue semaine ou mois, rendez-vous reporté (historique), annulé, terminé ; ajouter à Google Agenda.
5. **Assistant** : choisir Rocky et demander « Rocky mange moins et a perdu du poids, que faire ? », puis faire
   préparer une pesée ou un rendez-vous et confirmer la carte.
6. **Communauté** : fil d'adoption et filtres, Mes candidatures (chaque statut), Happy Tail de Tango, favoris.
7. **Refuge** (`refuge@petcare.test`) : candidatures reçues triées par score ; accepter la candidature de Sarra pour
   Oscar (l'annonce passe Réservée, Sarra est notifiée).
8. **Services** : annuaire, fiche d'un prestataire, réserver un créneau. Avec `admin@petcare.test`, publier le Dr
   Amine ; avec `veto@petcare.test`, confirmer ou refuser une demande.

## 4. Recréer ou compléter les données

Le script se relance sans créer de doublons : il passe ce qui existe déjà.

```powershell
cd backend
npm start                      # dans un premier terminal
$env:DEMO_PASSWORD = "..."     # dans un second terminal
$env:PHOTOS_DIR = "C:\chemin\vers\photos"   # facultatif : rocky.jpg, mimi.jpg, oscar.jpg, nina.jpg, tango.jpg…
# avec un compte administrateur, pour publier le vétérinaire et créer ses réservations :
$env:ADMIN_EMAIL = "admin@petcare.test"; $env:ADMIN_PASSWORD = "..."
node scripts/seed-demo-complet.js
```

Sans `PHOTOS_DIR`, le script génère des images simples. Les photos utilisées pour la base de démonstration
viennent des services libres [Dog CEO](https://dog.ceo/dog-api/) (Stanford Dogs Dataset) et [Cataas](https://cataas.com).

Après la démonstration, **arrêter le serveur et fermer l'application** : l'application relit régulièrement les
données, et le quota gratuit de Firestore est partagé par toute l'équipe.

## 5. Limites

- Les dates sont relatives au jour où le script a été lancé (« demain », « dans 10 jours ») : relancer le script ne
  décale pas les rendez-vous déjà créés.
- Les décisions d'adoption sont écrites directement dans Firestore, comme le fait l'application.
- Un rendez-vous « terminé » doit d'abord être créé dans le futur : le script le crée 90 secondes plus tard, puis
  attend environ 6 minutes avant de le terminer.
