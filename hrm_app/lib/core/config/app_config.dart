class AppConfig {
  static const String _envBaseUrl = String.fromEnvironment('APP_BASE_URL');

  static String get websocketUrl {
    if (_envBaseUrl.isEmpty) {
      throw Exception(
        'APP_BASE_URL is required. Please provide it via --dart-define=APP_BASE_URL=http://<ip>:<port>',
      );
    }

    return _envBaseUrl;
  }

  static String get apiBaseUrl => '$websocketUrl/api';

  static const Duration connectionTimeout = Duration(seconds: 10);

  static const int maxReconnectionAttempts = 5;
  static const Duration reconnectionDelay = Duration(seconds: 1);
  static const Duration maxReconnectionDelay = Duration(seconds: 5);
}
