// Lancer avec le fuseau du club : TZ=Europe/Paris flutter test test/booking_window_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:pgc_app/utils/booking_window.dart';

void main() {
  test('le jour du passage à l\'heure d\'hiver n\'apparaît qu\'une fois', () {
    final debut = DateTime(2026, 10, 23); // vendredi
    final jours = List.generate(5, (i) => addDays(debut, i));
    expect(jours.map((d) => d.day).toList(), [23, 24, 25, 26, 27]);
    expect(jours.every((d) => d.hour == 0), isTrue);
  });

  test('une série hebdomadaire garde son heure après le changement d\'heure', () {
    final cours = DateTime(2026, 10, 20, 20, 0); // mardi 20h
    expect(addDays(cours, 7), DateTime(2026, 10, 27, 20, 0));
    expect(addDays(DateTime(2027, 3, 23, 20), 7), DateTime(2027, 3, 30, 20, 0));
  });

  test('la fenêtre de réservation se termine bien un lundi minuit', () {
    final fin = BookingWindow.bookingHorizonEnd(DateTime(2026, 10, 23, 15));
    expect(fin, DateTime(2026, 11, 2));
  });
}
