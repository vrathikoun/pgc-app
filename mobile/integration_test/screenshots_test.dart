// Génère les captures d'écran de l'App Store en pilotant la vraie app.
// Se connecte avec le compte démo (données de prod), parcourt les écrans clés
// et capture chacun. Lancer via :
//   flutter drive --driver=test_driver/integration_test.dart \
//     --target=integration_test/screenshots_test.dart -d <simulateur>
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'package:pgc_app/main.dart';
import 'package:pgc_app/providers/auth_provider.dart';

Future<void> _shoot(
  IntegrationTestWidgetsFlutterBinding binding,
  WidgetTester tester,
  String name,
) async {
  // pumpAndSettle est inutilisable ici : le spinner de chargement tourne en
  // continu et n'atteint jamais l'état "settled". On laisse le réseau répondre
  // avec des pauses fixes (prod Render peut mettre du temps à se réveiller).
  await tester.pump(const Duration(seconds: 6));
  await tester.pump(const Duration(seconds: 4));
  await binding.takeScreenshot(name);
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('captures App Store', (tester) async {
    await binding.convertFlutterSurfaceToImage();
    // Comme main() : sans ça, les DateFormat('fr_FR') jettent LocaleDataException.
    await initializeDateFormatting('fr_FR', null);

    final auth = AuthProvider();
    final ok = await auth.login('demo.review@pgcapp.fr', 'Pgc-Review-2026!');
    expect(ok, isTrue, reason: 'échec login compte démo');

    await tester.pumpWidget(
      ChangeNotifierProvider<AuthProvider>.value(
        value: auth,
        child: const PgcApp(),
      ),
    );

    // 1. Planning (écran d'accueil après login)
    await _shoot(binding, tester, '01-planning');

    // 2. Mes réservations (onglet bookmark).
    final bookings = find.byIcon(Icons.bookmark);
    if (bookings.evaluate().isNotEmpty) {
      await tester.tap(bookings.first);
      await _shoot(binding, tester, '02-reservations');
    }

    // 3. Profil (onglet person).
    final profile = find.byIcon(Icons.person);
    if (profile.evaluate().isNotEmpty) {
      await tester.tap(profile.first);
      await _shoot(binding, tester, '03-profil');
    }

    // 4. Détail d'un cours (en dernier : on revient d'abord sur Courses).
    final courses = find.byIcon(Icons.fitness_center);
    if (courses.evaluate().isNotEmpty) {
      await tester.tap(courses.first);
      await tester.pump(const Duration(seconds: 3));
    }
    final card = find.byIcon(Icons.chevron_right);
    if (card.evaluate().isNotEmpty) {
      await tester.tap(card.first);
      await _shoot(binding, tester, '04-detail-cours');
    }
  });
}
