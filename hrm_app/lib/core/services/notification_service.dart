import 'dart:convert';
import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../../presentation/widgets/common/announcement_preview_dialog.dart';
import 'notification_navigation_service.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint("Handling a background message: ${message.messageId}");
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  bool _isSoundEnabled = true;
  bool _isVibrationEnabled = true;

  DateTime? _lastNotificationTime;
  String? _lastNotificationContent;

  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static GlobalKey<NavigatorState>? _globalNavigatorKey;

  static void setGlobalNavigatorKey(GlobalKey<NavigatorState> navigatorKey) {
    _globalNavigatorKey = navigatorKey;
  }

  static GlobalKey<NavigatorState>? get globalNavigatorKey =>
      _globalNavigatorKey;

  bool get isSoundEnabled => _isSoundEnabled;
  bool get isVibrationEnabled => _isVibrationEnabled;

  Future<void> initialize() async {
    try {
      // Initialize Firebase Messaging
      try {
        await Firebase.initializeApp();
        FirebaseMessaging.onBackgroundMessage(
          _firebaseMessagingBackgroundHandler,
        );

        FirebaseMessaging messaging = FirebaseMessaging.instance;

        NotificationSettings settings = await messaging.requestPermission(
          alert: true,
          announcement: false,
          badge: true,
          carPlay: false,
          criticalAlert: false,
          provisional: false,
          sound: true,
        );

        if (settings.authorizationStatus == AuthorizationStatus.authorized) {
          debugPrint('User granted permission');
        } else if (settings.authorizationStatus ==
            AuthorizationStatus.provisional) {
          debugPrint('User granted provisional permission');
        } else {
          debugPrint('User declined or has not accepted permission');
        }

        // Foreground message handler
        FirebaseMessaging.onMessage.listen((RemoteMessage message) {
          RemoteNotification? notification = message.notification;
          AndroidNotification? android = message.notification?.android;

          // If `onMessage` is triggered with a notification, construct our own
          // local notification to show it to the user.
          if (notification != null && android != null) {
            showNotification(
              title: notification.title ?? '',
              body: notification.body ?? '',
              data: message.data, // Pass data payload
            );
          }
        });

        // Background message handler (opened app)
        FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
          debugPrint('A new onMessageOpenedApp event was published!');
          if (message.data.isNotEmpty) {
            final navigationService = NotificationNavigationService();
            navigationService.handleNotificationTap(jsonEncode(message.data));
          }
        });

        // Check initial message (Terminated state)
        FirebaseMessaging.instance.getInitialMessage().then((
          RemoteMessage? message,
        ) {
          if (message != null && message.data.isNotEmpty) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              final navigationService = NotificationNavigationService();
              navigationService.handleNotificationTap(jsonEncode(message.data));
            });
          }
        });
      } catch (firebaseError) {
        debugPrint("Firebase Messaging initialization failed: $firebaseError");
      }

      // Initialize Local Notifications
      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/launcher_icon');

      const DarwinInitializationSettings initializationSettingsIOS =
          DarwinInitializationSettings(
            requestAlertPermission: true,
            requestBadgePermission: true,
            requestSoundPermission: true,
          );

      const InitializationSettings initializationSettings =
          InitializationSettings(
            android: initializationSettingsAndroid,
            iOS: initializationSettingsIOS,
          );

      await _flutterLocalNotificationsPlugin.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: _onNotificationTapped,
      );

      // Create high importance channel for Android
      final androidPlugin = _flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();

      if (androidPlugin != null) {
        await androidPlugin.createNotificationChannel(
          const AndroidNotificationChannel(
            'hrm_notifications_v2', // id
            'Empiqo Notifications', // title
            description: 'Notifications from Empiqo', // description
            importance: Importance.max,
          ),
        );
      }
    } catch (e) {
      debugPrint("Error initializing NotificationService: $e");
    }
  }

  Future<String?> getFcmToken() async {
    try {
      return await FirebaseMessaging.instance.getToken();
    } catch (e) {
      return null;
    }
  }

  void _onNotificationTapped(NotificationResponse response) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_globalNavigatorKey?.currentContext == null) {
        return;
      }

      if (response.payload != null && response.payload!.isNotEmpty) {
        try {
          final Map<String, dynamic> data = jsonDecode(response.payload!);

          if (data['type'] == 'announcement' ||
              (data.containsKey('title') && data.containsKey('message'))) {
            _showAnnouncementPopupDirectly(data);
          } else {
            final navigationService = NotificationNavigationService();
            navigationService.handleNotificationTap(response.payload!);
          }
        } catch (e) {
          try {
            final navigationService = NotificationNavigationService();
            navigationService.handleNotificationTap(response.payload!);
          } catch (e2) {}
        }
      }
    });
  }

  void _showAnnouncementPopupDirectly(Map<String, dynamic> data) {
    try {
      if (_globalNavigatorKey?.currentContext == null) {
        return;
      }

      final context = _globalNavigatorKey!.currentContext!;

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

  String _createNavigationPayload(Map<String, dynamic> data) {
    try {
      String notificationType = data['type'] ?? 'message';

      if (data.containsKey('title') &&
          data.containsKey('message') &&
          !data.containsKey('type')) {
        notificationType = 'announcement';
      } else if (data.containsKey('leaveRequest') &&
          !data.containsKey('type')) {
        notificationType = 'leave_request';
      } else if ((data.containsKey('messageId') ||
              data.containsKey('senderId')) &&
          !data.containsKey('type')) {
        notificationType = 'message';
      } else if ((data.containsKey('systemAlert') ||
              data.containsKey('system')) &&
          !data.containsKey('type')) {
        notificationType = 'system';
      }

      final Map<String, dynamic> navigationData = {
        'type': notificationType,
        'timestamp': DateTime.now().toIso8601String(),
      };

      if (notificationType == 'message') {
        final sender = data['sender'];
        final senderId =
            data['senderId'] ??
            data['sender']?['_id'] ??
            data['sender']?['userId'] ??
            data['sender']?['id'];
        final senderName =
            data['senderName'] ??
            data['sender']?['name'] ??
            data['sender']?['fullName'];
        final senderType =
            data['senderType'] ??
            data['sender']?['userType'] ??
            data['sender']?['role'] ??
            data['userType'];

        navigationData.addAll({
          'messageId': data['messageId'],
          'conversationId': data['conversationId'],
          'senderId': senderId,
          'receiverId': data['receiver']?['_id'] ?? data['receiver']?['userId'],
          'senderName': senderName,
          'senderType': senderType,
          'messageType': data['messageType'],
          'type': 'message',
        });

        if (sender is Map) {
          navigationData['sender'] = sender;
        }
      } else if (notificationType == 'announcement') {
        navigationData.addAll({
          'title': data['title'],
          'message': data['message'] ?? data['content'],
          'priority': data['priority'] ?? 'normal',
          'audience': data['audience'] ?? 'All',
          'createdBy': data['createdBy'] ?? data['author'],
          'createdAt': data['createdAt'] ?? data['timestamp'],
          'announcementId': data['announcementId'] ?? data['id'],
        });
      } else if (notificationType == 'payslip_request_created' ||
          notificationType == 'payslip_approved' ||
          notificationType == 'payslip_rejected' ||
          notificationType == 'leave_request') {
        // Preserve all data for these specific types
        navigationData.addAll(data);
        // ensure type is correct in case it was missing in data but set in notificationType
        navigationData['type'] = notificationType;
      } else {
        // For unknown types, also preserve all data
        navigationData.addAll(data);
        navigationData['type'] = notificationType;
      }

      return jsonEncode(navigationData);
    } catch (e) {
      try {
        return jsonEncode(data);
      } catch (e2) {
        return '{"type":"unknown"}';
      }
    }
  }

  Future<void> showNotification({
    required String title,
    required String body,
    String? type,
    Map<String, dynamic>? data,
    int? badgeCount,
  }) async {
    try {
      final now = DateTime.now();
      if (_lastNotificationTime != null &&
          _lastNotificationContent == body &&
          now.difference(_lastNotificationTime!).inMilliseconds < 1000) {
        return;
      }

      _lastNotificationTime = now;
      _lastNotificationContent = body;

      // Create a mutable copy of data or new map
      Map<String, dynamic> enrichedData = data != null
          ? Map<String, dynamic>.from(data)
          : {};

      // If type is not in data, try to use the passed type or infer from title/body
      if (!enrichedData.containsKey('type')) {
        if (type != null) {
          enrichedData['type'] = type;
        } else {
          final String lowerTitle = title.toLowerCase();
          final String lowerBody = body.toLowerCase();
          if (lowerTitle.contains('leave') || lowerBody.contains('leave')) {
            enrichedData['type'] = 'leave_request';
          } else if (lowerTitle.contains('payslip') ||
              lowerBody.contains('payslip')) {
            enrichedData['type'] = lowerTitle.contains('request')
                ? 'payslip_request_created'
                : 'payslip_approved'; // simplifiction, but better than message
          }
        }
      }

      await _showSystemNotification(
        title,
        body,
        enrichedData,
        badgeCount: badgeCount,
      );
    } catch (e) {
      debugPrint('Error in showNotification: $e');
    }
  }

  Future<void> _playNotificationSound(String type) async {
    try {
      if (!_isSoundEnabled) return;

      switch (type.toLowerCase()) {
        case 'urgent':
        case 'high':
        case 'critical':
          await HapticFeedback.heavyImpact();
          await Future.delayed(const Duration(milliseconds: 200));
          await HapticFeedback.heavyImpact();
          break;
        case 'announcement':
          await HapticFeedback.mediumImpact();
          await Future.delayed(const Duration(milliseconds: 100));
          await HapticFeedback.mediumImpact();
          break;
        case 'system':
          await HapticFeedback.mediumImpact();
          break;
        case 'message':
        case 'chat':
        default:
          await HapticFeedback.lightImpact();
          break;
      }
    } catch (e) {}
  }

  Future<void> _triggerVibration(String type) async {
    try {
      if (!Platform.isAndroid && !Platform.isIOS) return;

      switch (type.toLowerCase()) {
        case 'urgent':
        case 'high':
        case 'critical':
          await HapticFeedback.heavyImpact();
          await Future.delayed(const Duration(milliseconds: 100));
          await HapticFeedback.heavyImpact();
          break;
        case 'announcement':
          await HapticFeedback.mediumImpact();
          await Future.delayed(const Duration(milliseconds: 80));
          await HapticFeedback.mediumImpact();
          break;
        case 'system':
          await HapticFeedback.mediumImpact();
          break;
        case 'message':
        case 'chat':
        default:
          await HapticFeedback.lightImpact();
          break;
      }
    } catch (e) {}
  }

  Future<void> _showSystemNotification(
    String title,
    String body,
    Map<String, dynamic>? data, {
    int? badgeCount,
  }) async {
    try {
      if (kIsWeb) {
        return;
      }
      ByteArrayAndroidBitmap? largeIconBitmap;
      try {
        final ByteData byteData = await rootBundle.load(
          'assets/images/app_logo.png',
        );
        largeIconBitmap = ByteArrayAndroidBitmap(byteData.buffer.asUint8List());
      } catch (e) {}
      final AndroidNotificationDetails androidPlatformChannelSpecifics =
          AndroidNotificationDetails(
            'hrm_notifications_v2',
            'Empiqo Notifications',
            channelDescription: 'Notifications from Empiqo',
            importance: Importance.max,
            priority: Priority.max,
            playSound: true,
            enableVibration: true,
            showWhen: true,
            ongoing: false,
            autoCancel: true,
            channelShowBadge: true,
            enableLights: true,
            icon: '@mipmap/launcher_icon',
            largeIcon: largeIconBitmap,
            styleInformation: const BigTextStyleInformation(''),
            fullScreenIntent: false,
            category: AndroidNotificationCategory.message,
            visibility: NotificationVisibility.public,
            showProgress: false,
            maxProgress: 0,
            indeterminate: false,
            onlyAlertOnce: false,
            ticker: '',
            number: badgeCount ?? 1,
          );

      const DarwinNotificationDetails iOSPlatformChannelSpecifics =
          DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
            interruptionLevel: InterruptionLevel.active,
          );

      final NotificationDetails platformChannelSpecifics = NotificationDetails(
        android: androidPlatformChannelSpecifics,
        iOS: iOSPlatformChannelSpecifics,
      );

      int notificationId;
      if (data != null && data['messageId'] != null) {
        notificationId = data['messageId'].toString().hashCode.abs() % 100000;
      } else if (data != null && data['announcementId'] != null) {
        notificationId = data['announcementId'].hashCode.abs() % 100000;
      } else {
        notificationId = DateTime.now().millisecondsSinceEpoch.remainder(
          100000,
        );
      }

      await _flutterLocalNotificationsPlugin.show(
        notificationId,
        title,
        body,
        platformChannelSpecifics,
        payload: data != null ? _createNavigationPayload(data) : null,
      );
    } catch (e) {}
  }

  Future<void> showMessageNotification({
    required String senderName,
    required String messageContent,
    String? messageType,
    Map<String, dynamic>? messageData,
  }) async {
    try {
      final enrichedData = Map<String, dynamic>.from(messageData ?? {});

      if (enrichedData.containsKey('sender') && enrichedData['sender'] is Map) {
        final sender = enrichedData['sender'] as Map;
        enrichedData['senderId'] =
            enrichedData['senderId'] ??
            sender['userId'] ??
            sender['id'] ??
            sender['_id'];
        enrichedData['senderName'] =
            enrichedData['senderName'] ??
            sender['name'] ??
            sender['fullName'] ??
            sender['full_name'] ??
            senderName;
        enrichedData['senderType'] =
            enrichedData['senderType'] ??
            sender['userType'] ??
            sender['role'] ??
            sender['user_type'] ??
            'employee';
      }

      enrichedData['senderName'] = enrichedData['senderName'] ?? senderName;

      await showNotification(
        title: 'New Message from $senderName',
        body: messageContent,
        type: 'message',
        data: enrichedData,
      );
    } catch (e) {
      rethrow;
    }
  }

  Future<void> showSystemNotification({
    required String title,
    required String message,
    String? notificationType,
    Map<String, dynamic>? data,
    int? badgeCount,
  }) async {
    await showNotification(
      title: title,
      body: message,
      type: notificationType ?? 'system',
      data: data,
      badgeCount: badgeCount,
    );
  }

  Future<void> showUrgentNotification({
    required String title,
    required String message,
    Map<String, dynamic>? data,
  }) async {
    await showNotification(
      title: title,
      body: message,
      type: 'urgent',
      data: data,
    );
  }

  void toggleSound() {
    _isSoundEnabled = !_isSoundEnabled;
  }

  void toggleVibration() {
    _isVibrationEnabled = !_isVibrationEnabled;
  }

  void setSoundEnabled(bool enabled) {
    _isSoundEnabled = enabled;
  }

  void setVibrationEnabled(bool enabled) {
    _isVibrationEnabled = enabled;
  }

  Future<void> testNotificationSound() async {
    await showNotification(
      title: 'Test Notification',
      body: 'This is a test notification to check sound and vibration',
      type: 'message',
    );
  }

  Future<void> showTestAnnouncementNotification() async {
    await showNotification(
      title: 'Company Meeting Tomorrow',
      body:
          'Please attend the quarterly meeting at 2:00 PM in the conference room.',
      type: 'announcement',
      data: {
        'type': 'announcement',
        'title': 'Company Meeting Tomorrow',
        'message':
            'Please attend the quarterly meeting at 2:00 PM in the conference room. We will discuss Q4 results and upcoming projects. All employees are required to attend.',
        'priority': 'high',
        'audience': 'All Employees',
        'createdBy': {'fullName': 'John Admin', 'name': 'John Admin'},
        'createdAt': DateTime.now().toIso8601String(),
        'announcementId': 'test-announcement-123',
      },
    );
  }

  void testAnnouncementPopupDirectly() {
    if (_globalNavigatorKey?.currentContext == null) {
      return;
    }

    final testData = {
      'type': 'announcement',
      'title': 'Test Announcement Direct',
      'message':
          'This is a direct test of the announcement popup. If you can see this, the popup is working correctly!',
      'priority': 'high',
      'audience': 'All Employees',
      'createdBy': {'fullName': 'Test Admin'},
      'createdAt': DateTime.now().toIso8601String(),
      'announcementId': 'test-direct-popup-123',
    };

    _showAnnouncementPopupDirectly(testData);
  }

  void dispose() {}
}
