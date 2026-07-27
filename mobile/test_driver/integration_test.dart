// Driver : écrit sur le disque les captures prises par le test d'intégration.
import 'dart:io';

import 'package:integration_test/integration_test_driver_extended.dart';

Future<void> main() async {
  final dir = Directory('build/screenshots');
  if (!dir.existsSync()) dir.createSync(recursive: true);

  await integrationDriver(
    onScreenshot: (String name, List<int> bytes, [Map<String, Object?>? args]) async {
      final file = File('build/screenshots/$name.png');
      file.writeAsBytesSync(bytes);
      return true;
    },
  );
}
