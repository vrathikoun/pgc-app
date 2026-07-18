# 📱 Tester l'app sur un iPhone physique (sans compte développeur payant)

Un compte Apple **gratuit** suffit pour installer l'app sur votre propre iPhone
(signature "Personal Team"). Limitations du compte gratuit :

- l'app expire au bout de **7 jours** (il suffit de relancer `flutter run` pour la réinstaller) ;
- les **push notifications ne fonctionnent pas** (APNs exige un compte payant) —
  l'app gère ce cas proprement, tout le reste fonctionne.

L'app pointe déjà sur l'API de production (`https://pgc-app.onrender.com`,
voir `lib/config/api_config.dart`) : aucune config réseau n'est nécessaire.
⚠️ Sur le tier gratuit Render, la première requête peut prendre 30–60 s (réveil du service).

## Prérequis (une seule fois)

1. **Ajouter votre Apple ID dans Xcode**
   Xcode → *Settings…* → *Accounts* → `+` → *Apple Account* → connectez-vous
   avec votre Apple ID personnel. Un "Personal Team" apparaît.

2. **Sélectionner l'équipe de signature**
   ```bash
   open ios/Runner.xcworkspace
   ```
   Dans Xcode : cible **Runner** → onglet *Signing & Capabilities* →
   cochez *Automatically manage signing* (déjà le cas) → *Team* = votre Personal Team.

   > Si Xcode se plaint que le bundle ID `com.pgcapp.pgcApp` n'est pas disponible,
   > changez-le en quelque chose d'unique, ex. `com.pgcapp.pgcApp.vosinitiales`.

3. **Préparer l'iPhone**
   - Branchez-le en USB → répondez **"Se fier à cet ordinateur"**.
   - Activez le **mode développeur** : Réglages → Confidentialité et sécurité →
     Mode développeur → activer → redémarrage de l'iPhone.

## Lancer l'app

```bash
cd mobile
flutter pub get
flutter devices          # l'iPhone doit apparaître
flutter run -d <id_iphone>
```

Au **premier lancement**, iOS bloque l'app ("Développeur non fiable") :
Réglages → Général → VPN et gestion de l'appareil → votre Apple ID → **Faire confiance**.
Relancez l'app, c'est bon.

## Dépannage

| Problème | Solution |
|---|---|
| `No profiles for 'com.pgcapp.pgcApp' were found` | Étape 2 non faite (Team non sélectionnée dans Xcode) |
| L'iPhone n'apparaît pas dans `flutter devices` | Câble/confiance USB, mode développeur, ou déverrouillez l'écran |
| "Développeur d'entreprise non fiable" au lancement | Réglages → Général → VPN et gestion de l'appareil → Faire confiance |
| L'app ne se lance plus après ~7 jours | Normal avec un compte gratuit : relancez `flutter run` |
| Erreur Swift Package Manager au build | SPM est désactivé dans `pubspec.yaml` (`disable-swift-package-manager: true`) — lancez `flutter pub get` puis rebuild |
