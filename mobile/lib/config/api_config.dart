class ApiConfig {
  // Flutter Web / Linux desktop depuis WSL : localhost marche si FastAPI tourne sur le même WSL.
  // Android emulator Windows : remplace par http://10.0.2.2:8000
  // Téléphone réel : remplace par http://IP_DE_TON_PC:8000
  static const String baseUrl = 'https://pgc-api.onrender.com';
  static const String login = '$baseUrl/auth/login';
  static const String register = '$baseUrl/auth/register';
  static const String me = '$baseUrl/members/me';
  static const String coaches = '$baseUrl/members/coaches';
  static const String members = '$baseUrl/members';
  static const String courses = '$baseUrl/courses';
  static const String bookings = '$baseUrl/bookings';
  static const String myBookings = '$baseUrl/bookings/me';
}