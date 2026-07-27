# Fiche App Store / Play Store — PGC App

Textes prêts à coller dans App Store Connect et Google Play Console.

## Identité

| Champ | Valeur |
|---|---|
| Nom de l'app (App Store, 30 car. max) | `PGC — Polo Grappling Club` |
| Sous-titre (App Store, 30 car. max) | `Réserve tes cours de grappling` |
| Titre (Play Store, 30 car. max) | `PGC — Polo Grappling Club` |
| Description courte (Play Store, 80 car. max) | `L'app des membres du Polo Grappling Club : planning, réservations, rappels.` |
| Catégorie | Sport (secondaire : Forme et santé) |
| Classification d'âge | 4+ / Tous publics |
| URL politique de confidentialité | `https://pgc-app.onrender.com/privacy` |
| Email d'assistance | `vrathikoun@gmail.com` |

## Description longue (App Store + Play Store)

```
L'application officielle des membres du Polo Grappling Club.

PLANNING EN TEMPS RÉEL
Consulte les cours de la semaine en cours et de la semaine suivante :
grappling, MMA, lutte… avec le coach, le niveau et les places restantes.

RÉSERVATION EN 2 TAPS
Réserve ta place en quelques secondes. Cours complet ? Rejoins la liste
d'attente : si une place se libère, tu es inscrit automatiquement et prévenu
aussitôt.

RAPPELS AUTOMATIQUES
Reçois un rappel la veille de chaque cours, et sois averti immédiatement en
cas de changement d'horaire, de coach ou d'annulation.

TON PROFIL DE PRATIQUANT
Gère tes informations, ta photo et suis tes réservations passées et à venir.

ACADEMY
Accède aux vidéos techniques du club pour progresser entre les cours
(selon abonnement).

L'application est réservée aux membres du Polo Grappling Club.
```

## Mots-clés (App Store, 100 car. max)

```
grappling,jjb,mma,lutte,club,sport,combat,réservation,cours,planning,training
```

## Notes pour la review Apple (champ « Notes » dans App Store Connect)

```
Application de gestion d'un club de sport réel (Polo Grappling Club).
L'inscription est ouverte : créez un compte avec n'importe quel email pour
tester. Compte de démonstration si besoin :
  email : [CRÉER UN COMPTE DÉMO ET LE RENSEIGNER ICI]
  mot de passe : [MOT DE PASSE DÉMO]
Les abonnements des membres sont gérés physiquement au club (aucun achat
numérique dans l'app) — la mention d'un « plan » dans le profil est
informative.
```

⚠️ Avant soumission : créer un vrai compte démo en prod et remplir les
identifiants ci-dessus — Apple teste systématiquement les apps à login.

## Questionnaire « App Privacy » (App Store Connect) / « Data safety » (Play Console)

Données collectées, toutes **liées à l'identité de l'utilisateur**, aucune
utilisée pour le tracking ni la publicité :

| Donnée | Type ASC | Finalité |
|---|---|---|
| Email | Contact Info → Email Address | App Functionality (compte) |
| Nom, prénom | Contact Info → Name | App Functionality |
| Téléphone (facultatif) | Contact Info → Phone Number | App Functionality |
| Photo de profil (facultative) | User Content → Photos or Videos | App Functionality |
| Réservations / historique | User Content → Other User Content | App Functionality |
| Jeton de notification | Identifiers → Device ID | App Functionality (push) |

Réponses transverses : pas de données vendues, pas de partage à des tiers à
des fins pub, chiffrement en transit (HTTPS), suppression du compte sur
demande (email).

## Captures d'écran requises

- **App Store** : iPhone 6,9" (ex. simulateur iPhone 17 Pro Max) — 3 à 5 captures.
  iPad 13" requis aussi tant que l'app déclare le support iPad.
- **Play Store** : téléphone (min 2) + tablette 7"/10" si disponible, + bannière
  « feature graphic » 1024×500.
- Écrans conseillés : planning, détail d'un cours, mes réservations, profil, academy.
