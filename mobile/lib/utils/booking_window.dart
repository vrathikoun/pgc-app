/// Règle métier : un membre ne peut réserver que les cours de la semaine en
/// cours (N) et de la semaine suivante (N+1). Les semaines commencent le lundi.
///
/// Ces bornes sont calculées en heure locale (les dates des cours sont déjà
/// converties en local via `.toLocal()` dans le modèle Course). Le backend
/// applique la même règle côté serveur : cette logique n'est qu'un confort
/// d'interface, la vraie contrainte est vérifiée à la réservation.
class BookingWindow {
  /// Lundi 00:00 de la semaine en cours.
  static DateTime currentWeekStart([DateTime? now]) {
    final ref = now ?? DateTime.now();
    final today = DateTime(ref.year, ref.month, ref.day);
    // weekday : lundi = 1 … dimanche = 7
    return today.subtract(Duration(days: today.weekday - 1));
  }

  /// Borne haute EXCLUE : lundi 00:00 de la semaine N+2 (= fin de la semaine N+1).
  static DateTime bookingHorizonEnd([DateTime? now]) {
    return currentWeekStart(now).add(const Duration(days: 14));
  }

  /// Un cours démarrant à [start] est-il dans la fenêtre réservable (≤ fin de N+1) ?
  static bool isWithinWindow(DateTime start, [DateTime? now]) {
    return start.isBefore(bookingHorizonEnd(now));
  }
}
