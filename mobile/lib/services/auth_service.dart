import '../models/user_model.dart';
import 'api_service.dart';

class AuthService {
  static Future<Map<String, dynamic>> register(String email, String password, String? name) async {
    return await ApiService.post('/auth/register', {
      'email': email,
      'password': password,
      if (name != null) 'name': name,
    }, auth: false);
  }

  static Future<Map<String, dynamic>> login(String email, String password) async {
    return await ApiService.post('/auth/login', {'email': email, 'password': password}, auth: false);
  }

  static Future<Map<String, dynamic>> getMe() async {
    return await ApiService.get('/auth/me');
  }

  static Future<void> logout() async {
    await ApiService.deleteToken();
  }
}
