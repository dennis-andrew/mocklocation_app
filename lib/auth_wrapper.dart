import 'package:flutter/material.dart';
import 'services/auth_service.dart';
import 'services/api_service.dart';
import 'login_page.dart';
import 'home_page.dart';

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  static String baseUrl = 'https://smart-silver-rat.pams.revolte.io/api/v1/';

  final AuthService _authService = AuthService();
  bool _isInitializing = true;
  bool _isLoggedIn = false;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    try {
      await _authService.initialize();
      ApiService().initialize(baseUrl);

      // Check if user is logged in and token is valid
      bool isValidLogin = await _checkAuthStatus();

      setState(() {
        _isLoggedIn = isValidLogin;
        _isInitializing = false;
      });
    } catch (e) {
      setState(() {
        _isLoggedIn = false;
        _isInitializing = false;
      });
    }
  }

  Future<bool> _checkAuthStatus() async {
    // Check if we have a token
    if (!_authService.isLoggedIn) {
      return false;
    }

    // Check if token is expired (1 hour = 3600 seconds)
    final token = _authService.currentToken;
    if (token?.createdAt != null) {
      try {
        final createdAt = DateTime.parse(token!.createdAt!);
        final now = DateTime.now();
        final difference = now.difference(createdAt);

        // If token is older than 1 hour, consider it expired
        if (difference.inSeconds >= 3600) {
          await _authService.logout(); // Clear expired token
          return false;
        }
      } catch (e) {
        // If we can't parse the date, treat as expired
        await _authService.logout();
        return false;
      }
    }

    return true;
  }

  @override
  Widget build(BuildContext context) {
    if (_isInitializing) {
      return Scaffold(
        backgroundColor: Colors.grey[50],
        body: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.indigo[600]!, Colors.indigo[400]!],
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(25),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withAlpha(51)),
                ),
                child: Icon(
                  Icons.location_on,
                  color: Colors.white,
                  size: 48,
                ),
              ),
              SizedBox(height: 24),
              Text(
                'Mock Location Service',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Emergency Services Coordination',
                style: TextStyle(
                  color: Colors.white.withAlpha(204),
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(height: 40),
              SizedBox(
                width: 32,
                height: 32,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
              SizedBox(height: 16),
              Text(
                'Initializing...',
                style: TextStyle(
                  color: Colors.white.withAlpha(204),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_isLoggedIn) {
      return const MyHomePage(title: 'Updating the mocking coords to BE');
    } else {
      return const LoginPage();
    }
  }
}
