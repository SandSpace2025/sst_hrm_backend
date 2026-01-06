import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:hrm_app/core/services/logger_service.dart';
import 'package:hrm_app/core/utils/snackbar_utils.dart';
import 'package:hrm_app/main.dart';

class GlobalErrorHandler {
  static void initialize() {
    FlutterError.onError = (FlutterErrorDetails details) {
      LoggerService.error(
        'Flutter Error',
        error: details.exception,
        stackTrace: details.stack,
        tag: 'FLUTTER_ERROR',
      );

      _showErrorToUser(details.exception.toString());
    };

    PlatformDispatcher.instance.onError = (error, stack) {
      LoggerService.error(
        'Async Error',
        error: error,
        stackTrace: stack,
        tag: 'ASYNC_ERROR',
      );

      _showErrorToUser(error.toString());

      return true;
    };
  }

  static void _showErrorToUser(String errorMessage) {
    String? userMessage;

    if (errorMessage.contains('SocketException') ||
        errorMessage.contains('No internet')) {
      userMessage = 'No internet connection';
    } else if (errorMessage.contains('TimeoutException')) {
      userMessage = 'Request timed out';
    } else if (errorMessage.contains('FormatException')) {
      userMessage = 'Invalid data format';
    } else if (errorMessage.contains('Unauthorized') ||
        errorMessage.contains('401')) {
      userMessage = 'Session expired. Please login again';
    }

    if (userMessage == null) {
      // Suppress generic errors to prevent spam loops
      // We log it but do NOT show UI feedback for unknown errors
      // This prevents "An error occurred" toast spam during render loops
      LoggerService.error(
        'GlobalErrorHandler: Suppressed generic error: $errorMessage',
      );
      return;
    }

    final context = MyApp.navigatorKey.currentContext;
    if (context != null) {
      // Use SnackBarUtils for consistent UI
      SnackBarUtils.showError(context, userMessage);
    } else {
      // Fallback only if context is missing (rare)
      Fluttertoast.showToast(
        msg: userMessage,
        backgroundColor: Colors.red,
        textColor: Colors.white,
        toastLength: Toast.LENGTH_LONG,
      );
    }
  }

  static void handleError(
    dynamic error, {
    StackTrace? stackTrace,
    String? context,
  }) {
    LoggerService.error(
      context ?? 'Manual Error',
      error: error,
      stackTrace: stackTrace,
      tag: 'HANDLED_ERROR',
    );

    _showErrorToUser(error.toString());
  }
}
