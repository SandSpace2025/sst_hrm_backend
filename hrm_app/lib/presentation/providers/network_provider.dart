import 'dart:async';
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:provider/provider.dart';
import 'package:hrm_app/core/services/cache_service.dart';
import 'package:hrm_app/core/services/hive_cache_service.dart';
import 'package:hrm_app/core/utils/snackbar_utils.dart';
import 'package:hrm_app/presentation/providers/auth_provider.dart';
import 'package:hrm_app/presentation/providers/admin_provider.dart';
import 'package:hrm_app/presentation/providers/hr_provider.dart';
import 'package:hrm_app/presentation/providers/employee_provider.dart';
import 'package:hrm_app/main.dart';
import 'package:hrm_app/core/services/logger_service.dart';

class NetworkProvider extends ChangeNotifier {
  bool _isOnline = true;
  StreamSubscription<List<ConnectivityResult>>? _subscription;
  bool _isInitialized = false;
  Connectivity? _connectivity;
  Timer? _initTimer;
  bool _wasOffline = false; // Track if we were previously offline

  bool get isOnline => _isOnline;

  NetworkProvider() {
    Future.microtask(() => _initialize());
  }

  Future<void> _initialize() async {
    if (_isInitialized) return;
    LoggerService.debug('Initializing...', tag: 'NetworkProvider');

    try {
      await Future.delayed(
        const Duration(milliseconds: 500),
      ); // Ensure platform channel is ready
      try {
        _connectivity = Connectivity();
      } catch (e) {
        LoggerService.error(
          'Failed to instantiate Connectivity',
          error: e,
          tag: 'NetworkProvider',
        );
        _isOnline = false;
        _isInitialized = true;
        notifyListeners();
        return;
      }

      try {
        _subscription = _connectivity!.onConnectivityChanged.listen(
          (results) {
            LoggerService.debug(
              'Connectivity changed to $results',
              tag: 'NetworkProvider',
            );
            try {
              final previousState = _isOnline;

              _isOnline =
                  results.isNotEmpty &&
                  results.any((result) => result != ConnectivityResult.none);

              if (_isOnline != previousState) {
                final context = MyApp.navigatorKey.currentContext;
                if (context != null) {
                  if (!_isOnline) {
                    SnackBarUtils.showWarning(context, '⚠️ Connection Lost');
                  } else {
                    SnackBarUtils.showSuccess(context, '✅ Back Online');
                    _handleNetworkRestored();
                  }
                }
                notifyListeners();
              }
            } catch (e) {}
          },
          onError: (error) {
            try {
              if (_isOnline) {
                _isOnline = false;
                notifyListeners();
              }
            } catch (e) {}
          },
          cancelOnError: false,
        );
      } catch (e) {
        _isOnline = false;
        _isInitialized = true;
        notifyListeners();
        return;
      }

      _checkInitialConnection();
      _isInitialized = true;
    } catch (e) {
      // Don't mark as offline just because initialization had a hiccup
      // unless we know for sure (which we don't here)
      LoggerService.error('Init error', error: e, tag: 'NetworkProvider');
      _isInitialized = true;
      notifyListeners();
    }
  }

  Future<void> _checkInitialConnection() async {
    try {
      final connectivity = _connectivity ?? Connectivity();
      final results = await connectivity.checkConnectivity();

      _isOnline =
          results.isNotEmpty &&
          results.any((result) => result != ConnectivityResult.none);
      notifyListeners();
    } catch (e) {
      // Optimistic: Assume online if check fails unless explicitly told otherwise
      // This helps on some platforms/emulators where the check might throw initially
      LoggerService.error(
        'Initial check error',
        error: e,
        tag: 'NetworkProvider',
      );
      // Keep previous state or default to true if unsure, rather than forcing false
      notifyListeners();
    }
  }

  Future<bool> checkConnection() async {
    try {
      final connectivity = _connectivity ?? Connectivity();
      final results = await connectivity.checkConnectivity();

      _isOnline =
          results.isNotEmpty &&
          results.any((result) => result != ConnectivityResult.none);
      notifyListeners();
      return _isOnline;
    } catch (e) {
      _isOnline = false;
      notifyListeners();
      return false;
    }
  }

  /// Handle network restoration - clear cache and refresh all data
  Future<void> _handleNetworkRestored() async {
    try {
      LoggerService.debug(
        'Network restored - clearing cache and refreshing data',
        tag: 'NetworkProvider',
      );

      // Clear all cache from both cache services
      await Future.wait([
        CacheService.clearAllCache(),
        HiveCacheService.clearAllCache(),
      ]);

      LoggerService.debug('All cache cleared', tag: 'NetworkProvider');

      // Get the global navigator key to access providers
      final navigatorKey = MyApp.navigatorKey;
      if (navigatorKey.currentContext != null) {
        final context = navigatorKey.currentContext!;

        // Get auth provider to check if user is logged in and get token/role
        final authProvider = Provider.of<AuthProvider>(context, listen: false);

        if (authProvider.isAuth && authProvider.token != null) {
          final token =
              authProvider.token!; // Safe to use ! since we checked != null
          final role = authProvider.role;

          LoggerService.debug(
            'User is authenticated, refreshing data for role: $role',
            tag: 'NetworkProvider',
          );

          // Refresh data based on user role with forceRefresh=true
          // This ensures we hit APIs instead of using cached data
          try {
            switch (role?.toLowerCase()) {
              case 'admin':
                final adminProvider = Provider.of<AdminProvider>(
                  context,
                  listen: false,
                );
                await adminProvider.refreshAllData(token, forceRefresh: true);
                LoggerService.debug(
                  'Admin data refreshed',
                  tag: 'NetworkProvider',
                );
                break;
              case 'hr':
                final hrProvider = Provider.of<HRProvider>(
                  context,
                  listen: false,
                );
                await hrProvider.refreshAllData(token, forceRefresh: true);
                LoggerService.debug(
                  'HR data refreshed',
                  tag: 'NetworkProvider',
                );
                break;
              case 'employee':
                final employeeProvider = Provider.of<EmployeeProvider>(
                  context,
                  listen: false,
                );
                await employeeProvider.refreshAllData(
                  token,
                  forceRefresh: true,
                );
                LoggerService.debug(
                  'Employee data refreshed',
                  tag: 'NetworkProvider',
                );
                break;
              default:
                LoggerService.warning(
                  'Unknown role: $role',
                  tag: 'NetworkProvider',
                );
            }
          } catch (e) {
            LoggerService.error(
              'Error refreshing data for role $role',
              error: e,
              tag: 'NetworkProvider',
            );
          }
        } else {
          LoggerService.debug(
            'User not authenticated, skipping data refresh',
            tag: 'NetworkProvider',
          );
        }
      } else {
        LoggerService.debug(
          'Navigator key not available, cannot refresh providers',
          tag: 'NetworkProvider',
        );
      }
    } catch (e) {
      LoggerService.error(
        'Error handling network restoration',
        error: e,
        tag: 'NetworkProvider',
      );
    }
  }

  @override
  void dispose() {
    _initTimer?.cancel();
    _subscription?.cancel();
    super.dispose();
  }
}
