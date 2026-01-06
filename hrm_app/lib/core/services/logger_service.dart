import 'package:flutter/foundation.dart';

class LoggerService {
  static void log(String message, {String tag = 'APP'}) {
    if (kDebugMode) {
      debugPrint('[$tag] $message');
    }
  }

  static void info(String message, {String tag = 'INFO'}) {
    log(message, tag: 'ℹ️ $tag');
  }

  static void warning(String message, {String tag = 'WARNING'}) {
    log(message, tag: '⚠️ $tag');
  }

  static void error(
    String message, {
    dynamic error,
    StackTrace? stackTrace,
    String tag = 'ERROR',
  }) {
    if (kDebugMode) {
      debugPrint('[$tag] $message');
      if (error != null) debugPrint('Error: $error');
      if (stackTrace != null) debugPrint('Stack: $stackTrace');
    }
  }

  static void debug(String message, {String tag = 'DEBUG'}) {
    log(message, tag: '🐛 $tag');
  }
}
