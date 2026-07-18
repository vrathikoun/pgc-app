# 🔔 Notifications — guide de mise en route

Ce document explique **ce qui est déjà codé** et **les étapes manuelles** (comptes
externes) à réaliser pour activer les vraies push notifications.

## Ce qui est déjà fait (code)

**Backend**
- Stockage des tokens d'appareils : table `device_tokens` + endpoints
  `POST/DELETE /notifications/device-token`.
- Service d'envoi push FCM : `app/services/push_service.py`
  (dégradé gracieux : sans config Firebase, les push sont juste loguées).
- Orchestration push + email : `app/services/notification_service.py`.
- Déclencheurs automatiques sur les cours :
  - **modification** d'un cours (coach, horaire, nom, niveau, type) → `PUT /courses/{id}`
  - **annulation / suppression** d'un cours → `DELETE /courses/{id}`, `/series`, `/bulk-delete`
  - seuls les membres avec une réservation **active** (confirmée ou liste d'attente) sont notifiés.
- **Rappel 24h** : `POST /tasks/send-reminders` (protégé par `X-Cron-Secret`),
  à appeler toutes les heures par un cron.

**Mobile (Flutter)**
- Packages ajoutés : `firebase_core`, `firebase_messaging`, `flutter_local_notifications`.
- Service `lib/services/push_notification_service.dart` (init, permission, token,
  affichage premier plan) — tout en try/catch : sans config Firebase, l'app marche sans push.
- Enregistrement automatique du token au login / auto-login, suppression au logout
  (`lib/providers/auth_provider.dart`).

## Étapes manuelles à faire (toi)

### 1. Créer le projet Firebase
1. https://console.firebase.google.com → **Add project** → nomme-le `pgc-app`.
2. Active **Cloud Messaging** (Build → Cloud Messaging).

### 2. Configurer l'app Flutter (le plus simple : FlutterFire CLI)
```bash
dart pub global activate flutterfire_cli
cd mobile
flutterfire configure --project=<ton-project-id>
```
Cela génère `lib/firebase_options.dart` **et** ajoute automatiquement :
- `android/app/google-services.json`
- `ios/Runner/GoogleService-Info.plist`
- le plugin Gradle Google Services côté Android.

> Si tu utilises FlutterFire, remplace dans `push_notification_service.dart` :
> `await Firebase.initializeApp();`
> par `await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);`
> (et importe `firebase_options.dart`). Sinon, garde la version actuelle qui lit
> directement les fichiers natifs ci-dessus.

### 3. iOS — APNs (nécessite le compte Apple Developer payant, 99 €/an)
> ⚠️ Les push **ne fonctionnent PAS** avec un compte Apple gratuit. C'est la seule
> partie qui exige le compte payant.

1. Dans **Xcode** → cible Runner → **Signing & Capabilities** → **+ Capability** →
   ajoute **Push Notifications** (et, optionnel, **Background Modes → Remote notifications**).
   Cela crée le fichier `Runner.entitlements` avec `aps-environment` automatiquement.
2. Sur https://developer.apple.com → **Keys** → crée une **APNs Auth Key** (.p8).
3. Dans la **console Firebase** → Project Settings → Cloud Messaging → **Apple app
   configuration** → upload la clé `.p8` (+ Key ID + Team ID).

### 4. Backend — clé de service Firebase
1. Console Firebase → **Project Settings → Service accounts → Generate new private key**.
   Tu obtiens un fichier JSON.
2. Mets son contenu (sur **une seule ligne**) dans la variable d'environnement
   `FIREBASE_CREDENTIALS_JSON` (Render → Environment).

### 5. Cron du rappel 24h
Mets en place un appel **toutes les heures** sur :
```
POST https://pgc-app.onrender.com/tasks/send-reminders
Header: X-Cron-Secret: <valeur de CRON_SECRET>
```
Options :
- **Render Cron Job** (recommandé) : nouveau service de type *Cron Job*, schedule
  `0 * * * *`, commande `curl -X POST $URL/tasks/send-reminders -H "X-Cron-Secret: $CRON_SECRET"`.
- ou **cron-job.org** (gratuit), ou **GitHub Actions** (`schedule`).

> ⚠️ Sur le free tier Render, le service s'endort après inactivité : un cron qui
> tape l'URL le réveille, ce qui est exactement ce qu'on veut.

N'oublie pas de définir `CRON_SECRET` côté Render (même valeur que le cron).

## Tester sans rien payer
- **Android** : les push fonctionnent avec le compte Firebase gratuit (pas besoin
  d'Apple Developer). Tu peux donc tout valider sur Android d'abord.
- **Emails** : déjà fonctionnels — en `DEBUG=True` ils sont logués, en prod ils
  partent via SMTP. Les emails couvrent déjà « changement » / « annulation » / « rappel »
  même sans push.
- L'endpoint rappel se teste à la main :
  `curl -X POST http://localhost:8000/tasks/send-reminders -H "X-Cron-Secret: <secret>"`.
