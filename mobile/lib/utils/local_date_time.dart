class LocalDateTime {
  static String two(int n) => n.toString().padLeft(2, '0');

  static String three(int n) => n.toString().padLeft(3, '0');

  static String toApiString(DateTime value) {
    final local = value.toLocal();

    return '${local.year}-'
        '${two(local.month)}-'
        '${two(local.day)}T'
        '${two(local.hour)}:'
        '${two(local.minute)}:'
        '${two(local.second)}.'
        '${three(local.millisecond)}';
  }
}