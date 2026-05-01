class Course {
  final int id;
  final String name;
  final String? description;
  final String courseType;
  final String level;
  final DateTime startTime;
  final DateTime endTime;
  final int maxCapacity;
  final int? coachId;
  final int? spotsAvailable;
  final DateTime createdAt;

  Course({
    required this.id,
    required this.name,
    this.description,
    required this.courseType,
    required this.level,
    required this.startTime,
    required this.endTime,
    required this.maxCapacity,
    this.coachId,
    this.spotsAvailable,
    required this.createdAt,
  });

  factory Course.fromJson(Map<String, dynamic> json) => Course(
        id: json['id'],
        name: json['name'],
        description: json['description'],
        courseType: json['course_type'],
        level: json['level'],
        startTime: DateTime.parse(json['start_time']).toLocal(),
        endTime: DateTime.parse(json['end_time']).toLocal(),
        maxCapacity: json['max_capacity'],
        coachId: json['coach_id'],
        spotsAvailable: json['spots_available'],
        createdAt: DateTime.parse(json['created_at']),
      );

  bool get isFull => spotsAvailable != null && spotsAvailable! == 0;

  String get courseTypeLabel {
    const labels = {
      'boxing': '🥊 Boxe',
      'mma': '🤼 MMA',
      'kickboxing': '🦵 Kickboxing',
      'muay_thai': '🇹🇭 Muay Thaï',
      'bjj': '🥋 BJJ',
      'wrestling': '🤸 Lutte',
      'other': '🏋️ Autre',
    };
    return labels[courseType] ?? courseType;
  }

  String get levelLabel {
    const labels = {
      'beginner': 'Débutant',
      'intermediate': 'Intermédiaire',
      'advanced': 'Avancé',
      'all_levels': 'Tous niveaux',
    };
    return labels[level] ?? level;
  }
}