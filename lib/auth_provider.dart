import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';

class AuthProvider extends ChangeNotifier {
  final ApiService _apiService = ApiService();
  bool _isAuthenticated = false;

  bool get isAuthenticated => _isAuthenticated;

  Future<void> checkLoginStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    _isAuthenticated = token != null;
    notifyListeners();
  }

  Future<void> login(String username, String password) async {
    final token = await _apiService.login(username, password);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('token', token);
    await prefs.setString('username', username);

    _isAuthenticated = true;
    notifyListeners(); // Memicu redirect di Router
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    _isAuthenticated = false;
    notifyListeners(); // Memicu redirect di Router
  }
}

// Global instance untuk akses mudah
final authProvider = AuthProvider();
