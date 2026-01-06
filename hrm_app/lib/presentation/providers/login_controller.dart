import 'package:flutter/material.dart';
import 'package:provider/provider.dart' as legacy_provider;
import 'package:hrm_app/presentation/providers/auth_provider.dart';
import 'package:hrm_app/presentation/screens/admin/admin_dashboard_screen.dart';
import 'package:hrm_app/presentation/screens/employee/employee_dashboard_screen.dart';
import 'package:hrm_app/presentation/screens/hr/hr_dashboard_screen.dart';
import 'package:hrm_app/presentation/screens/auth/login_screen.dart';

class LoginController extends ChangeNotifier {
  bool _isPasswordVisible = false;
  bool _isLoading = false;
  String? _error;

  bool get isPasswordVisible => _isPasswordVisible;
  bool get isLoading => _isLoading;
  String? get error => _error;

  void togglePasswordVisibility() {
    _isPasswordVisible = !_isPasswordVisible;
    notifyListeners();
  }

  Future<void> login({
    required String email,
    required String password,
    required BuildContext context,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final authProvider = legacy_provider.Provider.of<AuthProvider>(
        context,
        listen: false,
      );
      final role = await authProvider.login(email, password, context);

      _isLoading = false;
      notifyListeners();

      if (context.mounted) {
        _navigate(role, context);
      }
    } catch (e) {
      _isLoading = false;
      _error = e.toString();
      notifyListeners();
    }
  }

  void _navigate(String? role, BuildContext context) {
    Widget destination;
    switch (role) {
      case 'admin':
        destination = const AdminDashboardScreen();
        break;
      case 'hr':
        destination = const HRDashboardScreen();
        break;
      case 'employee':
        destination = const EmployeeDashboardScreen();
        break;
      default:
        destination = const LoginScreen();
    }

    Navigator.of(
      context,
    ).pushReplacement(MaterialPageRoute(builder: (_) => destination));
  }
}
