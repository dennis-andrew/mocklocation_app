import 'dart:developer';
import 'package:dio/dio.dart';
import 'package:pretty_dio_logger/pretty_dio_logger.dart';
import '../models/user.dart';
import '../models/token.dart';

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  late Dio _dio;

  void initialize(String baseUrl) {
    _dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      headers: {
        'Content-Type': 'application/json',
        'User-Agent': 'Mobile',
      },
    ));

    _dio.interceptors.add(
      PrettyDioLogger(
        request: true,
        responseBody: true,
        requestBody: true,
        requestHeader: true,
        responseHeader: true,
      ),
    );
  }

  Future<LoginResponse> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _dio.post(
        '/auth/login',
        data: {
          'email': email,
          'password': password,
          "remember_me": true,
          'grant_type': 'credentials',
          "provider": "local",
        },
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = response.data['data'] as Map<String, dynamic>;
        final user = AppUser.fromJson(
          data['user'] as Map<String, dynamic>? ?? {},
        );
        final token = Token.fromJson(
          data['token'] as Map<String, dynamic>,
        );

        return LoginResponse(
          success: true,
          user: user,
          token: token,
        );
      } else {
        return LoginResponse(
          success: false,
          error: 'Login failed: ${response.statusMessage}',
        );
      }
    } on DioException catch (e) {
      String errorMessage = 'Login failed';
      if (e.response?.statusCode == 422) {
        errorMessage = 'Invalid credentials';
      } else if (e.response?.statusCode == 500) {
        errorMessage = 'Server error';
      } else if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout) {
        errorMessage = 'Connection timeout';
      } else if (e.type == DioExceptionType.connectionError) {
        errorMessage = 'No internet connection';
      }

      log('Login error: $e');
      return LoginResponse(
        success: false,
        error: errorMessage,
      );
    } catch (e) {
      log('Unexpected login error: $e');
      return LoginResponse(
        success: false,
        error: 'An unexpected error occurred',
      );
    }
  }
}

class LoginResponse {
  LoginResponse({
    required this.success,
    this.user,
    this.token,
    this.error,
  });

  final bool success;
  final AppUser? user;
  final Token? token;
  final String? error;
}
