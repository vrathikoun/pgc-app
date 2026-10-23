/// Ajoute [days] jours CALENDAIRES à [d], en gardant l'heure murale.
///
/// À ne pas remplacer par `d.add(Duration(days: n))` : une durée vaut
/// toujours 24 h, alors que les jours de changement d'heure en font 23 ou 25.
/// Le 25/10/2026 00:00 + 24 h donne le 25/10 à 23:00 — jour affiché en double.
DateTime addDays(DateTime d, int days) => DateTime(
    d.year, d.month, d.day + days, d.hour, d.minute, d.second, d.millisecond);

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
    return addDays(today, -(today.weekday - 1));
  }

  /// Borne haute EXCLUE : lundi 00:00 de la semaine N+2 (= fin de la semaine N+1).
  static DateTime bookingHorizonEnd([DateTime? now]) {
    return addDays(currentWeekStart(now), 14);
  }

  /// Un cours démarrant à [start] est-il dans la fenêtre réservable (≤ fin de N+1) ?
  static bool isWithinWindow(DateTime start, [DateTime? now]) {
    return start.isBefore(bookingHorizonEnd(now));
  }
}
