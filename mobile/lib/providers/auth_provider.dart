import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:pgc_app/models/member.dart';
import 'package:pgc_app/services/api_service.dart';

class AuthProvider extends ChangeNotifier {
  static const _tokenKey = 'jwt_token';
  final _storage = const FlutterSecureStorage();

  Member? _member;
  String? _token;
  bool _loading = false;
  String? _error;

  Member? get member => _member;
  String? get token => _token;
  bool get loading => _loading;
  String? get error => _error;
  bool get isAuthenticated => _token != null && _member != null;

  ApiService get api => ApiService(token: _token);

  // Appelé au démarrage de l'app
  Future<void> tryAutoLogin() async {
    final saved = await _storage.read(key: _tokenKey);
    if (saved == null) return;
    _token = saved;
    try {
      _member = await ApiService(token: saved).getMe();
      notifyListeners();
    } catch (_) {
      await logout();
    }
  }

  Future<bool> login(String email, String password) async {
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      final data = await ApiService().login(email, password);
      _token = data['access_token'];
      _member = Member.fromJson(data['member']);
      await _storage.write(key: _tokenKey, value: _token);
      return true;
    } on ApiException catch (e) {
      _error = e.message;
      return false;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<bool> register({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
  }) async {
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      await ApiService().register(
        email: email,
        password: password,
        firstName: firstName,
        lastName: lastName,
      );
      // Auto-login après inscription
      return await login(email, password);
    } on ApiException catch (e) {
      _error = e.message;
      return false;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    _token = null;
    _member = null;
    await _storage.delete(key: _tokenKey);
    notifyListeners();
  }

  /// Met à jour le membre en mémoire (après upload avatar, update profil, etc.)
  Future<void> refreshMember(Member updated) async {
    _member = updated;
    notifyListeners();
  }
}