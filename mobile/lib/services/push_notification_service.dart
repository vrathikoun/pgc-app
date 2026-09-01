import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'package:pgc_app/firebase_options.dart';
import 'package:pgc_app/services/api_service.dart';

/// Handler des messages reçus quand l'app est en arrière-plan ou tuée.
/// Doit être une fonction top-level annotée @pragma.
@pragma('vm:entry-point')
Future<void> firebaseBackgroundHandler(RemoteMessage message) async {
  // Le système iOS/Android affiche déjà la notification.
  // On ne fait rien de spécial ici pour l'instant.
}

/// Gère tout le cycle de vie des push notifications.
///
/// Tout est encapsulé dans des try/catch : si Firebase n'est pas encore
/// configuré (pas de google-services.json / GoogleService-Info.plist) ou si
/// l'utilisateur refuse la permission, l'app continue de fonctionner sans push.
class PushNotificationService {
  static final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();
  static bool _localInitialized = false;
  static String? _lastToken;

  /// À appeler une seule fois au démarrage, avant runApp().
  static Future<void> initApp() async {
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      FirebaseMessaging.onBackgroundMessage(firebaseBackgroundHandler);
    } catch (e) {
      debugPrint('[PUSH] Firebase non initialisé (config manquante ?) : $e');
    }
  }

  /// À appeler après le login (token JWT disponible) : demande la permission,
  /// récupère le token FCM et l'enregistre côté serveur.
  static Future<void> registerForUser(ApiService api) async {
    try {
      final messaging = FirebaseMessaging.instance;

      await messaging.requestPermission(alert: true, badge: true, sound: true);
      await _ensureLocalInit();

      // Notifications reçues quand l'app est au premier plan.
      FirebaseMessaging.onMessage.listen(_showForeground);

      final token = await messaging.getToken();
      if (token != null) {
        _lastToken = token;
        await api.registerDeviceToken(token, _platform());
      }

      // Le token FCM peut changer : on le réenregistre à chaque rotation.
      messaging.onTokenRefresh.listen((newToken) async {
        _lastToken = newToken;
        try {
          await api.registerDeviceToken(newToken, _platform());
        } catch (_) {}
      });
    } catch (e) {
      debugPrint('[PUSH] Enregistrement impossible : $e');
    }
  }

  /// À appeler à la déconnexion : retire le token de ce compte.
  static Future<void> unregister(ApiService api) async {
    try {
      if (_lastToken != null) {
        await api.unregisterDeviceToken(_lastToken!);
      }
      await FirebaseMessaging.instance.deleteToken();
    } catch (_) {}
    _lastToken = null;
  }

  static Future<void> _ensureLocalInit() async {
    if (_localInitialized) return;
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings();
    await _local.initialize(
      const InitializationSettings(android: android, iOS: ios),
    );
    _localInitialized = true;
  }

  static void _showForeground(RemoteMessage message) {
    final notification = message.notification;
    if (notification == null) return;

    _local.show(
      notification.hashCode,
      notification.title,
      notification.body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'pgc_default',
          'Notifications PGC',
          channelDescription: 'Rappels et changements de cours',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
    );
  }

  static String _platform() {
    if (kIsWeb) return 'web';
    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
        return 'ios';
      case TargetPlatform.android:
        return 'android';
      default:
        return 'other';
    }
  }
}
