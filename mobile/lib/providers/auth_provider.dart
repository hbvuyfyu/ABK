import 'package:flutter/foundation.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/api_service.dart';

class AuthProvider extends ChangeNotifier {
  UserModel? _user;
  bool _isLoading = true;
  bool _isAuthenticated = false;

  UserModel? get user => _user;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _isAuthenticated;
  bool get isAdmin => _user?.role == 'ADMIN';

  AuthProvider() {
    _init();
  }

  Future<void> _init() async {
    final token = await ApiService.getToken();
    if (token != null) {
      try {
        final resp = await AuthService.getMe();
        if (resp['success'] == true) {
          _user = UserModel.fromJson(resp['data']);
          _isAuthenticated = true;
        } else {
          await ApiService.deleteToken();
        }
      } catch (_) {
        await ApiService.deleteToken();
      }
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<String?> login(String email, String password) async {
    try {
      final resp = await AuthService.login(email, password);
      if (resp['success'] == true) {
        await ApiService.saveToken(resp['data']['token']);
        _user = UserModel.fromJson(resp['data']['user']);
        _isAuthenticated = true;
        notifyListeners();
        return null;
      }
      return resp['message'] ?? 'Login failed';
    } catch (_) {
      return 'Connection error';
    }
  }

  Future<String?> register(String email, String password, String? name) async {
    try {
      final resp = await AuthService.register(email, password, name);
      if (resp['success'] == true) {
        await ApiService.saveToken(resp['data']['token']);
        _user = UserModel.fromJson(resp['data']['user']);
        _isAuthenticated = true;
        notifyListeners();
        return null;
      }
      return resp['message'] ?? 'Registration failed';
    } catch (_) {
      return 'Connection error';
    }
  }

  Future<void> logout() async {
    await AuthService.logout();
    _user = null;
    _isAuthenticated = false;
    notifyListeners();
  }

  Future<void> refresh() async {
    await _init();
  }
}
