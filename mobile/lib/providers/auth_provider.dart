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
        _user = await AuthService.getMe();
        _isAuthenticated = _user != null;
        if (_user == null) await ApiService.deleteToken();
      } catch (_) {
        await ApiService.deleteToken();
      }
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<String?> login(String email, String password) async {
    try {
      final data = await AuthService.login(email, password);
      if (data != null && data['user'] != null) {
        _user = UserModel.fromJson(data['user'] as Map<String, dynamic>);
        _isAuthenticated = true;
        notifyListeners();
        return null;
      }
      return 'فشل تسجيل الدخول، تحقق من البريد وكلمة المرور';
    } catch (_) {
      return 'خطأ في الاتصال بالسيرفر';
    }
  }

  Future<String?> register(String email, String password, String? name) async {
    try {
      final data = await AuthService.register(email, password, name);
      if (data != null && data['user'] != null) {
        _user = UserModel.fromJson(data['user'] as Map<String, dynamic>);
        _isAuthenticated = true;
        notifyListeners();
        return null;
      }
      return 'فشل إنشاء الحساب';
    } catch (_) {
      return 'خطأ في الاتصال بالسيرفر';
    }
  }

  Future<void> logout() async {
    await AuthService.logout();
    _user = null;
    _isAuthenticated = false;
    notifyListeners();
  }

  Future<void> refresh() async {
    _isLoading = true;
    notifyListeners();
    await _init();
  }
}
