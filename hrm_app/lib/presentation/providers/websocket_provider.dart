import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/services/websocket_service.dart';
import '../../core/services/notification_service.dart';
import '../../core/constants/websocket_events.dart';
import '../../core/services/logger_service.dart';
import 'messaging_provider.dart';
import 'employee_provider.dart';
import 'hr_provider.dart';
import 'admin_provider.dart';
import 'auth_provider.dart';
import '../../presentation/widgets/employee_messaging/employee_whatsapp_chat_screen.dart';
import '../../presentation/widgets/hr_dashboard/messaging/hr_whatsapp_chat_screen.dart';
import '../../presentation/widgets/admin_dashboard/messaging/admin_whatsapp_chat_screen.dart';
import '../../presentation/widgets/admin_dashboard/messaging/whatsapp_chat_screen.dart';
import '../../presentation/screens/messaging/conversation_screen.dart';

class WebSocketProvider with ChangeNotifier, WidgetsBindingObserver {
  final WebSocketService _webSocketService = WebSocketService();

  ConnectionStatus _connectionStatus = ConnectionStatus.disconnected;
  bool _isConnecting = false;
  String? _lastError;
  DateTime? _lastActivity;

  StreamSubscription<ConnectionStatus>? _connectionStatusSubscription;
  StreamSubscription<Map<String, dynamic>>? _messageSubscription;
  StreamSubscription<Map<String, dynamic>>? _notificationSubscription;
  StreamSubscription<Map<String, dynamic>>? _payslipSubscription;
  StreamSubscription<Map<String, dynamic>>? _leaveSubscription;
  StreamSubscription<Map<String, dynamic>>? _employeeSubscription;
  StreamSubscription<Map<String, dynamic>>? _eodSubscription;
  StreamSubscription<Map<String, dynamic>>? _announcementSubscription;
  StreamSubscription<Map<String, dynamic>>? _presenceSubscription;

  final Set<String> _onlineIds = <String>{};
  final Set<String> _processedMessageIds = <String>{};

  WebSocketProvider() {
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    LoggerService.debug(
      'App Lifecycle Changed: $state',
      tag: 'WebSocketProvider',
    );
    if (state == AppLifecycleState.resumed) {
      _handleAppResult();
    } else if (state == AppLifecycleState.paused) {
      // Optional: Disconnect or pause, but socket_io_client usually handles this
    }
  }

  Future<void> _handleAppResult() async {
    LoggerService.debug(
      'App Resumed - Reconnecting Socket and Refreshing Data',
      tag: 'WebSocketProvider',
    );
    if (!isConnected) {
      await reconnect();
    }

    // Refresh Dashboard Data via Global Context
    final navigatorKey = NotificationService.globalNavigatorKey;
    if (navigatorKey?.currentContext != null) {
      final context = navigatorKey!.currentContext!;
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final role = authProvider.role;
      final token = authProvider.token;

      if (token != null && role != null) {
        if (role == 'hr') {
          Provider.of<HRProvider>(context, listen: false).refreshAllData(token);
        } else if (role == 'admin') {
          Provider.of<AdminProvider>(
            context,
            listen: false,
          ).refreshAllData(token);
        } else if (role == 'employee') {
          Provider.of<EmployeeProvider>(
            context,
            listen: false,
          ).refreshAllData(token);
        }
      }
    }
  }

  bool isOnlineId(String id) => _onlineIds.contains(id);

  ConnectionStatus get connectionStatus => _connectionStatus;
  bool get isConnected => _connectionStatus == ConnectionStatus.connected;
  bool get isConnecting => _isConnecting;
  String? get lastError => _lastError;
  DateTime? get lastActivity => _lastActivity;
  String? get userId => _webSocketService.userId;
  String? get userRole => _webSocketService.userRole;

  Stream<ConnectionStatus> get connectionStatusStream =>
      _webSocketService.connectionStatusStream;
  Stream<Map<String, dynamic>> get messageStream =>
      _webSocketService.messageStream;
  Stream<Map<String, dynamic>> get notificationStream =>
      _webSocketService.notificationStream;
  Stream<Map<String, dynamic>> get payslipStream =>
      _webSocketService.payslipStream;
  Stream<Map<String, dynamic>> get leaveStream => _webSocketService.leaveStream;
  Stream<Map<String, dynamic>> get employeeStream =>
      _webSocketService.employeeStream;
  Stream<Map<String, dynamic>> get eodStream => _webSocketService.eodStream;
  Stream<Map<String, dynamic>> get announcementStream =>
      _webSocketService.announcementStream;
  Stream<Map<String, dynamic>> get typingStream =>
      _webSocketService.typingStream;

  Future<void> connect(String token, String userId, String userRole) async {
    if (_isConnecting) return;

    // If we are already connected with the same credentials, don't do anything
    if (isConnected &&
        _webSocketService.userId == userId &&
        _webSocketService.userRole == userRole) {
      return;
    }

    _isConnecting = true;
    _lastError = null;
    notifyListeners();

    try {
      // Ensure we start with a clean slate
      _cancelStreamSubscriptions();

      await _webSocketService.connect(token, userId, userRole);
      _setupStreamSubscriptions();
      _lastActivity = DateTime.now();
    } catch (e) {
      _lastError = e.toString();
    } finally {
      _isConnecting = false;
      notifyListeners();
    }
  }

  Future<void> disconnect() async {
    await _webSocketService.disconnect();
    _cancelStreamSubscriptions();
    _lastActivity = DateTime.now();
    notifyListeners();
  }

  Future<void> reconnect() async {
    if (_isConnecting) return;

    // We can't access the token directly from _webSocketService public API easily unless we add a getter or access strictly private
    // But typically we should rely on the caller or stored state.
    // However, looking at _handleAppResult, it seems we might be better off letting the service handle auto-reconnection
    // or using the connect method if we have the token.

    // Given the current structure, let's look at how reconnect is used.
    // In _handleAppResult, it calls reconnect() but doesn't pass token.
    // If the socket disconnected, _webSocketService might still have credentials.

    // Let's defer to the service IF it has the capability, or just invoke connect if we can get the token from elsewhere.
    // Since this method doesn't take arguments, we'll try to trigger a service level reconnect or check connection.

    try {
      if (!isConnected) {
        // The service stores the token internally. We can try to force it to connect.
        // But wait, the service's connect method takes arguments.
        // If we look at WebSocketService, it stores _userId, _userRole, _token.
        // But connect() checks if socket is connected and returns.
        // If socket is NOT connected, it proceeds to use the PASSED IN arguments.
        // It does NOT use stored arguments if passed ones are null (arguments are non-nullable).

        // So `reconnect()` in Provider is tricky without arguments.
        // However, `WebSocketService` has logic to reconnect automatically if configured.
        // `socket_io_client` handles reconnection.

        // For now, let's just make sure we do not duplicate subscriptions if we do anything here.
        // Realistically, if we want to "force" a reconnect, we should probably just ensure listeners are healthy.

        if (_webSocketService.userId != null &&
            _webSocketService.userRole != null) {
          // We can't call connect() without the token.
          // We should rely on the socket's auto-reconnect or the app passing credentials again via `connect`.

          // If the user meant "restore listeners", then:
          _cancelStreamSubscriptions();
          _setupStreamSubscriptions();
        }
      }
    } catch (e) {
      _lastError = e.toString();
    }
  }

  void _setupStreamSubscriptions() {
    _connectionStatusSubscription = _webSocketService.connectionStatusStream
        .listen(
          (status) {
            _connectionStatus = status;
            _lastActivity = DateTime.now();
            notifyListeners();
          },
          onError: (error) {
            _lastError = error.toString();

            notifyListeners();
          },
        );

    _messageSubscription = _webSocketService.messageStream.listen(
      (data) {
        try {
          _lastActivity = DateTime.now();

          _handleMessageEvent(data);
        } catch (e) {}
      },
      onError: (error) {},
      cancelOnError: false,
    );

    _presenceSubscription = _webSocketService.presenceStream.listen((data) {
      try {
        final event = data['event']?.toString() ?? '';
        final userId = (data['userId'] ?? data['id'] ?? data['_id'])
            ?.toString();
        final profileId = data['profileId']?.toString();
        if (event == WebSocketEvents.userConnected) {
          if (userId != null && userId.isNotEmpty) _onlineIds.add(userId);
          if (profileId != null && profileId.isNotEmpty) {
            _onlineIds.add(profileId);
          }
        } else if (event == WebSocketEvents.userDisconnected) {
          if (userId != null && userId.isNotEmpty) _onlineIds.remove(userId);
          if (profileId != null && profileId.isNotEmpty) {
            _onlineIds.remove(profileId);
          }
        }
        _lastActivity = DateTime.now();
        notifyListeners();
      } catch (_) {}
    }, onError: (_) {});

    _notificationSubscription = _webSocketService.notificationStream.listen((
      data,
    ) {
      _lastActivity = DateTime.now();
      _handleNotificationEvent(data);
    }, onError: (error) {});

    _payslipSubscription = _webSocketService.payslipStream.listen((data) {
      _lastActivity = DateTime.now();
      _handlePayslipEvent(data);
    }, onError: (error) {});

    _leaveSubscription = _webSocketService.leaveStream.listen((data) {
      _lastActivity = DateTime.now();
      _handleLeaveEvent(data);
    }, onError: (error) {});

    _employeeSubscription = _webSocketService.employeeStream.listen((data) {
      _lastActivity = DateTime.now();
      _handleEmployeeEvent(data);
    }, onError: (error) {});

    _eodSubscription = _webSocketService.eodStream.listen((data) {
      _lastActivity = DateTime.now();
      _handleEODEvent(data);
    }, onError: (error) {});

    _announcementSubscription = _webSocketService.announcementStream.listen((
      data,
    ) {
      _lastActivity = DateTime.now();
      _handleAnnouncementEvent(data);
    }, onError: (error) {});
  }

  void _cancelStreamSubscriptions() {
    _connectionStatusSubscription?.cancel();
    _messageSubscription?.cancel();
    _notificationSubscription?.cancel();
    _payslipSubscription?.cancel();
    _leaveSubscription?.cancel();
    _employeeSubscription?.cancel();
    _eodSubscription?.cancel();
    _announcementSubscription?.cancel();
    _presenceSubscription?.cancel();
  }

  void _handleMessageEvent(Map<String, dynamic> data) {
    try {
      final messageData = data['data'] ?? data;
      final eventType = data['event'] ?? messageData['eventType'] ?? '';

      if (messageData is Map) {
      } else {}

      final isMessageReceived =
          eventType == 'message_received' ||
          eventType == WebSocketEvents.messageReceived ||
          (eventType.isEmpty &&
              messageData is Map &&
              messageData.containsKey('conversationId') &&
              messageData.containsKey('sender') &&
              !messageData.containsKey('receiver'));

      if (isMessageReceived &&
          eventType != 'message_sent' &&
          eventType != WebSocketEvents.messageSent) {
        final conversationId =
            messageData['conversationId'] ?? data['conversationId'];
        final sender = messageData['sender'] ?? data['sender'];
        final content = messageData['content'] ?? data['content'] ?? '';
        final messageType =
            messageData['messageType'] ?? data['messageType'] ?? 'text';
        final messageId = messageData['messageId'] ?? data['messageId'];

        if (sender != null && conversationId != null) {
          String senderName = 'Someone';
          String? senderUserId;
          String? senderType;

          if (sender is Map) {
            final senderMap = Map<String, dynamic>.from(sender);
            senderName =
                senderMap['name'] ??
                senderMap['fullName'] ??
                senderMap['full_name'] ??
                senderMap['senderName'] ??
                'Someone';
            senderUserId =
                (senderMap['userId'] ??
                        senderMap['id'] ??
                        senderMap['_id'] ??
                        senderMap['senderId'])
                    ?.toString();
            senderType =
                senderMap['userType'] ??
                senderMap['role'] ??
                senderMap['user_type'] ??
                senderMap['senderType'] ??
                'employee';
          } else if (sender is String) {
            senderName = sender;
          }

          bool isOnChatScreen = false;
          bool verifiedMatch = false;

          if (senderUserId != null) {
            senderUserId = senderUserId.trim();
          } else {
            if (sender is Map) {
              final senderMap = Map<String, dynamic>.from(sender);
              senderUserId =
                  (senderMap['userId'] ??
                          senderMap['id'] ??
                          senderMap['_id'] ??
                          senderMap['senderId'])
                      ?.toString();
              if (senderUserId != null) {
                senderUserId = senderUserId.trim();
              }
            }
          }

          if (senderUserId != null && senderUserId.isNotEmpty) {
            try {
              final navigatorKey = NotificationService.globalNavigatorKey;
              if (navigatorKey?.currentContext != null) {
                final context = navigatorKey!.currentContext!;

                try {
                  final employeeProvider = Provider.of<EmployeeProvider>(
                    context,
                    listen: false,
                  );
                  final currentChatPartnerId =
                      employeeProvider.currentChatPartnerId;

                  if (currentChatPartnerId != null &&
                      currentChatPartnerId.isNotEmpty) {
                    final normalizedPartnerId = currentChatPartnerId.trim();
                    final normalizedSenderId = senderUserId.trim();

                    if (normalizedPartnerId == normalizedSenderId) {
                      verifiedMatch = true;
                      isOnChatScreen = true;
                    } else {}
                  } else {}
                } catch (e) {}

                if (!verifiedMatch) {
                  try {
                    final hrProvider = Provider.of<HRProvider>(
                      context,
                      listen: false,
                    );
                    final currentChatPartnerId =
                        hrProvider.currentChatPartnerId;

                    if (currentChatPartnerId != null &&
                        currentChatPartnerId.isNotEmpty) {
                      final normalizedPartnerId = currentChatPartnerId.trim();
                      final normalizedSenderId = senderUserId.trim();

                      if (normalizedPartnerId == normalizedSenderId) {
                        verifiedMatch = true;
                        isOnChatScreen = true;
                      } else {}
                    }
                  } catch (e) {}
                }

                if (!verifiedMatch) {
                  try {
                    final adminProvider = Provider.of<AdminProvider>(
                      context,
                      listen: false,
                    );
                    final currentChatPartnerId =
                        adminProvider.currentChatPartnerId;

                    if (currentChatPartnerId != null &&
                        currentChatPartnerId.isNotEmpty) {
                      final normalizedPartnerId = currentChatPartnerId.trim();
                      final normalizedSenderId = senderUserId.trim();

                      if (normalizedPartnerId == normalizedSenderId) {
                        verifiedMatch = true;
                        isOnChatScreen = true;
                      } else {}
                    }
                  } catch (e) {}
                }

                if (!verifiedMatch && conversationId != null) {
                  try {
                    final messagingProvider = Provider.of<MessagingProvider>(
                      context,
                      listen: false,
                    );
                    final currentConversationId =
                        messagingProvider.currentConversationId;

                    if (currentConversationId != null &&
                        currentConversationId.toString().trim() ==
                            conversationId.toString().trim()) {
                      verifiedMatch = true;
                      isOnChatScreen = true;
                    }
                  } catch (e) {}
                }
              } else {}
            } catch (e) {}
          } else {}

          if (verifiedMatch && isOnChatScreen) {
          } else {
            if (!verifiedMatch && senderUserId != null) {
              try {
                final navigatorKey = NotificationService.globalNavigatorKey;
                if (navigatorKey?.currentContext != null) {
                  final context = navigatorKey!.currentContext!;
                  try {
                    final currentRoute = ModalRoute.of(context)?.settings.name;
                    final isOnConversationRoute =
                        currentRoute == '/conversation';

                    bool isOnConversationScreen = false;
                    try {
                      final conversationScreen = context
                          .findAncestorWidgetOfExactType<ConversationScreen>();
                      isOnConversationScreen = conversationScreen != null;
                      if (isOnConversationScreen) {}
                    } catch (e) {}

                    bool isOnWhatsAppChat = false;
                    String? currentChatUserId;

                    try {
                      EmployeeWhatsAppChatScreen? employeeChat;
                      HRWhatsAppChatScreen? hrChat;
                      AdminWhatsAppChatScreen? adminChat;
                      WhatsAppChatScreen? genericChat;

                      try {
                        employeeChat = context
                            .findAncestorWidgetOfExactType<
                              EmployeeWhatsAppChatScreen
                            >();
                        if (employeeChat != null) {
                          isOnWhatsAppChat = true;
                          currentChatUserId = employeeChat.userId;

                          if (currentChatUserId == senderUserId) {
                            verifiedMatch = true;
                            isOnChatScreen = true;
                          }

                          if (!verifiedMatch) {
                            final employeeProvider =
                                Provider.of<EmployeeProvider>(
                                  context,
                                  listen: false,
                                );
                            final currentChatPartnerId =
                                employeeProvider.currentChatPartnerId;

                            if (currentChatPartnerId != null &&
                                currentChatPartnerId == senderUserId) {
                              verifiedMatch = true;
                              isOnChatScreen = true;
                            }
                          }
                        } else {
                          final employeeProvider =
                              Provider.of<EmployeeProvider>(
                                context,
                                listen: false,
                              );
                          if (employeeProvider.currentChatPartnerId != null) {
                            employeeProvider.setCurrentChatPartner(null);
                          }
                        }
                      } catch (e) {}

                      if (!isOnWhatsAppChat && !verifiedMatch) {
                        try {
                          hrChat = context
                              .findAncestorWidgetOfExactType<
                                HRWhatsAppChatScreen
                              >();
                          if (hrChat != null) {
                            isOnWhatsAppChat = true;
                            currentChatUserId = hrChat.userId;

                            if (currentChatUserId == senderUserId) {
                              verifiedMatch = true;
                              isOnChatScreen = true;
                            }

                            if (!verifiedMatch) {
                              final hrProvider = Provider.of<HRProvider>(
                                context,
                                listen: false,
                              );
                              final currentChatPartnerId =
                                  hrProvider.currentChatPartnerId;
                              if (currentChatPartnerId != null &&
                                  currentChatPartnerId == senderUserId) {
                                verifiedMatch = true;
                                isOnChatScreen = true;
                              }
                            }
                          } else {
                            final hrProvider = Provider.of<HRProvider>(
                              context,
                              listen: false,
                            );
                            if (hrProvider.currentChatPartnerId != null) {
                              hrProvider.setCurrentChatPartner(null);
                            }
                          }
                        } catch (e) {}
                      }

                      if (!isOnWhatsAppChat && !verifiedMatch) {
                        try {
                          adminChat = context
                              .findAncestorWidgetOfExactType<
                                AdminWhatsAppChatScreen
                              >();
                          if (adminChat != null) {
                            isOnWhatsAppChat = true;
                            currentChatUserId = adminChat.userId;

                            if (currentChatUserId == senderUserId) {
                              verifiedMatch = true;
                              isOnChatScreen = true;
                            }

                            if (!verifiedMatch) {
                              final adminProvider = Provider.of<AdminProvider>(
                                context,
                                listen: false,
                              );
                              final currentChatPartnerId =
                                  adminProvider.currentChatPartnerId;
                              if (currentChatPartnerId != null &&
                                  currentChatPartnerId == senderUserId) {
                                verifiedMatch = true;
                                isOnChatScreen = true;
                              }
                            }
                          } else {
                            final adminProvider = Provider.of<AdminProvider>(
                              context,
                              listen: false,
                            );
                            if (adminProvider.currentChatPartnerId != null) {
                              adminProvider.setCurrentChatPartner(null);
                            }
                          }

                          if (!isOnWhatsAppChat && !verifiedMatch) {
                            genericChat = context
                                .findAncestorWidgetOfExactType<
                                  WhatsAppChatScreen
                                >();
                            if (genericChat != null) {
                              isOnWhatsAppChat = true;
                              currentChatUserId = genericChat.userId;

                              if (currentChatUserId == senderUserId) {
                                verifiedMatch = true;
                                isOnChatScreen = true;
                              }
                            }
                          }
                        } catch (e) {}
                      }

                      if (!isOnWhatsAppChat) {
                        final widgetType = context.widget.runtimeType
                            .toString();
                        isOnWhatsAppChat =
                            widgetType.contains('WhatsAppChatScreen') ||
                            widgetType.contains('EmployeeWhatsAppChatScreen') ||
                            widgetType.contains('HRWhatsAppChatScreen') ||
                            widgetType.contains('AdminWhatsAppChatScreen');

                        if (isOnWhatsAppChat && currentChatUserId == null) {
                          try {
                            final state = context
                                .findAncestorStateOfType<
                                  State<StatefulWidget>
                                >();
                            if (state != null) {
                              final widget = state.widget;
                              if (widget is EmployeeWhatsAppChatScreen) {
                                currentChatUserId = widget.userId;
                              } else if (widget is HRWhatsAppChatScreen) {
                                currentChatUserId = widget.userId;
                              } else if (widget is AdminWhatsAppChatScreen) {
                                currentChatUserId = widget.userId;
                              } else if (widget is WhatsAppChatScreen) {
                                currentChatUserId = widget.userId;
                              }

                              if (currentChatUserId != null &&
                                  currentChatUserId == senderUserId) {
                                verifiedMatch = true;
                                isOnChatScreen = true;
                              }
                            }
                          } catch (e) {}
                        }
                      }
                    } catch (e) {}

                    if (isOnConversationRoute ||
                        isOnConversationScreen ||
                        isOnWhatsAppChat) {
                      try {
                        final messagingProvider =
                            Provider.of<MessagingProvider>(
                              context,
                              listen: false,
                            );
                        final currentConversationId =
                            messagingProvider.currentConversationId;

                        if (currentConversationId != null &&
                            conversationId != null) {
                          final idsMatch =
                              currentConversationId.toString() ==
                              conversationId.toString();

                          if (idsMatch) {
                            verifiedMatch = true;
                            isOnChatScreen = true;
                          }
                        }

                        if (!verifiedMatch &&
                            isOnWhatsAppChat &&
                            currentChatUserId != null) {
                          final userIdsMatch =
                              currentChatUserId == senderUserId;

                          if (userIdsMatch) {
                            verifiedMatch = true;
                            isOnChatScreen = true;
                          } else {}
                        } else if (!verifiedMatch && isOnWhatsAppChat) {
                          try {
                            final employeeProvider =
                                Provider.of<EmployeeProvider>(
                                  context,
                                  listen: false,
                                );
                            if (employeeProvider.currentChatPartnerId ==
                                senderUserId) {
                              verifiedMatch = true;
                              isOnChatScreen = true;
                            }
                          } catch (_) {}

                          if (!verifiedMatch) {
                            try {
                              final hrProvider = Provider.of<HRProvider>(
                                context,
                                listen: false,
                              );
                              if (hrProvider.currentChatPartnerId ==
                                  senderUserId) {
                                verifiedMatch = true;
                                isOnChatScreen = true;
                              }
                            } catch (_) {}
                          }

                          if (!verifiedMatch) {
                            try {
                              final adminProvider = Provider.of<AdminProvider>(
                                context,
                                listen: false,
                              );
                              if (adminProvider.currentChatPartnerId ==
                                  senderUserId) {
                                verifiedMatch = true;
                                isOnChatScreen = true;
                              }
                            } catch (_) {}
                          }

                          if (!verifiedMatch) {
                            if (currentChatUserId == null) {}
                          }
                        }
                      } catch (e) {
                        if (!verifiedMatch) {
                          verifiedMatch = false;
                        }
                      }

                      if (verifiedMatch) {
                        isOnChatScreen = true;
                      }

                      if (!verifiedMatch) {
                      } else {}
                    } else {
                      if (!isOnChatScreen) {
                        isOnChatScreen = false;
                      }
                    }
                  } catch (e) {
                    if (!isOnChatScreen) {
                      isOnChatScreen = false;
                    }
                  }
                } else {
                  if (!isOnChatScreen) {
                    isOnChatScreen = false;
                  }
                }
              } catch (e) {
                if (!isOnChatScreen) {
                  isOnChatScreen = false;
                }
              }
            }
          }

          if (isOnChatScreen) {
          } else {}

          if (!isOnChatScreen) {
            final enriched = <String, dynamic>{
              'type': 'message',
              'senderName': senderName,
              'conversationId': conversationId.toString(),
              'messageId': messageId?.toString(),
              'content': content,
              'messageType': messageType,
            };

            if (sender is Map) {
              final senderMap = Map<String, dynamic>.from(sender);
              enriched['sender'] = senderMap;

              enriched['senderId'] =
                  senderUserId ??
                  senderMap['userId'] ??
                  senderMap['id'] ??
                  senderMap['_id'] ??
                  senderMap['senderId'];
              enriched['senderName'] = senderName;
              enriched['senderType'] =
                  senderType ??
                  senderMap['userType'] ??
                  senderMap['role'] ??
                  senderMap['user_type'] ??
                  senderMap['senderType'] ??
                  'employee';
            } else {
              enriched['sender'] = sender;
              if (senderUserId != null) enriched['senderId'] = senderUserId;
              if (senderType != null) enriched['senderType'] = senderType;
            }

            if (messageData is Map<String, dynamic>) {
              enriched.addAll(messageData);
            } else if (messageData is Map) {
              enriched.addAll(Map<String, dynamic>.from(messageData));
            }

            enriched.addAll(data);

            try {
              final navigatorKey = NotificationService.globalNavigatorKey;
              if (navigatorKey?.currentContext != null) {
                final context = navigatorKey!.currentContext!;
                final authProvider = Provider.of<AuthProvider>(
                  context,
                  listen: false,
                );

                if (senderUserId != null) {
                  if (authProvider.role == 'hr') {
                    final hrProvider = Provider.of<HRProvider>(
                      context,
                      listen: false,
                    );
                    hrProvider.addUnreadConversation(senderUserId);
                  } else if (authProvider.role == 'admin') {
                    final adminProvider = Provider.of<AdminProvider>(
                      context,
                      listen: false,
                    );
                    adminProvider.addUnreadConversation(senderUserId);
                  } else if (authProvider.role == 'employee') {
                    final employeeProvider = Provider.of<EmployeeProvider>(
                      context,
                      listen: false,
                    );
                    employeeProvider.addUnreadConversation(senderUserId);
                  }
                }
              }
            } catch (e) {
              LoggerService.error(
                'Error updating unread count from WebSocket',
                error: e,
                tag: 'WebSocketProvider',
              );
            }

            final notificationService = NotificationService();
            notificationService
                .showMessageNotification(
                  senderName: senderName,
                  messageContent: content.isNotEmpty ? content : 'New message',
                  messageType: messageType,
                  messageData: enriched,
                )
                .then((_) {})
                .catchError((e) {});
          } else {}
        } else {}
      }
    } catch (e) {}
  }

  void _handleNotificationEvent(Map<String, dynamic> data) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final title = data['title'] ?? 'Notification';
      final message = data['message'] ?? '';
      final type = data['type'] ?? 'system';
      if (type == 'announcement') {
        return;
      }

      final notificationService = NotificationService();
      int? currentBadgeCount;
      try {
        final navigatorKey = NotificationService.globalNavigatorKey;
        if (navigatorKey?.currentContext != null) {
          final context = navigatorKey!.currentContext!;
          if (context.mounted) {
            final authProvider = Provider.of<AuthProvider>(
              context,
              listen: false,
            );
            if (authProvider.role == 'employee') {
              final employeeProvider = Provider.of<EmployeeProvider>(
                context,
                listen: false,
              );
              currentBadgeCount = employeeProvider.unreadMessagesCount;
            } else if (authProvider.role == 'hr') {
              final hrProvider = Provider.of<HRProvider>(
                context,
                listen: false,
              );
              currentBadgeCount = hrProvider.unreadMessagesCount;
            } else if (authProvider.role == 'admin') {
              final adminProvider = Provider.of<AdminProvider>(
                context,
                listen: false,
              );
              currentBadgeCount = adminProvider.unreadMessagesCount;
            }
          }
        }
      } catch (e) {}
      notificationService.showSystemNotification(
        title: title,
        message: message,
        notificationType: type,
        data: data,
        badgeCount: currentBadgeCount != null && currentBadgeCount > 0
            ? currentBadgeCount
            : null,
      );
    });
  }

  void _handlePayslipEvent(Map<String, dynamic> data) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        final eventType = data['event'] ?? '';
        final requestId = data['requestId'] ?? data['payslipRequest']?['_id'];
        final employee =
            data['employee'] ?? data['payslipRequest']?['employee'];
        final employeeName = employee is Map
            ? (employee['name'] ?? 'An employee')
            : (employee?.toString() ?? 'An employee');

        if (eventType.contains('created') ||
            (data.containsKey('requestId') && !data.containsKey('status'))) {
          final title = 'New Payslip Request';
          final message = '$employeeName has submitted a payslip request';
          final notificationData = {
            ...data,
            'type': 'payslip_request_created',
            'title': title,
            'message': message,
            'requestId': requestId,
          };

          final notificationService = NotificationService();
          notificationService.showSystemNotification(
            title: title,
            message: message,
            notificationType: 'payslip_request_created',
            data: notificationData,
          );

          _refreshHRPayslipRequests();

          _callHRProviderHandler(data);
        } else if (eventType.contains('approved') ||
            data['status'] == 'approved') {
          final title = data['title'] ?? 'Payslip Accepted';
          final message =
              data['message'] ?? 'Your payslip request has been approved';
          final notificationData = {
            ...data,
            'type': 'payslip_approved',
            'title': title,
            'message': message,
          };

          final notificationService = NotificationService();
          notificationService.showSystemNotification(
            title: title,
            message: message,
            notificationType: 'payslip_approved',
            data: notificationData,
          );
        } else if (eventType.contains('rejected') ||
            data['status'] == 'rejected') {
          final title = 'Payslip Request Rejected';
          final message =
              data['message'] ?? 'Your payslip request has been rejected';
          final notificationData = {
            ...data,
            'type': 'payslip_rejected',
            'title': title,
            'message': message,
          };

          final notificationService = NotificationService();
          notificationService.showSystemNotification(
            title: title,
            message: message,
            notificationType: 'payslip_rejected',
            data: notificationData,
          );
        } else {
          final title = data['title'] ?? 'Payslip Update';
          final message = data['message'] ?? '';
          final type = data['type'] ?? 'payslip_update';

          final notificationService = NotificationService();
          notificationService.showSystemNotification(
            title: title,
            message: message,
            notificationType: type,
            data: data,
          );
        }
      } catch (e) {}
    });
  }

  void _refreshHRPayslipRequests() {
    try {
      final navigatorKey = NotificationService.globalNavigatorKey;
      if (navigatorKey?.currentContext != null) {
        final context = navigatorKey!.currentContext!;
        if (context.mounted) {
          try {
            final hrProvider = Provider.of<HRProvider>(context, listen: false);
            final authProvider = Provider.of<AuthProvider>(
              context,
              listen: false,
            );
            if (authProvider.token != null) {
              hrProvider.loadPayslipRequests(
                authProvider.token!,
                forceRefresh: true,
              );
            }
          } catch (e) {}
        }
      }
    } catch (e) {}
  }

  void _callHRProviderHandler(Map<String, dynamic> data) {
    try {
      final navigatorKey = NotificationService.globalNavigatorKey;
      if (navigatorKey?.currentContext != null) {
        final context = navigatorKey!.currentContext!;
        if (context.mounted) {
          try {
            final hrProvider = Provider.of<HRProvider>(context, listen: false);
            hrProvider.handlePayslipRequestCreated(data);
          } catch (e) {}
        }
      }
    } catch (e) {}
  }

  void _handleLeaveEvent(Map<String, dynamic> data) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (data.containsKey('leaveRequest')) {
        final leaveRequest = data['leaveRequest'];
        final employeeName = leaveRequest['employee']?['name'] ?? 'An employee';
        final leaveType = leaveRequest['leaveType'] ?? 'leave';

        // Update HR Dashboard if user is HR
        try {
          final navigatorKey = NotificationService.globalNavigatorKey;
          if (navigatorKey?.currentContext != null) {
            final context = navigatorKey!.currentContext!;
            final authProvider = Provider.of<AuthProvider>(
              context,
              listen: false,
            );

            if (authProvider.role == 'hr') {
              final hrProvider = Provider.of<HRProvider>(
                context,
                listen: false,
              );
              hrProvider.incrementPendingLeavesCount();
            }
          }
        } catch (e) {
          LoggerService.error(
            'Error updating pending leaves count',
            error: e,
            tag: 'WebSocketProvider',
          );
        }

        final notificationService = NotificationService();
        notificationService.showSystemNotification(
          title: 'New Leave Request',
          message: '$employeeName has requested a $leaveType',
          notificationType: 'system',
          data: data,
        );
      }
    });
  }

  void _handleEmployeeEvent(Map<String, dynamic> data) {}

  void _handleEODEvent(Map<String, dynamic> data) {}

  final Set<String> _processedAnnouncements = {};

  void _handleAnnouncementEvent(Map<String, dynamic> data) {
    final title = data['title'] ?? 'New Announcement';
    final message = data['message'] ?? data['content'] ?? '';
    final priority = data['priority'] ?? 'normal';
    final audience = data['audience'] ?? 'All';
    final announcementId = data['announcementId'] ?? data['id'] ?? '';

    if (announcementId.isNotEmpty &&
        _processedAnnouncements.contains(announcementId)) {
      return;
    }

    if (announcementId.isNotEmpty) {
      _processedAnnouncements.add(announcementId);

      if (_processedAnnouncements.length > 100) {
        final toRemove = _processedAnnouncements
            .take(_processedAnnouncements.length - 100)
            .toList();
        for (final id in toRemove) {
          _processedAnnouncements.remove(id);
        }
      }
    }

    final notificationData = {
      ...data,
      'type': 'announcement',
      'priority': priority,
      'audience': audience,
      'createdBy': data['createdBy'] ?? data['author'],
      'createdAt': data['createdAt'] ?? data['timestamp'],
      'announcementId': announcementId,
    };

    final notificationService = NotificationService();

    final isInForeground =
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;

    if (isInForeground) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showAnnouncementNotification(
          title,
          message,
          priority,
          notificationData,
          notificationService,
        );
      });
    } else {
      _showAnnouncementNotification(
        title,
        message,
        priority,
        notificationData,
        notificationService,
      );
    }
  }

  void _showAnnouncementNotification(
    String title,
    String message,
    String priority,
    Map<String, dynamic> notificationData,
    NotificationService notificationService,
  ) {
    if (priority == 'urgent' || priority == 'high') {
      notificationService.showUrgentNotification(
        title: title,
        message: message,
        data: notificationData,
      );
    } else {
      notificationService.showSystemNotification(
        title: title,
        message: message,
        notificationType: 'announcement',
        data: notificationData,
      );
    }
  }

  void emitEvent(String event, Map<String, dynamic> data) {
    _webSocketService.emitEvent(event, data);
  }

  void joinRoom(String roomName) {
    _webSocketService.joinRoom(roomName);
  }

  void leaveRoom(String roomName) {
    _webSocketService.leaveRoom(roomName);
  }

  Future<bool> testConnection() async {
    return await _webSocketService.testConnection();
  }

  Future<bool> testHttpConnectivity() async {
    return await _webSocketService.testHttpConnectivity();
  }

  String getConnectionStatusText() {
    switch (_connectionStatus) {
      case ConnectionStatus.disconnected:
        return 'Disconnected';
      case ConnectionStatus.connecting:
        return 'Connecting...';
      case ConnectionStatus.connected:
        return 'Connected';
      case ConnectionStatus.reconnecting:
        return 'Reconnecting...';
      case ConnectionStatus.error:
        return 'Error';
    }
  }

  bool get isHealthy {
    if (!isConnected) return false;
    if (_lastActivity == null) return false;

    final timeSinceLastActivity = DateTime.now().difference(_lastActivity!);
    return timeSinceLastActivity.inMinutes < 5;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cancelStreamSubscriptions();
    _webSocketService.dispose();
    super.dispose();
  }
}
