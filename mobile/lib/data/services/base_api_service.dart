/// Base API Service - Common HTTP request handling for all API services.
///
/// Provides reusable HTTP methods (GET, POST, PATCH, DELETE) with:
/// - Automatic token injection from SharedPreferences
/// - JSON encoding/decoding
/// - Server health check utilities
/// - Token validation helpers
///
/// All API service classes (AuthService, CallApiService, etc.) extend this.
library;

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../config/app_config.dart';

/// Base class for API services handling common HTTP logic.
abstract class BaseApiService {
  /// Test connection to a server by calling the /health endpoint.
  /// Returns true if the server responds with 200 OK.
  static Future<bool> testConnection(String host, int port) async {
    try {
      final uri = Uri.parse('http://$host:$port${AppConfig.healthEndpoint}');
      final response = await http.get(uri).timeout(
        const Duration(seconds: 5),
        onTimeout: () => http.Response('Timeout', 408),
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  /// Test connection to the currently configured server.
  static Future<bool> testCurrentConnection() async {
    return testConnection(AppConfig.currentHost, AppConfig.currentPort);
  }

  /// Validate auth token with a specific server by calling /api/auth/me.
  /// Returns true if the token is valid on that server.
  static Future<bool> validateAuthToken(String host, int port, String token) async {
    try {
      final uri = Uri.parse('http://$host:$port/api/auth/me');
      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(
        const Duration(seconds: 5),
        onTimeout: () => http.Response('Timeout', 408),
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

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
