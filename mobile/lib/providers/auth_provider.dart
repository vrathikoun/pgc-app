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

  Future<void> tryAutoLogin() async {
    final saved = await _storage.read(key: _tokenKey);

    if (saved == null || saved.isEmpty) {
      return;
    }

    _token = saved;

    try {
      _member = await ApiService(token: saved).getMe();
      notifyListeners();
    } catch (_) {
      await logout();
    }
  }

  Future<bool> login(
    String email,
    String password, {
    bool rememberMe = true,
  }) async {
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      final data = await ApiService().login(email, password);

      _token = data['access_token'];

      if (data['member'] != null) {
        _member = Member.fromJson(data['member']);
      } else {
        _member = await ApiService(token: _token).getMe();
      }

      if (rememberMe) {
        await _storage.write(key: _tokenKey, value: _token);
      } else {
        await _storage.delete(key: _tokenKey);
      }

      return true;
    } on ApiException catch (e) {
      _error = e.message;
      return false;
    } catch (e) {
      _error = e.toString();
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
    bool rememberMe = true,
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

      return await login(
        email,
        password,
        rememberMe: rememberMe,
      );
    } on ApiException catch (e) {
      _error = e.message;
      return false;
    } catch (e) {
      _error = e.toString();
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

  Future<void> refreshMember(Member updated) async {
    _member = updated;
    notifyListeners();
  }
}