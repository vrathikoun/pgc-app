# Guide de publication Google Play Store — PGC App

Tout ce qu'il faut pour soumettre l'app sur le Play Store. Les fichiers à
uploader sont dans **`~/Desktop/pgc-play-store/`** :

- `icone-512x512.png` — icône du Play Store
- `feature-graphic-1024x500.png` — image de couverture (obligatoire)
- `capture-telephone-*.png` (×4) — captures téléphone
- Le bundle à installer : `mobile/build/app/outputs/bundle/release/app-release.aab`

> ⚠️ Compte personnel récent : Google impose une phase de **closed testing avec
> au moins 12 testeurs pendant 14 jours** avant d'autoriser la production.
> Démarre-la au plus tôt.

---

## 1. Créer l'application (Play Console → Toutes les apps → Créer une application)

| Champ | Valeur |
|---|---|
| Nom de l'application | `PGC — Polo Grappling Club` |
| Langue par défaut | Français (France) |
| Type | Application |
| Gratuite ou payante | Gratuite |

Coche les déclarations (règles du programme + lois export US), puis **Créer**.

---

## 2. Fiche du Play Store (Développer sa présence → Fiche principale du Store)

**Nom de l'app** (30 car.) :
```
PGC — Polo Grappling Club
```

**Description courte** (80 car.) :
```
L'app des membres du Polo Grappling Club : planning, réservations, rappels.
```

**Description complète** (4000 car.) :
```
L'application officielle des membres du Polo Grappling Club.

PLANNING EN TEMPS RÉEL
Consulte les cours de la semaine en cours et de la semaine suivante :
grappling, lutte… avec le coach, le niveau et les places restantes.

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
Accède aux vidéos techniques du club pour progresser entre les cours.

L'application est réservée aux membres du Polo Grappling Club.
```

**Visuels** :
- Icône : `icone-512x512.png`
- Image de couverture : `feature-graphic-1024x500.png`
- Captures téléphone : les 4 `capture-telephone-*.png` (2 minimum)

---

## 3. Paramètres de la fiche

- **Catégorie d'application** : Sport
- **E-mail de contact** : vrathikoun@gmail.com
- **Politique de confidentialité** : `https://pgc-app.onrender.com/privacy`

---

## 4. Sécurité des données (Règles → Sécurité des données)

Déclare la collecte suivante (toutes les données sont **chiffrées en transit**,
l'utilisateur **peut demander leur suppression**, **aucune donnée n'est vendue
ou partagée** à des fins publicitaires) :

| Donnée | Catégorie Google | Finalité | Obligatoire ? |
|---|---|---|---|
| E-mail | Informations personnelles → Adresses e-mail | Fonctionnalité de l'app, Gestion du compte | Oui |
| Nom, prénom | Informations personnelles → Nom | Fonctionnalité de l'app | Oui |
| Téléphone | Informations personnelles → Numéro de téléphone | Fonctionnalité de l'app | Non |
| Photo de profil | Photos et vidéos → Photos | Fonctionnalité de l'app | Non |
| Réservations | Activité dans l'app → Autre | Fonctionnalité de l'app | Oui |

Réponses transverses :
- Collectez-vous ou partagez-vous des données ? **Oui (collecte), pas de partage**
- Données chiffrées en transit ? **Oui**
- L'utilisateur peut-il demander la suppression ? **Oui** (via e-mail de contact)

---

## 5. Classification du contenu (Règles → Classification du contenu)

Questionnaire, catégorie **Référence / Éducation / Autre** (pas un jeu).
Réponds **Non** à toutes les questions (violence, contenu sexuel, drogue,
grossièretés, jeux d'argent…) → classification **PEGI 3 / Tous publics**.

---

## 6. Public cible et contenu

- **Tranche d'âge cible** : 18 ans et plus (ou 16+) — évite le régime « enfants »
  et ses contraintes supplémentaires.
- **App destinée aux enfants ?** Non.

---

## 7. Test fermé (Tester → Test fermé)

1. Crée un circuit de **test fermé** (« Closed testing »).
2. **Testeurs** : ajoute une liste d'e-mails (≥ 12 comptes Google) — tes élèves,
   proches. Ils devront accepter l'invitation via le lien opt-in.
3. **Importer le bundle** : dépose `app-release.aab`.
4. Notes de version (français) :
   ```
   Première version : planning, réservation de cours, liste d'attente,
   rappels et profil membre.
   ```
5. **Enregistrer → Vérifier la version → Déployer**.
6. Partage le **lien d'opt-in** aux testeurs : ils installent via le Play Store.

> Le compteur des 14 jours démarre quand des testeurs sont actifs. Après 14
> jours + ≥ 12 testeurs, le bouton « Passer en production » se débloque.

---

## 8. Passage en production (après les 14 jours)

1. Production → Créer une version → réutilise le même bundle.
2. Renseigne la disponibilité par pays (France, ou monde entier).
3. Envoie pour examen (~1 à 3 jours).

---

## Rappels

- **Keystore de signature** : `~/pgc-keys/pgc-upload-keystore.jks` — à sauvegarder
  hors du Mac (perte = plus aucune mise à jour possible).
- **Play App Signing** : accepte quand Google le propose (Google gère la clé de
  signature finale, ton keystore ne sert que d'« upload key »).
- **Version** : 1.1.0 (versionCode 2).
