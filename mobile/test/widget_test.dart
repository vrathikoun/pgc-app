// Test de fumée minimal : vérifie que la logique de fenêtre de réservation
// (semaine N + N+1, semaines démarrant le lundi) est correcte.
import 'package:flutter_test/flutter_test.dart';

import 'package:pgc_app/utils/booking_window.dart';

void main() {
  test('fenêtre de réservation = semaine en cours + semaine suivante', () {
    // Mercredi 15 juillet 2026 → lundi de la semaine = 13 juillet.
    final now = DateTime(2026, 7, 15, 18, 30);

    expect(BookingWindow.currentWeekStart(now), DateTime(2026, 7, 13));
    // Borne exclue : lundi 27 juillet (semaine N+2).
    expect(BookingWindow.bookingHorizonEnd(now), DateTime(2026, 7, 27));

    // Dimanche de la semaine N+1 à 23h59 : réservable.
    expect(BookingWindow.isWithinWindow(DateTime(2026, 7, 26, 23, 59), now), isTrue);
    // Lundi de la semaine N+2 à 00h00 : refusé.
    expect(BookingWindow.isWithinWindow(DateTime(2026, 7, 27), now), isFalse);
    // Aujourd'hui : réservable.
    expect(BookingWindow.isWithinWindow(DateTime(2026, 7, 15, 19), now), isTrue);
  });
}
