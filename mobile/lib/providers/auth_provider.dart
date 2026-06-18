import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';

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
    Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      if (data.event == AuthChangeEvent.signedOut) {
        _user = null;
        _isAuthenticated = false;
        notifyListeners();
      }
    });
  }

  Future<void> _init() async {
    final session = Supabase.instance.client.auth.currentSession;
    if (session != null) {
      try {
        _user = await AuthService.getMe();
        _isAuthenticated = _user != null;
      } catch (_) {}
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<String?> login(String email, String password) async {
    try {
      final user = await AuthService.login(email, password);
      if (user != null) {
        _user = user;
        _isAuthenticated = true;
        notifyListeners();
        return null;
      }
      return 'فشل تسجيل الدخول';
    } on AuthException catch (e) {
      return e.message;
    } catch (_) {
      return 'خطأ في الاتصال';
    }
  }

  Future<String?> register(String email, String password, String? name) async {
    try {
      final user = await AuthService.register(email, password, name);
      if (user != null) {
        _user = user;
        _isAuthenticated = true;
        notifyListeners();
        return null;
      }
      return 'فشل إنشاء الحساب';
    } on AuthException catch (e) {
      return e.message;
    } catch (_) {
      return 'خطأ في الاتصال';
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
