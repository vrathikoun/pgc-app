import 'package:pgc_app/models/course.dart';

class Booking {
  final int id;
  final int memberId;
  final int courseId;
  final String status;
  final String? notes;
  final DateTime bookedAt;
  final DateTime? cancelledAt;
  final Course? course;
  final int? waitlistPosition;

  Booking({
    required this.id,
    required this.memberId,
    required this.courseId,
    required this.status,
    this.notes,
    required this.bookedAt,
    this.cancelledAt,
    this.course,
    this.waitlistPosition,
  });

  factory Booking.fromJson(Map<String, dynamic> json) => Booking(
        id: json['id'],
        memberId: json['member_id'],
        courseId: json['course_id'],
        status: json['status'],
        notes: json['notes'],
        bookedAt: DateTime.parse(json['booked_at']).toLocal(),
        cancelledAt: json['cancelled_at'] != null
            ? DateTime.parse(json['cancelled_at']).toLocal()
            : null,
        course: json['course'] != null ? Course.fromJson(json['course']) : null,
        waitlistPosition: json['waitlist_position'],
      );

  bool get isConfirmed => status == 'confirmed';
  bool get isWaitlist => status == 'waitlist';
  bool get isCancelled => status == 'cancelled';

  bool get canCancel {
    if (isCancelled) return false;
    if (course == null) return true;
    return !course!.hasStarted;
  }

  String get statusLabel {
    if (isWaitlist && waitlistPosition != null) {
      return '⏳ Liste d\'attente • n°$waitlistPosition';
    }
    const labels = {
      'confirmed': '✅ Confirmé',
      'waitlist': '⏳ Liste d\'attente',
      'cancelled': '❌ Annulé',
      'attended': '🏅 Présent',
    };
    return labels[status] ?? status;
  }
}
