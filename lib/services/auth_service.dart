import 'dart:convert';
import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';
import '../models/token.dart';
import 'api_service.dart';
import '../auth_wrapper.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  static const String _userKey = 'user';
  static const String _tokenKey = 'token';

  AppUser? _currentUser;
  Token? _currentToken;

  AppUser? get currentUser => _currentUser;
  Token? get currentToken => _currentToken;
  bool get isLoggedIn =>
      _currentToken?.accessToken != null && !_isTokenExpired();

  static void redirectToLogin(BuildContext context) {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const AuthWrapper()),
      (route) => false,
    );
  }

  bool _isTokenExpired() {
    final token = _currentToken;
    if (token?.createdAt == null) return true;

    try {
      final createdAt = DateTime.parse(token!.createdAt!);
      final now = DateTime.now();
      final difference = now.difference(createdAt);

      // Token expires after 1 hour (3600 seconds)
      return difference.inSeconds >= 3600;
    } catch (e) {
      // If we can't parse the date, treat as expired
      return true;
    }
  }

  Future<void> initialize() async {
    await _loadUserFromPrefs();
    await _loadTokenFromPrefs();

    // Clear expired token on initialization
    if (_isTokenExpired()) {
      await logout();
    }
  }

  Future<LoginResponse> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await ApiService().login(
        email: email,
        password: password,
      );

      if (response.success && response.user != null && response.token != null) {
        _currentUser = response.user;
        _currentToken = response.token;

        await _saveUserToPrefs(response.user!);
        await _saveTokenToPrefs(response.token!);

        log('Login successful for user: ${response.user?.firstName}');
        return response;
      } else {
        return response;
      }
    } catch (e) {
      log('Auth service login error: $e');
      return LoginResponse(
        success: false,
        error: 'Authentication failed',
      );
    }
  }

  Future<void> logout() async {
    _currentUser = null;
    _currentToken = null;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_userKey);
    await prefs.remove(_tokenKey);

    log('User logged out successfully');
  }

  Future<void> _saveUserToPrefs(AppUser user) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userJson = jsonEncode(user.toJson());
      await prefs.setString(_userKey, userJson);
    } catch (e) {
      log('Error saving user to preferences: $e');
    }
  }

  Future<void> _loadUserFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userJson = prefs.getString(_userKey);
      if (userJson != null) {
        final userMap = jsonDecode(userJson) as Map<String, dynamic>;
        _currentUser = AppUser.fromJson(userMap);
      }
    } catch (e) {
      log('Error loading user from preferences: $e');
    }
  }

  Future<void> _saveTokenToPrefs(Token token) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final tokenJson = jsonEncode(token.toJson());
      await prefs.setString(_tokenKey, tokenJson);
    } catch (e) {
      log('Error saving token to preferences: $e');
    }
  }

  Future<void> _loadTokenFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final tokenJson = prefs.getString(_tokenKey);
      if (tokenJson != null) {
        final tokenMap = jsonDecode(tokenJson) as Map<String, dynamic>;
        _currentToken = Token.fromJson(tokenMap);
      }
    } catch (e) {
      log('Error loading token from preferences: $e');
    }
  }
}
