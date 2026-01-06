class ApiConstants {
  static const String _envBaseUrl = String.fromEnvironment('APP_BASE_URL');

  static String get baseUrl {
    if (_envBaseUrl.isEmpty) {
      throw Exception(
        'APP_BASE_URL is required. Please provide it via --dart-define=APP_BASE_URL=http://<ip>:<port>',
      );
    }
    return _envBaseUrl;
  }
}
