import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../config/app_config.dart';

/// Base class for API services handling common HTTP logic
abstract class BaseApiService {
  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(AppConfig.userTokenKey);
  }

  Uri buildUri(String path, [Map<String, String>? query]) {
    return Uri.parse('${AppConfig.baseUrl}$path')
        .replace(queryParameters: query);
  }

  Map<String, String> getAuthHeaders(String? token) {
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  /// Helper for GET requests
  Future<http.Response> get(String path, {Map<String, String>? query}) async {
    final token = await getToken();
    final uri = buildUri(path, query);
    return http.get(uri, headers: getAuthHeaders(token));
  }

  /// Helper for POST requests
  Future<http.Response> post(String path, {Object? body}) async {
    final token = await getToken();
    final uri = buildUri(path);
    return http.post(
      uri,
      headers: getAuthHeaders(token),
      body: body != null ? jsonEncode(body) : null,
    );
  }

  /// Helper for PATCH requests
  Future<http.Response> patch(String path, {Object? body}) async {
    final token = await getToken();
    final uri = buildUri(path);
    return http.patch(
      uri,
      headers: getAuthHeaders(token),
      body: body != null ? jsonEncode(body) : null,
    );
  }

  /// Helper for DELETE requests
  Future<http.Response> delete(String path) async {
    final token = await getToken();
    final uri = buildUri(path);
    return http.delete(uri, headers: getAuthHeaders(token));
  }
}
