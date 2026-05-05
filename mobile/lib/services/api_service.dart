import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:pgc_app/config/api_config.dart';
import 'package:pgc_app/models/booking.dart';
import 'package:pgc_app/models/course.dart';
import 'package:pgc_app/models/member.dart';
import 'package:pgc_app/utils/local_date_time.dart';

class ApiException implements Exception {
  final String message;
  final int? statusCode;

  ApiException(this.message, {this.statusCode});

  @override
  String toString() => message;
}

class ApiService {
  final String? token;

  ApiService({this.token});

  String get baseUrl => ApiConfig.baseUrl;

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

  void _checkStatus(http.Response res) {
    if (res.statusCode >= 400) {
      dynamic body;
      try {
        body = jsonDecode(res.body);
      } catch (_) {}

      throw ApiException(
        body is Map && body['detail'] != null
            ? body['detail'].toString()
            : 'Erreur serveur',
        statusCode: res.statusCode,
      );
    }
  }

  Future<Map<String, dynamic>> login(String email, String password) async {
    final res = await http.post(
      Uri.parse(ApiConfig.login),
      headers: _headers,
      body: jsonEncode({'email': email, 'password': password}),
    );
    _checkStatus(res);
    return jsonDecode(res.body);
  }

  Future<Member> register({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    String? phone,
  }) async {
    final res = await http.post(
      Uri.parse(ApiConfig.register),
      headers: _headers,
      body: jsonEncode({
        'email': email,
        'password': password,
        'first_name': firstName,
        'last_name': lastName,
        if (phone != null) 'phone': phone,
      }),
    );
    _checkStatus(res);
    return Member.fromJson(jsonDecode(res.body));
  }

  Future<Member> getMe() async {
    final res = await http.get(Uri.parse(ApiConfig.me), headers: _headers);
    _checkStatus(res);
    return Member.fromJson(jsonDecode(res.body));
  }

  Future<Member> updateMe({
    String? firstName,
    String? lastName,
    String? phone,
    String? beltRank,
    int? weeklyBookingLimit,
  }) async {
    final res = await http.put(
      Uri.parse(ApiConfig.me),
      headers: _headers,
      body: jsonEncode({
        if (firstName != null) 'first_name': firstName,
        if (lastName != null) 'last_name': lastName,
        if (phone != null) 'phone': phone,
        if (beltRank != null) 'belt_rank': beltRank,
        if (weeklyBookingLimit != null) 'weekly_booking_limit': weeklyBookingLimit,
      }),
    );
    _checkStatus(res);
    return Member.fromJson(jsonDecode(res.body));
  }

  Future<Member> uploadMyAvatar(String base64Image) async {
    final res = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/members/me/avatar'),
      headers: _headers,
      body: jsonEncode({'image_b64': base64Image}),
    );
    _checkStatus(res);
    return Member.fromJson(jsonDecode(res.body));
  }

  Future<Member> uploadMemberAvatar(int memberId, String base64Image) async {
    final res = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/members/$memberId/avatar'),
      headers: _headers,
      body: jsonEncode({'image_b64': base64Image}),
    );
    _checkStatus(res);
    return Member.fromJson(jsonDecode(res.body));
  }

  Future<List<Member>> getCoaches() async {
    final res = await http.get(Uri.parse(ApiConfig.coaches), headers: _headers);
    _checkStatus(res);
    final List data = jsonDecode(res.body);
    return data.map((e) => Member.fromJson(e)).toList();
  }

  Future<Member> getCoach(int coachId) async {
    final res = await http.get(
      Uri.parse('${ApiConfig.coaches}/$coachId'),
      headers: _headers,
    );
    _checkStatus(res);
    return Member.fromJson(jsonDecode(res.body));
  }

  Future<List<Member>> getMembers({int skip = 0, int limit = 100}) async {
    final uri = Uri.parse(ApiConfig.members).replace(queryParameters: {
      'skip': '$skip',
      'limit': '$limit',
    });
    final res = await http.get(uri, headers: _headers);
    _checkStatus(res);
    final List data = jsonDecode(res.body);
    return data.map((e) => Member.fromJson(e)).toList();
  }

  Future<Member> updateMemberRole(int memberId, String role) async {
    final res = await http.patch(
      Uri.parse('${ApiConfig.members}/$memberId/role'),
      headers: _headers,
      body: jsonEncode({'role': role}),
    );
    _checkStatus(res);
    return Member.fromJson(jsonDecode(res.body));
  }

  Future<Member> updateMember(
    int memberId, {
    String? firstName,
    String? lastName,
    String? phone,
    String? beltRank,
    int? weeklyBookingLimit,
  }) async {
    final res = await http.put(
      Uri.parse('${ApiConfig.members}/$memberId'),
      headers: _headers,
      body: jsonEncode({
        if (firstName != null) 'first_name': firstName,
        if (lastName != null) 'last_name': lastName,
        if (phone != null) 'phone': phone,
        if (beltRank != null) 'belt_rank': beltRank,
        if (weeklyBookingLimit != null) 'weekly_booking_limit': weeklyBookingLimit,
      }),
    );
    _checkStatus(res);
    return Member.fromJson(jsonDecode(res.body));
  }

  Future<List<Course>> getCourses({
    DateTime? fromDate,
    DateTime? toDate,
    int? coachId,
  }) async {
    final params = <String, String>{};
    if (fromDate != null) params['from_date'] = LocalDateTime.toApiString(fromDate);
    if (toDate != null) params['to_date'] = LocalDateTime.toApiString(toDate);
    if (coachId != null) params['coach_id'] = '$coachId';

    final uri = Uri.parse(ApiConfig.courses).replace(queryParameters: params);
    final res = await http.get(uri, headers: _headers);
    _checkStatus(res);
    final List data = jsonDecode(res.body);
    return data.map((e) => Course.fromJson(e)).toList();
  }

  Future<Course> getCourse(int courseId) async {
    final res = await http.get(
      Uri.parse('${ApiConfig.courses}/$courseId'),
      headers: _headers,
    );
    _checkStatus(res);
    return Course.fromJson(jsonDecode(res.body));
  }

  Future<Course> createCourse({
    required String name,
    String? description,
    required String courseType,
    required String level,
    required DateTime startTime,
    required DateTime endTime,
    required int maxCapacity,
    int? coachId,
  }) async {
    final res = await http.post(
      Uri.parse(ApiConfig.courses),
      headers: _headers,
      body: jsonEncode({
        'name': name,
        'description': description,
        'course_type': courseType,
        'level': level,
        'start_time': LocalDateTime.toApiString(startTime),
        'end_time': LocalDateTime.toApiString(endTime),
        'max_capacity': maxCapacity,
        'coach_id': coachId,
      }),
    );
    _checkStatus(res);
    return Course.fromJson(jsonDecode(res.body));
  }

  Future<Course> updateCourse({
    required int courseId,
    String? name,
    String? description,
    String? courseType,
    String? level,
    DateTime? startTime,
    DateTime? endTime,
    int? maxCapacity,
    int? coachId,
  }) async {
    final res = await http.put(
      Uri.parse('${ApiConfig.courses}/$courseId'),
      headers: _headers,
      body: jsonEncode({
        if (name != null) 'name': name,
        if (description != null) 'description': description,
        if (courseType != null) 'course_type': courseType,
        if (level != null) 'level': level,
        if (startTime != null) 'start_time': LocalDateTime.toApiString(startTime),
        if (endTime != null) 'end_time': LocalDateTime.toApiString(endTime),
        if (maxCapacity != null) 'max_capacity': maxCapacity,
        if (coachId != null) 'coach_id': coachId,
      }),
    );
    _checkStatus(res);
    return Course.fromJson(jsonDecode(res.body));
  }

  Future<void> deleteCourse(int courseId) async {
    final res = await http.delete(
      Uri.parse('${ApiConfig.courses}/$courseId'),
      headers: _headers,
    );
    _checkStatus(res);
  }

  Future<List<Booking>> getMyBookings() async {
    final res = await http.get(Uri.parse(ApiConfig.myBookings), headers: _headers);
    _checkStatus(res);
    final List data = jsonDecode(res.body);
    return data.map((e) => Booking.fromJson(e)).toList();
  }

  Future<Booking> createBooking(int courseId) async {
    final res = await http.post(
      Uri.parse(ApiConfig.bookings),
      headers: _headers,
      body: jsonEncode({'course_id': courseId}),
    );
    _checkStatus(res);
    return Booking.fromJson(jsonDecode(res.body));
  }

  Future<Booking> cancelBooking(int bookingId) async {
    final res = await http.delete(
      Uri.parse('${ApiConfig.bookings}/$bookingId'),
      headers: _headers,
    );
    _checkStatus(res);
    return Booking.fromJson(res.body.isEmpty ? <String, dynamic>{} : jsonDecode(res.body));
  }

  Future<List<Booking>> getCourseBookings(int courseId) async {
    final res = await http.get(
      Uri.parse('${ApiConfig.bookings}/course/$courseId'),
      headers: _headers,
    );
    _checkStatus(res);
    final List data = jsonDecode(res.body);
    return data.map((e) => Booking.fromJson(e)).toList();
  }
}
