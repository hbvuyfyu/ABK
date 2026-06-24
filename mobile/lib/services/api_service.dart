import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';

class ApiService {
  static const _storage = FlutterSecureStorage();
  static const _tokenKey = 'auth_token';

  static Future<String?> getToken() => _storage.read(key: _tokenKey);
  static Future<void> saveToken(String token) => _storage.write(key: _tokenKey, value: token);
  static Future<void> deleteToken() => _storage.delete(key: _tokenKey);

  static Future<Map<String, String>> _headers({bool auth = true}) async {
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (auth) {
      final token = await getToken();
      if (token != null) headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  static Future<Map<String, dynamic>> get(String path, {bool auth = true}) async {
    final uri = Uri.parse('${AppConfig.apiUrl}$path');
    final res = await http.get(uri, headers: await _headers(auth: auth));
    return _parse(res);
  }

  static Future<Map<String, dynamic>> post(String path, Map<String, dynamic> body, {bool auth = true}) async {
    final uri = Uri.parse('${AppConfig.apiUrl}$path');
    final res = await http.post(uri, headers: await _headers(auth: auth), body: jsonEncode(body));
    return _parse(res);
  }

  static Future<Map<String, dynamic>> put(String path, Map<String, dynamic> body, {bool auth = true}) async {
    final uri = Uri.parse('${AppConfig.apiUrl}$path');
    final res = await http.put(uri, headers: await _headers(auth: auth), body: jsonEncode(body));
    return _parse(res);
  }

  static Future<Map<String, dynamic>> patch(String path, Map<String, dynamic> body, {bool auth = true}) async {
    final uri = Uri.parse('${AppConfig.apiUrl}$path');
    final res = await http.patch(uri, headers: await _headers(auth: auth), body: jsonEncode(body));
    return _parse(res);
  }

  static Future<Map<String, dynamic>> delete(String path, {bool auth = true}) async {
    final uri = Uri.parse('${AppConfig.apiUrl}$path');
    final res = await http.delete(uri, headers: await _headers(auth: auth));
    return _parse(res);
  }

  static Map<String, dynamic> _parse(http.Response res) {
    try {
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      return data;
    } catch (_) {
      return {'success': false, 'message': 'Invalid response from server'};
    }
  }
}
