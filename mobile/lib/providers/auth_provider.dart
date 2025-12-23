import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/api/api_service.dart';
import '../models/user.dart';

/// Holds registration data temporarily until the flow is complete
class PendingRegistration {
  final String phone;
  final String fullName;
  final String password;
  final String primaryLanguage;

  PendingRegistration({
    required this.phone,
    required this.fullName,
    required this.password,
    required this.primaryLanguage,
  });
}

class AuthProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();
  User? _currentUser;
  bool _isLoading = false;

  /// Temporary storage for registration data until flow is complete
  PendingRegistration? _pendingRegistration;

  User? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _currentUser != null;
  bool get hasPendingRegistration => _pendingRegistration != null;
  PendingRegistration? get pendingRegistration => _pendingRegistration;

  Future<bool> login(String phone, String password) async {
    _isLoading = true;
    notifyListeners();

    try {
      _currentUser = await _apiService.login(phone, password);
      // Hydrate with /auth/me when possible
      final me = await _apiService.me();
      if (me != null) {
        _currentUser = me;
      }
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Callback for logout actions (e.g., disconnect from WebSocket)
  VoidCallback? _onLogout;

  /// Set callback to be called when user logs out
  void setOnLogoutCallback(VoidCallback callback) => _onLogout = callback;

  void logout() {
    _currentUser = null;
    // Trigger logout callback (e.g., disconnect from Lobby)
    _onLogout?.call();
    // Clear stored auth token and user id
    SharedPreferences.getInstance().then((prefs) {
      prefs.remove('user_token');
      prefs.remove('user_id');
    });
    notifyListeners();
  }

  /// Store registration data temporarily (don't call API yet)
  void setPendingRegistration({
    required String phone,
    required String fullName,
    required String password,
    required String primaryLanguage,
  }) {
    _pendingRegistration = PendingRegistration(
      phone: phone,
      fullName: fullName,
      password: password,
      primaryLanguage: primaryLanguage,
    );
    notifyListeners();
  }

  /// Clear pending registration data
  void clearPendingRegistration() {
    _pendingRegistration = null;
    notifyListeners();
  }

  /// Complete the registration (call API with pending data)
  /// Call this after voice recording or skip
  Future<bool> completePendingRegistration() async {
    if (_pendingRegistration == null) {
      debugPrint('[AuthProvider] No pending registration to complete');
      return false;
    }

    _isLoading = true;
    notifyListeners();

    try {
      _currentUser = await _apiService.register(
        _pendingRegistration!.phone,
        _pendingRegistration!.fullName,
        _pendingRegistration!.password,
        _pendingRegistration!.primaryLanguage,
      );

      // Hydrate with /auth/me when possible
      final me = await _apiService.me();
      if (me != null) {
        _currentUser = me;
      }

      // Clear pending data after successful registration
      _pendingRegistration = null;
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('[AuthProvider] Registration failed: $e');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Direct registration (for cases where voice is already recorded)
  Future<bool> register(
      {required String phone,
      required String fullName,
      required String password,
      required String primaryLanguage}) async {
    _isLoading = true;
    notifyListeners();
    try {
      _currentUser = await _apiService.register(
          phone, fullName, password, primaryLanguage);
      // Hydrate with /auth/me when possible
      final me = await _apiService.me();
      if (me != null) {
        _currentUser = me;
      }
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Refresh current user data from the server
  Future<void> refreshCurrentUser() async {
    try {
      final me = await _apiService.me();
      if (me != null) {
        _currentUser = me;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('[AuthProvider] Failed to refresh user: $e');
    }
  }

  /// Check if user is currently authenticated (has token in storage)
  /// Returns the token if valid, null otherwise
  Future<String?> checkAuthStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('user_token');
    final userId = prefs.getString('user_id');

    if (token != null && userId != null) {
      // Validate session with server if needed, for now just check existence
      // We could call /auth/me here to verify validity
      try {
        final me = await _apiService.me();
        if (me != null) {
          _currentUser = me;
          notifyListeners();
          return token;
        }
      } catch (e) {
        debugPrint('[AuthProvider] Token validation failed: $e');
        // If server rejects token (401), clear it
        logout();
        return null;
      }
    }
    return null;
  }
}
