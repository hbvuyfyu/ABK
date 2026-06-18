import 'package:supabase_flutter/supabase_flutter.dart';

class ApiService {
  static SupabaseClient get client => Supabase.instance.client;

  static Future<String?> getToken() async {
    return client.auth.currentSession?.accessToken;
  }

  static Future<void> deleteToken() async {
    await client.auth.signOut();
  }
}
