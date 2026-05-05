import 'package:pgc_app/models/member.dart';

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
  final Member? coach;
  final String? coachFirstName;
  final String? coachLastName;
  final String? coachAvatarUrl;
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
    this.coach,
    this.coachFirstName,
    this.coachLastName,
    this.coachAvatarUrl,
    this.spotsAvailable,
    required this.createdAt,
  });

  factory Course.fromJson(Map<String, dynamic> json) {
    final nestedCoach = json['coach'] != null
        ? Member.fromJson(Map<String, dynamic>.from(json['coach']))
        : null;

    return Course(
      id: json['id'],
      name: json['name'],
      description: json['description'],
      courseType: json['course_type'],
      level: json['level'],
      startTime: DateTime.parse(json['start_time']).toLocal(),
      endTime: DateTime.parse(json['end_time']).toLocal(),
      maxCapacity: json['max_capacity'],
      coachId: json['coach_id'],
      coach: nestedCoach,
      coachFirstName: json['coach_first_name'] ?? nestedCoach?.firstName,
      coachLastName: json['coach_last_name'] ?? nestedCoach?.lastName,
      coachAvatarUrl: json['coach_avatar_url'] ?? nestedCoach?.avatarUrl,
      spotsAvailable: json['spots_available'],
      createdAt: DateTime.parse(json['created_at']).toLocal(),
    );
  }

  bool get isFull => spotsAvailable != null && spotsAvailable! == 0;
  bool get hasStarted => DateTime.now().isAfter(startTime);
  bool get isPast => DateTime.now().isAfter(endTime);

  String get coachFullName {
    if (coach != null) return coach!.fullName;
    final first = coachFirstName?.trim() ?? '';
    final last = coachLastName?.trim() ?? '';
    final full = '$first $last'.trim();
    return full.isEmpty ? 'Coach à assigner' : full;
  }

  String? get effectiveCoachAvatarUrl => coach?.avatarUrl ?? coachAvatarUrl;

  String get coachInitials {
    if (coach != null) return coach!.initials;
    final f = (coachFirstName?.isNotEmpty ?? false) ? coachFirstName![0] : '';
    final l = (coachLastName?.isNotEmpty ?? false) ? coachLastName![0] : '';
    final value = '$f$l'.trim();
    return value.isEmpty ? 'PGC' : value;
  }

  String get courseTypeLabel {
    const labels = {
      'grappling': 'NoGi Grappling',
      'bjj': 'BJJ',
      'mma': 'MMA',
      'wrestling': 'Wrestling',
      'boxing': 'Boxing',
      'kickboxing': 'Kickboxing',
      'muay_thai': 'Muay Thai',
      'other': 'Autre',
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
