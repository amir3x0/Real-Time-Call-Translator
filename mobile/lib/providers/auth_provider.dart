import 'package:flutter/material.dart';
import '../data/api/api_service.dart';
import '../models/user.dart';

class AuthProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();
  User? _currentUser;
  bool _isLoading = false;

  User? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _currentUser != null;

  Future<bool> login(String phone, String password) async {
    _isLoading = true;
    notifyListeners();

    try {
      _currentUser = await _apiService.login(phone, password);
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  void logout() {
    _currentUser = null;
    notifyListeners();
  }

  Future<bool> register({required String phone, required String fullName, required String password, required String primaryLanguage}) async {
    _isLoading = true;
    notifyListeners();
    try {
      _currentUser = await _apiService.register(phone, fullName, password, primaryLanguage);
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }
}