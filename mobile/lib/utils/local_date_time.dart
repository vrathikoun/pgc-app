/// Helpers pour manipuler les horaires de cours comme des horaires "muraux"
/// du club (18:00 = 18:00 affiché), sans conversion automatique UTC/local.
///
/// Problème évité : si l'API renvoie `2026-05-02T18:00:00Z`, Dart peut
/// convertir en heure locale et afficher 20:00 en France. Pour un planning de
/// dojo, on veut conserver l'heure choisie par l'admin.
class LocalDateTime {
  static String two(int value) => value.toString().padLeft(2, '0');
  static String three(int value) => value.toString().padLeft(3, '0');

  /// Envoie une date sans suffixe timezone (`Z`, `+02:00`, etc.).
  /// Exemple : `2026-05-02T18:00:00.000`
  static String toApiString(DateTime value) {
    return '${value.year.toString().padLeft(4, '0')}-'
        '${two(value.month)}-'
        '${two(value.day)}T'
        '${two(value.hour)}:'
        '${two(value.minute)}:'
        '${two(value.second)}.'
        '${three(value.millisecond)}';
  }

  /// Parse une date API comme heure locale de planning, sans conversion.
  /// Supprime `Z` ou offset si présent, puis crée un DateTime local avec les
  /// mêmes composants année/mois/jour/heure/minute.
  static DateTime parseApiString(String raw) {
    var clean = raw.trim();

    if (clean.endsWith('Z')) {
      clean = clean.substring(0, clean.length - 1);
    }

    // Supprime un offset timezone en fin de string, ex: +00:00 ou -05:00.
    final offsetMatch = RegExp(r'([+-]\d{2}:\d{2})$').firstMatch(clean);
    if (offsetMatch != null) {
      clean = clean.substring(0, offsetMatch.start);
    }

    // Fallback robuste si jamais l'API renvoie autre chose.
    final parsed = DateTime.tryParse(clean);
    if (parsed != null) return parsed;

    return DateTime.parse(raw).toLocal();
  }

  static String hm(DateTime value) => '${two(value.hour)}:${two(value.minute)}';
}
