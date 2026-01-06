import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:hrm_app/presentation/providers/auth_provider.dart';
import 'package:hrm_app/presentation/screens/admin/admin_dashboard_screen.dart';
import 'package:hrm_app/presentation/screens/auth/login_screen.dart';
import 'package:hrm_app/presentation/screens/employee/employee_dashboard_screen.dart';
import 'package:hrm_app/presentation/screens/hr/hr_dashboard_screen.dart';
import 'package:hrm_app/core/theme/app_colors.dart';

const Duration _kNavigationDelay = Duration(milliseconds: 3225);

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkAuthStatusAndNavigate();
  }

  Future<void> _checkAuthStatusAndNavigate() async {
    final delayFuture = Future.delayed(_kNavigationDelay);
    String? role;

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      role = await authProvider.tryAutoLogin(context);
    } catch (e) {
      // Ignore error, role remains null
    }

    await delayFuture;

    if (mounted) {
      await _navigateToDashboard(role);
    }
  }

  Future<void> _navigateToDashboard(String? role) async {
    if (!mounted) return;

    Widget destination;
    if (role != null) {
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
    } else {
      destination = const LoginScreen();
    }

    if (mounted) {
      await Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => destination,
          transitionsBuilder: (_, animation, __, child) {
            return FadeTransition(opacity: animation, child: child);
          },
          transitionDuration: const Duration(milliseconds: 500),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: Center(
        child: Image.asset(
          'assets/images/Splash-Screen-1.gif',
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}
