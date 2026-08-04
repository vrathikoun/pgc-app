import 'dart:convert';
import 'package:http/http.dart' as http;

import 'package:pgc_app/config/api_config.dart';
import 'package:pgc_app/models/academy_video.dart';
import 'package:pgc_app/models/booking.dart';
import 'package:pgc_app/models/course.dart';
import 'package:pgc_app/models/member.dart';

class ApiException implements Exception {
  final String message;
  final int? statusCode;

  ApiException(this.message, {this.statusCode});

  @override
  String toString() => message;
}

/// Timeout réseau global. Sans lui, un appel qui n'aboutit jamais (serveur
/// Render en cours de réveil, réseau mobile instable…) laissait l'UI avec un
/// spinner infini. 45 s couvre le réveil d'un service Render gratuit (~30-60 s).
const Duration kApiTimeout = Duration(seconds: 45);

ApiException _timeoutError() => ApiException(
    'Le serveur met trop de temps à répondre. Réessaie dans un instant.');

class _Http {
  static Future<http.Response> get(Uri url, {Map<String, String>? headers}) =>
      http.get(url, headers: headers).timeout(kApiTimeout, onTimeout: () => throw _timeoutError());

  static Future<http.Response> post(Uri url, {Map<String, String>? headers, Object? body}) =>
      http.post(url, headers: headers, body: body).timeout(kApiTimeout, onTimeout: () => throw _timeoutError());

  static Future<http.Response> put(Uri url, {Map<String, String>? headers, Object? body}) =>
      http.put(url, headers: headers, body: body).timeout(kApiTimeout, onTimeout: () => throw _timeoutError());

  static Future<http.Response> delete(Uri url, {Map<String, String>? headers, Object? body}) =>
      http.delete(url, headers: headers, body: body).timeout(kApiTimeout, onTimeout: () => throw _timeoutError());

  static Future<http.Response> patch(Uri url, {Map<String, String>? headers, Object? body}) =>
      http.patch(url, headers: headers, body: body).timeout(kApiTimeout, onTimeout: () => throw _timeoutError());
}

class ApiService {
  final String? token;

  ApiService({this.token});

  String get baseUrl => ApiConfig.baseUrl;

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

  String _joinUrl(String base, String path) {
    final b = base.endsWith('/') ? base.substring(0, base.length - 1) : base;
    final p = path.startsWith('/') ? path.substring(1) : path;
    return '$b/$p';
  }

  dynamic _parseBody(http.Response res) {
    if (res.body.isEmpty) return null;
    try {
      return jsonDecode(res.body);
    } catch (_) {
      return null;
    }
  }

  void _checkStatus(http.Response res) {
    if (res.statusCode >= 400) {
      final body = _parseBody(res);

      throw ApiException(
        body is Map && body['detail'] != null
            ? body['detail'].toString()
            : 'Erreur serveur (${res.statusCode})',
        statusCode: res.statusCode,
      );
    }
  }

  Future<Map<String, dynamic>> login(String email, String password) async {
    final res = await _Http.post(
      Uri.parse(ApiConfig.login),
      headers: _headers,
      body: jsonEncode({'email': email, 'password': password}),
    );

    _checkStatus(res);

    final data = _parseBody(res);
    if (data == null) {
      throw ApiException('Réponse serveur vide lors de la connexion');
    }

    return Map<String, dynamic>.from(data);
  }

  Future<Member> register({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    String? phone,
  }) async {
    final res = await _Http.post(
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

    final data = _parseBody(res);
    if (data == null) {
      throw ApiException('Réponse serveur vide lors de l’inscription');
    }

    return Member.fromJson(data);
  }

  Future<Member> getMe() async {
    final res = await _Http.get(
      Uri.parse(ApiConfig.me),
      headers: _headers,
    );

    _checkStatus(res);

    final data = _parseBody(res);
    if (data == null) {
      throw ApiException('Réponse serveur vide');
    }

    return Member.fromJson(data);
  }

  Future<Member> updateMe({
    String? firstName,
    String? lastName,
    String? phone,
    String? beltRank,
  }) async {
    final res = await _Http.put(
      Uri.parse(ApiConfig.me),
      headers: _headers,
      body: jsonEncode({
        if (firstName != null) 'first_name': firstName,
        if (lastName != null) 'last_name': lastName,
        if (phone != null) 'phone': phone,
        if (beltRank != null) 'belt_rank': beltRank,
      }),
    );

    _checkStatus(res);

    final data = _parseBody(res);
    if (data == null) {
      throw ApiException('Réponse serveur vide');
    }

    return Member.fromJson(data);
  }

  /// Suppression définitive du compte (exigence App Store 5.1.1(v)).
  Future<void> deleteMyAccount() async {
    final res = await _Http.delete(
      Uri.parse(ApiConfig.me),
      headers: _headers,
    );
    _checkStatus(res);
  }

  Future<Member> uploadMyAvatar(String base64Image) async {
    final res = await _Http.post(
      Uri.parse(_joinUrl(ApiConfig.baseUrl, 'members/me/avatar')),
      headers: _headers,
      body: jsonEncode({'image_b64': base64Image}),
    );

    _checkStatus(res);

    final data = _parseBody(res);
    if (data == null) {
      throw ApiException('Réponse serveur vide');
    }

    return Member.fromJson(data);
  }

  Future<Member> uploadMemberAvatar(int memberId, String base64Image) async {
    final res = await _Http.post(
      Uri.parse(_joinUrl(ApiConfig.baseUrl, 'members/$memberId/avatar')),
      headers: _headers,
      body: jsonEncode({'image_b64': base64Image}),
    );

    _checkStatus(res);

    final data = _parseBody(res);
    if (data == null) {
      throw ApiException('Réponse serveur vide');
    }

    return Member.fromJson(data);
  }

  Future<List<Member>> getCoaches() async {
    final res = await _Http.get(
      Uri.parse(ApiConfig.coaches),
      headers: _headers,
    );

    _checkStatus(res);

    final data = _parseBody(res);
    if (data is! List) return [];

    return data.map((e) => Member.fromJson(e)).toList();
  }

  Future<Member> getCoach(int coachId) async {
    final res = await _Http.get(
      Uri.parse(_joinUrl(ApiConfig.coaches, '$coachId')),
      headers: _headers,
    );

    _checkStatus(res);

    final data = _parseBody(res);
    if (data == null) {
      throw ApiException('Coach introuvable');
    }

    return Member.fromJson(data);
  }

  Future<List<Course>> getCoursesByCoach(int coachId) async {
    final res = await _Http.get(
      Uri.parse(_joinUrl(ApiConfig.courses, 'by-coach/$coachId')),
      headers: _headers,
    );

    _checkStatus(res);

    final data = _parseBody(res);
    if (data is! List) return [];

    return data.map((e) => Course.fromJson(e)).toList();
  }

  Future<List<Member>> getMembers({int skip = 0, int limit = 100}) async {
    final uri = Uri.parse(ApiConfig.members).replace(queryParameters: {
      'skip': '$skip',
      'limit': '$limit',
    });

    final res = await _Http.get(uri, headers: _headers);

    _checkStatus(res);

    final data = _parseBody(res);
    if (data is! List) return [];

    return data.map((e) => Member.fromJson(e)).toList();
  }

  Future<Member> updateMemberRole(int memberId, String role) async {
    final res = await _Http.patch(
      Uri.parse(_joinUrl(ApiConfig.members, '$memberId/role')),
      headers: _headers,
      body: jsonEncode({'role': role}),
    );

    _checkStatus(res);

    final data = _parseBody(res);
    if (data == null) {
      throw ApiException('Réponse serveur vide');
    }

    return Member.fromJson(data);
  }

  Future<Member> updateMember(
    int memberId, {
    String? firstName,
    String? lastName,
    String? phone,
    String? beltRank,
    String? subscriptionPlan,
  }) async {
    final res = await _Http.put(
      Uri.parse(_joinUrl(ApiConfig.members, '$memberId')),
      headers: _headers,
      body: jsonEncode({
        if (firstName != null) 'first_name': firstName,
        if (lastName != null) 'last_name': lastName,
        if (phone != null) 'phone': phone,
        if (beltRank != null) 'belt_rank': beltRank,
        if (subscriptionPlan != null) 'subscription_plan': subscriptionPlan,
        if (subscriptionPlan == 'two_per_week') 'weekly_booking_limit': 2,
        if (subscriptionPlan == 'unlimited') 'weekly_booking_limit': null,
      }),
    );

    _checkStatus(res);

    final data = _parseBody(res);
    if (data == null) {
      throw ApiException('Réponse serveur vide');
    }

    return Member.fromJson(data);
  }

  Future<List<Course>> getCourses({
    DateTime? fromDate,
    DateTime? toDate,
    String? courseType,
    int? coachId,
  }) async {
    final params = <String, String>{};

    if (fromDate != null) params['from_date'] = fromDate.toIso8601String();
    if (toDate != null) params['to_date'] = toDate.toIso8601String();
    if (courseType != null) params['course_type'] = courseType;
    if (coachId != null) params['coach_id'] = '$coachId';

    final uri = Uri.parse(ApiConfig.courses).replace(queryParameters: params);

    final res = await _Http.get(uri, headers: _headers);

    _checkStatus(res);

    final data = _parseBody(res);
    if (data is! List) return [];

    return data.map((e) => Course.fromJson(e)).toList();
  }

  Future<Course> getCourse(int courseId) async {
    final res = await _Http.get(
      Uri.parse(_joinUrl(ApiConfig.courses, '$courseId')),
      headers: _headers,
    );

    _checkStatus(res);

    final data = _parseBody(res);
    if (data == null) {
      throw ApiException('Cours introuvable');
    }

    return Course.fromJson(data);
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
    final res = await _Http.post(
      Uri.parse(ApiConfig.courses),
      headers: _headers,
      body: jsonEncode({
        'name': name,
        'description': description,
        'course_type': courseType,
        'level': level,
        'start_time': startTime.toUtc().toIso8601String(),
        'end_time': endTime.toUtc().toIso8601String(),
        'max_capacity': maxCapacity,
        'coach_id': coachId,
      }),
    );

    _checkStatus(res);

    final data = _parseBody(res);
    if (data == null) {
      throw ApiException('Réponse serveur vide lors de la création du cours');
    }

    return Course.fromJson(data);
  }

  Future<Course> updateCourse(
    int courseId, {
    required String name,
    String? description,
    required String courseType,
    required String level,
    required DateTime startTime,
    required DateTime endTime,
    required int maxCapacity,
    int? coachId,
  }) async {
    final res = await _Http.put(
      Uri.parse(_joinUrl(ApiConfig.courses, '$courseId')),
      headers: _headers,
      body: jsonEncode({
        'name': name,
        'description': description,
        'course_type': courseType,
        'level': level,
        'start_time': startTime.toIso8601String(),
        'end_time': endTime.toIso8601String(),
        'max_capacity': maxCapacity,
        'coach_id': coachId,
      }),
    );

    _checkStatus(res);

    final data = _parseBody(res);
    if (data == null) {
      throw ApiException('Réponse serveur vide lors de la modification du cours');
    }

    return Course.fromJson(data);
  }

  Future<void> deleteCourse(int courseId) async {
    final res = await _Http.delete(
      Uri.parse(_joinUrl(ApiConfig.courses, '$courseId')),
      headers: _headers,
    );

    _checkStatus(res);
  }

  Future<int> bulkDeleteCourses(List<int> courseIds) async {
    final res = await _Http.post(
      Uri.parse(_joinUrl(ApiConfig.courses, 'bulk-delete')),
      headers: _headers,
      body: jsonEncode({'course_ids': courseIds}),
    );

    _checkStatus(res);

    final data = _parseBody(res);
    if (data is Map && data['deleted_count'] != null) {
      return data['deleted_count'] as int;
    }

    return 0;
  }

  Future<int> deleteCourseSeries(
    int courseId, {
    bool deleteFollowingOnly = true,
  }) async {
    final res = await _Http.post(
      Uri.parse(_joinUrl(ApiConfig.courses, 'bulk-delete')),
      headers: _headers,
      body: jsonEncode({
        'same_series_as_course_id': courseId,
        'delete_following_only': deleteFollowingOnly,
      }),
    );

    _checkStatus(res);

    final data = _parseBody(res);
    if (data is Map && data['deleted_count'] != null) {
      return data['deleted_count'] as int;
    }

    return 0;
  }

  Future<List<Booking>> getMyBookings() async {
    final res = await _Http.get(
      Uri.parse(ApiConfig.myBookings),
      headers: _headers,
    );

    _checkStatus(res);

    final data = _parseBody(res);
    if (data is! List) return [];

    return data.map((e) => Booking.fromJson(e)).toList();
  }

  Future<Booking> createBooking(int courseId) async {
    final res = await _Http.post(
      Uri.parse(ApiConfig.bookings),
      headers: _headers,
      body: jsonEncode({'course_id': courseId}),
    );

    _checkStatus(res);

    final data = _parseBody(res);
    if (data == null) {
      throw ApiException('Réponse serveur vide lors de la réservation');
    }

    return Booking.fromJson(data);
  }

  Future<Booking> cancelBooking(int bookingId) async {
    final res = await _Http.delete(
      Uri.parse(_joinUrl(ApiConfig.bookings, '$bookingId')),
      headers: _headers,
    );

    _checkStatus(res);

    final data = _parseBody(res);
    if (data == null) {
      throw ApiException('Réponse serveur vide lors de l’annulation');
    }

    return Booking.fromJson(data);
  }

  Future<List<AcademyVideo>> getAcademyVideos() async {
    final res = await _Http.get(
      Uri.parse(ApiConfig.academyVideos),
      headers: _headers,
    );

    _checkStatus(res);

    final data = _parseBody(res);
    if (data is! List) return [];

    return data.map((e) => AcademyVideo.fromJson(e)).toList();
  }

  Future<AcademyVideo> createAcademyVideo({
    required String title,
    required String section,
    required String youtubeId,
    String? description,
    int sortOrder = 0,
  }) async {
    final res = await _Http.post(
      Uri.parse(ApiConfig.academyVideos),
      headers: _headers,
      body: jsonEncode({
        'title': title,
        'section': section,
        'youtube_id': youtubeId,
        'description': description,
        'sort_order': sortOrder,
      }),
    );

    _checkStatus(res);

    return AcademyVideo.fromJson(_parseBody(res));
  }

  Future<AcademyVideo> updateAcademyVideo(
    int videoId, {
    String? title,
    String? section,
    String? youtubeId,
    String? description,
    int? sortOrder,
  }) async {
    final body = <String, dynamic>{};
    if (title != null) body['title'] = title;
    if (section != null) body['section'] = section;
    if (youtubeId != null) body['youtube_id'] = youtubeId;
    if (description != null) body['description'] = description;
    if (sortOrder != null) body['sort_order'] = sortOrder;

    final res = await _Http.put(
      Uri.parse('${ApiConfig.academyVideos}/$videoId'),
      headers: _headers,
      body: jsonEncode(body),
    );

    _checkStatus(res);

    return AcademyVideo.fromJson(_parseBody(res));
  }

  Future<void> deleteAcademyVideo(int videoId) async {
    final res = await _Http.delete(
      Uri.parse('${ApiConfig.academyVideos}/$videoId'),
      headers: _headers,
    );

    _checkStatus(res);
  }

  Future<List<Member>> getCourseBookings(int courseId) async {
    final res = await _Http.get(
      Uri.parse(_joinUrl(ApiConfig.bookings, 'course/$courseId')),
      headers: _headers,
    );

    _checkStatus(res);

    final data = _parseBody(res);
    if (data is! List) return [];

    return data.map((e) => Member.fromJson(e)).toList();
  }

  // ── Push notifications ──────────────────────────────────────────────
  Future<void> registerDeviceToken(String token, String platform) async {
    final res = await _Http.post(
      Uri.parse(ApiConfig.deviceToken),
      headers: _headers,
      body: jsonEncode({'token': token, 'platform': platform}),
    );
    _checkStatus(res);
  }

  Future<void> unregisterDeviceToken(String token) async {
    final res = await _Http.delete(
      Uri.parse(ApiConfig.deviceToken),
      headers: _headers,
      body: jsonEncode({'token': token}),
    );
    _checkStatus(res);
  }
}