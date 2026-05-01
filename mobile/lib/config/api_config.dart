class ApiConfig {
  // En développement : ton PC et le téléphone doivent être sur le même réseau
  // Remplace par l'IP locale de ta machine (pas localhost !)
  // Exemple : 'http://192.168.1.10:8000'
  // En production : remplace par l'URL de ton serveur Railway/Render
  static const String baseUrl = 'http://10.0.2.2:8000'; // émulateur Android
  // static const String baseUrl = 'http://localhost:8000'; // simulateur iOS

  // Endpoints
  static const String login = '$baseUrl/auth/login';
  static const String register = '$baseUrl/auth/register';
  static const String me = '$baseUrl/members/me';
  static const String courses = '$baseUrl/courses';
  static const String bookings = '$baseUrl/bookings';
  static const String myBookings = '$baseUrl/bookings/me';
}