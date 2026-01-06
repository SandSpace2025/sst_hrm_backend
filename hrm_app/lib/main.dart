import 'package:flutter/material.dart';
import 'package:hrm_app/core/theme/app_theme.dart';
import 'package:hive_flutter/adapters.dart';
import 'package:hrm_app/core/services/notification_service.dart';
import 'package:hrm_app/core/services/notification_navigation_service.dart';
import 'package:hrm_app/core/errors/global_error_handler.dart';
import 'package:hrm_app/presentation/providers/admin_provider.dart';
import 'package:hrm_app/presentation/providers/announcement_provider.dart';
import 'package:hrm_app/presentation/providers/auth_provider.dart';
import 'package:hrm_app/presentation/providers/employee_provider.dart';
import 'package:hrm_app/presentation/providers/eod_provider.dart';
import 'package:hrm_app/presentation/providers/hr_provider.dart';

import 'package:hrm_app/presentation/providers/leave_request_provider.dart';
import 'package:hrm_app/presentation/providers/message_provider.dart';
import 'package:hrm_app/presentation/providers/messaging_provider.dart';
import 'package:hrm_app/presentation/providers/messaging_websocket_provider.dart';
import 'package:hrm_app/presentation/providers/network_provider.dart';
import 'package:hrm_app/presentation/providers/payroll_provider.dart';
import 'package:hrm_app/presentation/providers/websocket_provider.dart';
import 'package:hrm_app/presentation/providers/attendance_provider.dart';
import 'package:hrm_app/core/services/websocket_service.dart';
import 'package:hrm_app/core/models/conversation.dart';
import 'package:hrm_app/presentation/screens/splash_screen.dart';
import 'package:hrm_app/presentation/screens/messaging/contacts_screen.dart';
import 'package:hrm_app/presentation/screens/messaging/conversation_screen.dart';
import 'package:hrm_app/presentation/providers/login_controller.dart';
import 'package:provider/provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  GlobalErrorHandler.initialize();

  await Hive.initFlutter();

  await Hive.openBox('profileCache');
  await Hive.openBox('chatCache');
  await Hive.openBox('announcementCache');
  await Hive.openBox('dashboardCache');
  await Hive.openBox('messageCache');
  await Hive.openBox('payrollCache');
  await Hive.openBox('payslipCache');

  await Hive.openBox('employee_cache_box');
  await Hive.openBox('admin_dashboard_cache');

  await NotificationService().initialize().catchError((e) {});

  _setupNotificationNavigation();

  runApp(const MyApp());
}

void _setupNotificationNavigation() {}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final navigationService = NotificationNavigationService();
      navigationService.setNavigatorKey(navigatorKey);

      NotificationService.setGlobalNavigatorKey(navigatorKey);
    });

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => NetworkProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => AdminProvider()),
        ChangeNotifierProvider(create: (_) => HRProvider()),
        ChangeNotifierProvider(create: (_) => EmployeeProvider()),
        ChangeNotifierProvider(create: (_) => EODProvider()),
        ChangeNotifierProvider(create: (_) => PayrollProvider()),
        ChangeNotifierProvider(create: (_) => AnnouncementProvider()),
        ChangeNotifierProvider(create: (_) => LeaveRequestProvider()),
        ChangeNotifierProvider(create: (_) => MessageProvider()),
        ChangeNotifierProvider(create: (_) => MessagingProvider()),
        ChangeNotifierProvider(
          create: (_) => MessagingWebSocketProvider(
            messagingProvider: MessagingProvider(),
            webSocketService: WebSocketService(),
          ),
        ),
        ChangeNotifierProvider(create: (_) => WebSocketProvider()),
        ChangeNotifierProvider(create: (_) => AttendanceProvider()),
        ChangeNotifierProvider(create: (_) => LoginController()),
      ],
      child: MaterialApp(
        navigatorKey: navigatorKey,
        debugShowCheckedModeBanner: false,
        title: 'Empiqo',
        theme: AppTheme.lightTheme,
        home: const SplashScreen(),
        routes: {
          '/messaging': (context) => const ContactsScreen(),
          '/conversation': (context) {
            final conversation =
                ModalRoute.of(context)!.settings.arguments as Conversation;
            return ConversationScreen(conversation: conversation);
          },
        },
      ),
    );
  }
}
