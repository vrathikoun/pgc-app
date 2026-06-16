class ApiConfig {
  static const String baseUrl = 'https://pgc-app.onrender.com';

  static const String login = '$baseUrl/auth/login';
  static const String register = '$baseUrl/auth/register';

  static const String me = '$baseUrl/members/me';
  static const String coaches = '$baseUrl/members/coaches';

  static const String members = '$baseUrl/members/';
  static const String courses = '$baseUrl/courses/';
  static const String bookings = '$baseUrl/bookings/';
  static const String myBookings = '$baseUrl/bookings/me';
  static const String academyVideos = '$baseUrl/academy/videos';

  static const String deviceToken = '$baseUrl/notifications/device-token';
}