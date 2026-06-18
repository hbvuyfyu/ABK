import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_model.dart';
import 'api_service.dart';

class AuthService {
  static Future<UserModel?> register(String email, String password, String? name) async {
    final res = await ApiService.client.auth.signUp(
      email: email,
      password: password,
      data: name != null && name.isNotEmpty ? {'name': name} : null,
    );
    if (res.user == null) return null;
    // Wait briefly for trigger to create profile
    await Future.delayed(const Duration(milliseconds: 500));
    return getMe();
  }

  static Future<UserModel?> login(String email, String password) async {
    final res = await ApiService.client.auth.signInWithPassword(
      email: email, password: password,
    );
    if (res.user == null) return null;
    return getMe();
  }

  static Future<UserModel?> getMe() async {
    final user = ApiService.client.auth.currentUser;
    if (user == null) return null;
    try {
      final data = await ApiService.client
          .from('profiles')
          .select()
          .eq('id', user.id)
          .maybeSingle();
      if (data == null) {
        return UserModel(id: user.id, email: user.email ?? '', role: 'USER');
      }
      return UserModel.fromJson(data);
    } catch (_) {
      return UserModel(id: user.id, email: user.email ?? '', role: 'USER');
    }
  }

  static Future<void> logout() async {
    await ApiService.client.auth.signOut();
  }
}
