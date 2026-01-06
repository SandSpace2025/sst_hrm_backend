import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hrm_app/core/services/hive_cache_service.dart';
import 'package:hrm_app/data/repositories/auth_repository.dart';
import 'package:jwt_decode/jwt_decode.dart';
import 'package:provider/provider.dart';
import 'package:hrm_app/presentation/providers/admin_provider.dart';
import 'package:hrm_app/presentation/providers/announcement_provider.dart';
import 'package:hrm_app/presentation/providers/attendance_provider.dart';
import 'package:hrm_app/presentation/providers/employee_provider.dart';
import 'package:hrm_app/presentation/providers/eod_provider.dart';
import 'package:hrm_app/presentation/providers/hr_provider.dart';
import 'package:hrm_app/presentation/providers/leave_request_provider.dart';
import 'package:hrm_app/presentation/providers/message_provider.dart';
import 'package:hrm_app/presentation/providers/messaging_provider.dart';
import 'package:hrm_app/presentation/providers/payroll_provider.dart';
import 'package:hrm_app/presentation/providers/websocket_provider.dart';

import 'package:hrm_app/core/services/notification_service.dart';

class AuthProvider with ChangeNotifier {
  String? _token;
  String? _role;
  bool _isLoading = false;

  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  final AuthRepository _authRepository = AuthRepository();

  bool get isAuth => _token != null;
  bool get isLoading => _isLoading;
  String? get role => _role;
  String? get token => _token;

  String? get userId {
    if (_token == null) return null;
    try {
      final payload = Jwt.parseJwt(_token!);
      return (payload['userId'] ?? payload['id'])?.toString();
    } catch (e) {
      return null;
    }
  }

  Future<String?> login(
    String email,
    String password,
    BuildContext context,
  ) async {
    _isLoading = true;
    notifyListeners();

    try {
      await HiveCacheService.clearAllCache();

      final responseData = await _authRepository.login(email, password);

      _token = responseData['accessToken'];
      _role = responseData['role']?.toString().toLowerCase();

      await _storage.write(key: 'jwt', value: _token);

      // CRITICAL: After setting new token, ensure all providers clear their data again
      // This ensures that any data loaded with the old token is cleared
      // CRITICAL: After setting new token, ensure all providers clear their data again
      // This ensures that any data loaded with the old token is cleared
      debugPrint(
        '🔄 AuthProvider: Clearing all providers data after setting new token',
      );

      // Clear all providers individually to ensure one failure doesn't stop others
      await _safeClearProvider<EmployeeProvider>(context);
      await _safeClearProvider<AttendanceProvider>(context);
      await _safeClearProvider<HRProvider>(context);
      await _safeClearProvider<AdminProvider>(context);
      await _safeClearProvider<EODProvider>(context);
      await _safeClearProvider<AnnouncementProvider>(context);
      await _safeClearProvider<LeaveRequestProvider>(context);
      await _safeClearProvider<PayrollProvider>(context);
      await _safeClearProvider<MessageProvider>(context);
      await _safeClearProvider<MessagingProvider>(context);

      if (_token != null && _role != null) {
        final userId = responseData['userId'] ?? responseData['id'];
        if (userId != null) {
          final webSocketProvider = Provider.of<WebSocketProvider>(
            context,
            listen: false,
          );
          await webSocketProvider.connect(_token!, userId.toString(), _role!);

          // Initialize Messaging Provider with Token
          final messagingProvider = Provider.of<MessagingProvider>(
            context,
            listen: false,
          );
          messagingProvider.initializeMessaging(_token!);

          // Sync FCM Token
          NotificationService().getFcmToken().then((fcmToken) {
            if (fcmToken != null) {
              _authRepository.updateFcmToken(_token!, fcmToken);
            }
          });

          // Refresh Attendance Data
          Provider.of<AttendanceProvider>(
            context,
            listen: false,
          ).loadAttendance();
        }
      }

      _isLoading = false;
      notifyListeners();
      return _role;
    } catch (error) {
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<String?> tryAutoLogin(BuildContext context) async {
    final token = await _storage.read(key: 'jwt');

    if (token == null || Jwt.isExpired(token)) {
      return null;
    }

    _token = token;
    final Map<String, dynamic> payload = Jwt.parseJwt(token);
    _role = payload['role']?.toString().toLowerCase();
    final userId = payload['userId'] ?? payload['id'];

    if (_token != null && _role != null && userId != null) {
      final webSocketProvider = Provider.of<WebSocketProvider>(
        context,
        listen: false,
      );
      await webSocketProvider.connect(_token!, userId.toString(), _role!);

      // Initialize Messaging Provider with Token
      final messagingProvider = Provider.of<MessagingProvider>(
        context,
        listen: false,
      );
      messagingProvider.initializeMessaging(_token!);

      // Sync FCM Token
      NotificationService().getFcmToken().then((fcmToken) {
        if (fcmToken != null) {
          _authRepository.updateFcmToken(_token!, fcmToken);
        }
      });

      // Refresh Attendance Data
      Provider.of<AttendanceProvider>(context, listen: false).loadAttendance();
    }

    notifyListeners();
    return _role;
  }

  Future<void> logout(BuildContext context) async {
    final webSocketProvider = Provider.of<WebSocketProvider>(
      context,
      listen: false,
    );
    await webSocketProvider.disconnect();

    // Clear all providers
    // Clear all providers individually to ensure one failure doesn't stop others
    await _safeClearProvider<EmployeeProvider>(context);
    await _safeClearProvider<AttendanceProvider>(context);
    await _safeClearProvider<HRProvider>(context);
    await _safeClearProvider<AdminProvider>(context);
    await _safeClearProvider<EODProvider>(context);
    await _safeClearProvider<AnnouncementProvider>(context);
    await _safeClearProvider<LeaveRequestProvider>(context);
    await _safeClearProvider<PayrollProvider>(context);
    await _safeClearProvider<MessageProvider>(context);
    await _safeClearProvider<MessagingProvider>(context);

    await HiveCacheService.clearAllCache();

    _token = null;
    _role = null;
    await _storage.delete(key: 'jwt');
    notifyListeners();
  }

  Future<void> _safeClearProvider<T>(BuildContext context) async {
    try {
      final provider = Provider.of<T>(context, listen: false);
      if (provider is EmployeeProvider) {
        provider.clearData();
      } else if (provider is AttendanceProvider) {
        provider.clearData();
      } else if (provider is HRProvider) {
        provider.clearData();
      } else if (provider is AdminProvider) {
        provider.clearData();
      } else if (provider is EODProvider) {
        provider.clearData();
      } else if (provider is AnnouncementProvider) {
        provider.clearData();
      } else if (provider is LeaveRequestProvider) {
        provider.clearData();
      } else if (provider is PayrollProvider) {
        provider.clearData();
      } else if (provider is MessageProvider) {
        provider.clearData();
      } else if (provider is MessagingProvider) {
        provider.clearData();
      }
    } catch (e) {
      debugPrint('Error clearing provider $T: $e');
    }
  }
}
