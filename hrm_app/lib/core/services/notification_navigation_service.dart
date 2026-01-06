import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:jwt_decode/jwt_decode.dart';
import 'dart:convert';
import '../../presentation/widgets/common/announcement_preview_dialog.dart';
import '../../core/models/conversation.dart';
import '../../presentation/providers/messaging_provider.dart';
import '../../presentation/providers/auth_provider.dart';
import '../../presentation/widgets/employee_messaging/employee_whatsapp_chat_screen.dart';
import '../../presentation/widgets/hr_dashboard/messaging/hr_whatsapp_chat_screen.dart';
import '../../presentation/widgets/admin_dashboard/messaging/admin_whatsapp_chat_screen.dart';
import '../../presentation/screens/employee/employee_payslip_screen.dart';
import '../../presentation/screens/hr/hr_manage_employee_screen.dart';
import '../../presentation/screens/employee/employee_leave_screen.dart';
import '../../presentation/screens/hr/hr_leave_request_screen.dart';

class NotificationNavigationService {
  static final NotificationNavigationService _instance =
      NotificationNavigationService._internal();
  factory NotificationNavigationService() => _instance;
  NotificationNavigationService._internal();

  GlobalKey<NavigatorState>? _navigatorKey;

  GlobalKey<NavigatorState>? get navigatorKey => _navigatorKey;

  void setNavigatorKey(GlobalKey<NavigatorState> navigatorKey) {
    _navigatorKey = navigatorKey;
  }

  void testAnnouncementPreview() {
    if (_navigatorKey?.currentContext != null) {
      final testData = {
        'type': 'announcement',
        'title': 'Test Announcement',
        'message':
            'This is a test announcement to verify the popup is working correctly.',
        'priority': 'high',
        'audience': 'All Employees',
        'createdBy': {'fullName': 'Test Admin'},
        'createdAt': DateTime.now().toIso8601String(),
        'announcementId': 'test-direct-123',
      };
      _showAnnouncementPreview(_navigatorKey!.currentContext!, testData);
    } else {}
  }

  Map<String, dynamic>? _pendingNavigationData;

  void handleNotificationTap(String payload) {
    debugPrint('DEBUG: handleNotificationTap called with payload: $payload');
    try {
      final Map<String, dynamic> navigationData = _parsePayload(payload);
      debugPrint('DEBUG: Parsed navigation data: $navigationData');

      // Check if we have context and auth is ready
      if (_navigatorKey?.currentContext != null) {
        final context = _navigatorKey!.currentContext!;

        // Check for AuthProvider availability and state
        bool isAuthReady = false;
        try {
          final authProvider = Provider.of<AuthProvider>(
            context,
            listen: false,
          );
          isAuthReady = authProvider.isAuth && authProvider.role != null;
        } catch (e) {
          // Provider might not be available yet
        }

        if (context.mounted && isAuthReady) {
          navigateToContent(context, navigationData);
        } else {
          // Store for later if not ready
          print(
            "⚠️ NotificationNavigationService: Context or Auth not ready, queuing navigation data",
          );
          _pendingNavigationData = navigationData;

          // Still try post frame callback just in case it's a transparency/mounting issue vs auth issue
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_navigatorKey?.currentContext != null &&
                _navigatorKey!.currentContext!.mounted) {
              final authProvider = Provider.of<AuthProvider>(
                _navigatorKey!.currentContext!,
                listen: false,
              );
              if (authProvider.isAuth && authProvider.role != null) {
                navigateToContent(
                  _navigatorKey!.currentContext!,
                  navigationData,
                );
                _pendingNavigationData = null; // Clear if successful
              }
            }
          });
        }
      } else {
        // No navigator key yet, definitely queue it
        print(
          "⚠️ NotificationNavigationService: No Navigator Key, queuing navigation data",
        );
        _pendingNavigationData = navigationData;
      }
    } catch (e) {
      debugPrint("Error handling notification tap: $e");
    }
  }

  void consumePendingNavigation(BuildContext context) {
    if (_pendingNavigationData != null) {
      debugPrint(
        "🚀 NotificationNavigationService: Consuming pending navigation data",
      );
      // Add a small delay to ensure the dashboard is fully rendered and providers are attached
      Future.delayed(const Duration(milliseconds: 500), () {
        if (context.mounted) {
          navigateToContent(context, _pendingNavigationData!);
          _pendingNavigationData = null;
        }
      });
    }
  }

  Map<String, dynamic> _parsePayload(String payload) {
    try {
      if (payload.startsWith('{') && payload.endsWith('}')) {
        return json.decode(payload) as Map<String, dynamic>;
      }
      return {'type': 'unknown', 'payload': payload};
    } catch (e) {
      debugPrint("Error parsing payload: $e");
      return {'type': 'unknown', 'payload': payload};
    }
  }

  void navigateToContent(BuildContext context, Map<String, dynamic> data) {
    try {
      String type = data['type'] ?? '';

      // FORCE OVERRIDE: If leaveRequest data is present, it MUST be a leave request
      if (data.containsKey('leaveRequest')) {
        debugPrint(
          'DEBUG: Detected leaveRequest data, overriding type to leave_request',
        );
        type = 'leave_request';
      }

      switch (type) {
        case 'message':
          _navigateToChat(context, data).catchError((e) {
            _navigateToGeneralMessaging(context);
          });
          break;
        case 'announcement':
          _showAnnouncementPreview(context, data);
          break;
        case 'payslip_approved':
        case 'payslip_rejected':
          _navigateToPayslipRequests(context);
          break;
        case 'payslip_request_created':
          _navigateToPayslipRequests(context);
          break;
        case 'leave_request':
          debugPrint('DEBUG: Navigating to Leave Requests');
          debugPrint('DEBUG: Payload: $data');
          _navigateToLeaveRequests(context);
          break;
        case 'system':
          debugPrint('DEBUG: Navigating to System');
          _navigateToGeneralMessaging(context);
          break;
        default:
          if (data.containsKey('messageId') || data.containsKey('senderId')) {
            _navigateToChat(context, data).catchError((e) {
              _navigateToGeneralMessaging(context);
            });
          } else if (data.containsKey('title') ||
              data.containsKey('announcementId')) {
            _showAnnouncementPreview(context, data);
          } else {
            _navigateToGeneralMessaging(context);
          }
          break;
      }
    } catch (e) {
      _navigateToGeneralMessaging(context);
    }
  }

  Future<void> _navigateToChat(
    BuildContext context,
    Map<String, dynamic> data,
  ) async {
    try {
      final conversationId = data['conversationId'] ?? '';
      final senderName =
          data['senderName'] ??
          data['sender']?['name'] ??
          data['sender']?['fullName'] ??
          'Chat';
      final sender = data['sender'];

      final messagingProvider = Provider.of<MessagingProvider>(
        context,
        listen: false,
      );
      final authProvider = Provider.of<AuthProvider>(context, listen: false);

      try {
        if (authProvider.token != null) {
          messagingProvider.initializeMessaging(authProvider.token!);
        } else {}
      } catch (e) {}

      final currentUserRole = authProvider.role?.toLowerCase() ?? '';

      String? otherUserId =
          data['senderId']?.toString() ??
          data['userId']?.toString() ??
          data['sender']?['userId']?.toString() ??
          data['sender']?['id']?.toString() ??
          data['sender']?['_id']?.toString();

      String? otherUserName =
          data['senderName']?.toString() ??
          data['userName']?.toString() ??
          data['sender']?['name']?.toString() ??
          data['sender']?['fullName']?.toString() ??
          data['sender']?['full_name']?.toString() ??
          senderName;

      String? otherUserType =
          data['senderType']?.toString().toLowerCase() ??
          data['userType']?.toString().toLowerCase() ??
          data['sender']?['userType']?.toString().toLowerCase() ??
          data['sender']?['role']?.toString().toLowerCase() ??
          data['sender']?['user_type']?.toString().toLowerCase() ??
          'employee';

      if (conversationId is String &&
          conversationId.isNotEmpty &&
          otherUserId == null) {
        String? currentUserId;
        try {
          if (authProvider.token != null) {
            final jwt = Jwt.parseJwt(authProvider.token!);
            currentUserId = (jwt['id'] ?? jwt['userId'] ?? '').toString();
          }
        } catch (e) {}

        Conversation? targetConversation;
        try {
          await messagingProvider.loadConversations();

          for (final conversation in messagingProvider.conversations) {
            if (conversation.conversationId == conversationId) {
              targetConversation = conversation;
              break;
            }
          }
        } catch (e) {}

        if (targetConversation == null) {
          try {
            await messagingProvider.getConversation(conversationId);
            targetConversation = messagingProvider.currentConversation;
          } catch (e) {}
        }

        if (targetConversation != null &&
            targetConversation.participants.isNotEmpty) {
          for (final participant in targetConversation.participants) {
            if (currentUserId != null && participant.userId != currentUserId) {
              otherUserId = participant.userId;
              otherUserName = participant.name ?? otherUserName ?? senderName;
              otherUserType = participant.userType.toLowerCase();

              break;
            } else if (currentUserId == null) {
              if (sender is Map && sender['userId'] != null) {
                final senderId = sender['userId'].toString();
                if (participant.userId != senderId) {
                  otherUserId = participant.userId;
                  otherUserName =
                      participant.name ?? otherUserName ?? senderName;
                  otherUserType = participant.userType.toLowerCase();

                  break;
                }
              } else {
                if (otherUserId == null) {
                  otherUserId = participant.userId;
                  otherUserName =
                      participant.name ?? otherUserName ?? senderName;
                  otherUserType = participant.userType.toLowerCase();

                  break;
                }
              }
            }
          }
        }
      }

      if (otherUserId == null || otherUserId.isEmpty) {
        _navigateToGeneralMessaging(context);
        return;
      }

      if (otherUserName == null || otherUserName.isEmpty) {
        otherUserName = 'Chat User';
      }

      if (otherUserType == null || otherUserType.isEmpty) {
        otherUserType = 'employee';
      }

      if (!context.mounted) {
        _navigateToGeneralMessaging(context);
        return;
      }

      try {
        if (currentUserRole == 'employee') {
          Navigator.push(
            context,
            PageRouteBuilder(
              pageBuilder: (context, animation, secondaryAnimation) =>
                  EmployeeWhatsAppChatScreen(
                    userId: otherUserId!,
                    userName: otherUserName!,
                    userType: otherUserType!,
                    fromNotification: true,
                  ),
              transitionsBuilder:
                  (context, animation, secondaryAnimation, child) {
                    const begin = Offset(1.0, 0.0);
                    const end = Offset.zero;
                    const curve = Curves.easeOutCubic;
                    final tween = Tween(
                      begin: begin,
                      end: end,
                    ).chain(CurveTween(curve: curve));
                    final offsetAnimation = animation.drive(tween);
                    return SlideTransition(
                      position: offsetAnimation,
                      child: child,
                    );
                  },
              transitionDuration: const Duration(milliseconds: 300),
            ),
          ).catchError((e) {
            _navigateToGeneralMessaging(context);
          });
        } else if (currentUserRole == 'hr') {
          Navigator.push(
            context,
            PageRouteBuilder(
              pageBuilder: (context, animation, secondaryAnimation) =>
                  HRWhatsAppChatScreen(
                    userId: otherUserId!,
                    userName: otherUserName!,
                    userType: otherUserType!,
                    fromNotification: true,
                  ),
              transitionsBuilder:
                  (context, animation, secondaryAnimation, child) {
                    const begin = Offset(1.0, 0.0);
                    const end = Offset.zero;
                    const curve = Curves.easeOutCubic;
                    final tween = Tween(
                      begin: begin,
                      end: end,
                    ).chain(CurveTween(curve: curve));
                    final offsetAnimation = animation.drive(tween);
                    return SlideTransition(
                      position: offsetAnimation,
                      child: child,
                    );
                  },
              transitionDuration: const Duration(milliseconds: 300),
            ),
          ).catchError((e) {
            _navigateToGeneralMessaging(context);
          });
        } else if (currentUserRole == 'admin') {
          Navigator.push(
            context,
            PageRouteBuilder(
              pageBuilder: (context, animation, secondaryAnimation) =>
                  AdminWhatsAppChatScreen(
                    userId: otherUserId!,
                    userName: otherUserName!,
                    userType: otherUserType!,
                    fromNotification: true,
                  ),
              transitionsBuilder:
                  (context, animation, secondaryAnimation, child) {
                    const begin = Offset(1.0, 0.0);
                    const end = Offset.zero;
                    const curve = Curves.easeOutCubic;
                    final tween = Tween(
                      begin: begin,
                      end: end,
                    ).chain(CurveTween(curve: curve));
                    final offsetAnimation = animation.drive(tween);
                    return SlideTransition(
                      position: offsetAnimation,
                      child: child,
                    );
                  },
              transitionDuration: const Duration(milliseconds: 300),
            ),
          ).catchError((e) {
            _navigateToGeneralMessaging(context);
          });
        } else {
          _navigateToGeneralMessaging(context);
        }
      } catch (e) {
        _navigateToGeneralMessaging(context);
      }
    } catch (e) {
      try {
        if (context.mounted) {
          _navigateToGeneralMessaging(context);
        }
      } catch (e2) {}
    }
  }

  void _showAnnouncementPreview(
    BuildContext context,
    Map<String, dynamic> data,
  ) {
    try {
      if (!context.mounted) {
        return;
      }

      final announcementData = {
        'title': data['title'] ?? 'Announcement',
        'message': data['message'] ?? data['content'] ?? '',
        'priority': data['priority'] ?? 'normal',
        'audience': data['audience'] ?? 'All',
        'createdBy': data['createdBy'] is Map
            ? data['createdBy']
            : (data['author'] is Map
                  ? data['author']
                  : {
                      'fullName':
                          data['createdBy']?.toString() ??
                          data['author']?.toString() ??
                          'Unknown',
                    }),
        'createdAt':
            data['createdAt'] ??
            data['timestamp'] ??
            DateTime.now().toIso8601String(),
        'announcementId': data['announcementId'] ?? data['id'] ?? 'unknown',
      };

      showAnnouncementPreview(context, announcementData);
    } catch (e) {}
  }

  void _navigateToGeneralMessaging(BuildContext context) {
    try {
      Navigator.pushNamed(context, '/messaging');
    } catch (e) {}
  }

  void _navigateToPayslipRequests(BuildContext context) {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final role = authProvider.role?.toLowerCase() ?? '';

      if (role == 'employee') {
        _navigateToEmployeePayslipScreen(context);
      } else if (role == 'hr' || role == 'admin') {
        _navigateToHRPayslipRequests(context);
      }
    } catch (e) {}
  }

  void _navigateToEmployeePayslipScreen(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 100), () {
        try {
          if (!context.mounted) {
            return;
          }

          final employeePayslipScreen = const EmployeePayslipScreen(
            initialTabIndex: 2,
          );
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => employeePayslipScreen,
              settings: const RouteSettings(name: '/employee-payslip'),
            ),
          ).catchError((error) {});
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Payslip has been approved! Check your payslip requests.',
                ),
                duration: Duration(seconds: 3),
              ),
            );
          }
        }
      });
    });
  }

  void _navigateToHRPayslipRequests(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 100), () {
        try {
          if (!context.mounted) {
            return;
          }

          final hrManageEmployeeScreen = const HRManageEmployeeScreen(
            initialTabIndex: 1,
          );
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => hrManageEmployeeScreen,
              settings: const RouteSettings(name: '/hr-manage-employees'),
            ),
          ).catchError((error) {});
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'New payslip request received! Check your payslip requests.',
                ),
                duration: Duration(seconds: 3),
              ),
            );
          }
        }
      });
    });
  }

  void _navigateToLeaveRequests(BuildContext context) {
    try {
      debugPrint('DEBUG: _navigateToLeaveRequests called');
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final role = authProvider.role?.toLowerCase() ?? '';
      debugPrint('DEBUG: Role is $role');

      WidgetsBinding.instance.addPostFrameCallback((_) {
        try {
          if (!context.mounted) {
            debugPrint(
              'DEBUG: Context not mounted in _navigateToLeaveRequests',
            );
            return;
          }

          if (role == 'employee') {
            debugPrint('DEBUG: Pushing EmployeeLeaveScreen');
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    const EmployeeLeaveScreen(initialTabIndex: 1),
                settings: const RouteSettings(name: '/employee-leave'),
              ),
            );
          } else if (role == 'hr' || role == 'admin') {
            debugPrint('DEBUG: Pushing HRLeaveRequestScreen');
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    const HRLeaveRequestScreen(initialTabIndex: 1),
                settings: const RouteSettings(name: '/hr-leave-requests'),
              ),
            );
          } else {
            debugPrint('DEBUG: Role mismatch, doing nothing');
          }
        } catch (e) {
          debugPrint("Error navigating to leave requests: $e");
        }
      });
    } catch (e) {
      debugPrint("Error in _navigateToLeaveRequests: $e");
    }
  }
}
