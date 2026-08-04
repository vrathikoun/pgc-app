// Démonstration filmée du flux de suppression de compte (App Store 5.1.1(v)).
// Se connecte avec un compte jetable, va sur le profil, supprime le compte et
// confirme — pour enregistrer une vidéo à joindre aux notes de review.
// Lancer avec l'écran enregistré :
//   flutter drive --no-pub --driver=test_driver/integration_test.dart \
//     --target=integration_test/delete_account_demo_test.dart -d <simulateur>
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'package:pgc_app/main.dart';
import 'package:pgc_app/providers/auth_provider.dart';

Future<void> _pause([int s = 2]) async {}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('démo suppression de compte', (tester) async {
    await initializeDateFormatting('fr_FR', null);

    final auth = AuthProvider();
    final ok = await auth.login('demo.delete@pgcapp.fr', 'Pgc-Delete-2026!');
    expect(ok, isTrue, reason: 'login compte démo suppression échoué');

    await tester.pumpWidget(
      ChangeNotifierProvider<AuthProvider>.value(
        value: auth,
        child: const PgcApp(),
      ),
    );
    await tester.pump(const Duration(seconds: 4));
    await tester.pump(const Duration(seconds: 3));

    // Onglet Profil.
    await tester.tap(find.byIcon(Icons.person).first);
    await tester.pump(const Duration(seconds: 3));

    // Fait défiler jusqu'au bouton de suppression et le tape.
    final deleteBtn = find.text('Supprimer mon compte');
    await tester.scrollUntilVisible(deleteBtn, 300,
        scrollable: find.byType(Scrollable).first);
    await tester.pump(const Duration(seconds: 2));
    await tester.tap(deleteBtn);
    await tester.pump(const Duration(seconds: 3)); // dialogue de confirmation visible

    // Confirme la suppression définitive.
    await tester.tap(find.text('Supprimer définitivement'));
    await tester.pump(const Duration(seconds: 5)); // suppression + retour login
    await tester.pump(const Duration(seconds: 3));
  });
}
