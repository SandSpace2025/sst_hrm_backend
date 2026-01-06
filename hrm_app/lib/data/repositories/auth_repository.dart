import 'package:hrm_app/core/services/http_service.dart';

class AuthRepository {
  final HttpService _httpService;

  AuthRepository({HttpService? httpService})
    : _httpService = httpService ?? HttpService();

  Future<Map<String, dynamic>> login(String email, String password) async {
    final response = await _httpService.post(
      '/api/auth/login',
      body: {'email': email, 'password': password},
      contextName: 'Login API',
    );
    return response as Map<String, dynamic>;
  }

  Future<void> logout(String token) async {
    await _httpService.post(
      '/api/auth/logout',
      token: token,
      isVoid: true,
      contextName: 'Logout API',
    );
  }

  Future<void> updateFcmToken(String token, String fcmToken) async {
    try {
      await _httpService.put(
        '/api/users/fcm-token',
        token: token,
        body: {'fcmToken': fcmToken},
        isVoid: true,
        contextName: 'Update FCM Token API',
      );
    } catch (e) {
      // Ignore errors for FCM token update as it shouldn't block app usage
    }
  }
}
