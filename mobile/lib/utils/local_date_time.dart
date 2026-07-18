class LocalDateTime {
  static String two(int n) => n.toString().padLeft(2, '0');

  static String three(int n) => n.toString().padLeft(3, '0');

  /// Sérialise en ISO 8601 AVEC l'offset du fuseau local (ex : +02:00).
  /// Indispensable : sans offset, le backend (colonnes timestamptz) interprétait
  /// l'heure comme de l'UTC et tous les cours étaient décalés de 1–2 h.
  static String toApiString(DateTime value) {
    final local = value.toLocal();
    final offset = local.timeZoneOffset;
    final sign = offset.isNegative ? '-' : '+';
    final oh = two(offset.inHours.abs());
    final om = two(offset.inMinutes.abs() % 60);

    return '${local.year}-'
        '${two(local.month)}-'
        '${two(local.day)}T'
        '${two(local.hour)}:'
        '${two(local.minute)}:'
        '${two(local.second)}.'
        '${three(local.millisecond)}'
        '$sign$oh:$om';
  }
}