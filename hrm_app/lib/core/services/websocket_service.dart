import 'dart:async';
import 'dart:io';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../constants/websocket_events.dart';
import '../config/app_config.dart';

class WebSocketService {
  static final WebSocketService _instance = WebSocketService._internal();
  factory WebSocketService() => _instance;
  WebSocketService._internal();

  IO.Socket? _socket;
  String? _userId;
  String? _userRole;
  String? _token;

  Timer? _refreshTimer;
  static const Duration _refreshInterval = Duration(minutes: 5);

  final StreamController<ConnectionStatus> _connectionStatusController =
      StreamController<ConnectionStatus>.broadcast();
  final StreamController<Map<String, dynamic>> _messageController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<Map<String, dynamic>> _notificationController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<Map<String, dynamic>> _payslipController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<Map<String, dynamic>> _leaveController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<Map<String, dynamic>> _employeeController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<Map<String, dynamic>> _eodController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<Map<String, dynamic>> _announcementController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<Map<String, dynamic>> _presenceController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<Map<String, dynamic>> _typingController =
      StreamController<Map<String, dynamic>>.broadcast();

  String? get userId => _userId;
  String? get userRole => _userRole;
  bool get isConnected => _socket?.connected ?? false;

  String? _getAuthToken() => _token;

  Stream<ConnectionStatus> get connectionStatusStream =>
      _connectionStatusController.stream;
  Stream<Map<String, dynamic>> get messageStream => _messageController.stream;
  Stream<Map<String, dynamic>> get notificationStream =>
      _notificationController.stream;
  Stream<Map<String, dynamic>> get payslipStream => _payslipController.stream;
  Stream<Map<String, dynamic>> get leaveStream => _leaveController.stream;
  Stream<Map<String, dynamic>> get employeeStream => _employeeController.stream;
  Stream<Map<String, dynamic>> get eodStream => _eodController.stream;
  Stream<Map<String, dynamic>> get announcementStream =>
      _announcementController.stream;
  Stream<Map<String, dynamic>> get presenceStream => _presenceController.stream;
  Stream<Map<String, dynamic>> get typingStream => _typingController.stream;

  Future<void> connect(String token, String userId, String userRole) async {
    if (_socket?.connected == true) {
      return;
    }

    _userId = userId;
    _userRole = userRole;
    _token = token;

    try {
      _connectionStatusController.add(ConnectionStatus.connecting);

      _socket = IO.io(
        AppConfig.websocketUrl,
        IO.OptionBuilder()
            .setTransports(['websocket', 'polling'])
            .disableAutoConnect()
            .setAuth({'token': token})
            .setTimeout(AppConfig.connectionTimeout.inMilliseconds)
            .enableReconnection()
            .setReconnectionAttempts(AppConfig.maxReconnectionAttempts)
            .setReconnectionDelay(AppConfig.reconnectionDelay.inMilliseconds)
            .setReconnectionDelayMax(
              AppConfig.maxReconnectionDelay.inMilliseconds,
            )
            .setExtraHeaders({'Connection': 'Upgrade'})
            .setQuery({'token': token})
            .enableForceNew()
            .enableReconnection()
            .setPath('/socket.io/')
            .build(),
      );

      _setupEventListeners();

      _socket!.connect();
      await _waitForConnection();

      _startIntervalRefresh();
    } catch (e) {
      _connectionStatusController.add(ConnectionStatus.error);

      Future.delayed(const Duration(seconds: 5), () {
        if (_socket?.connected != true) {
          try {
            _socket?.connect();
          } catch (reconnectError) {}
        }
      });
    }
  }

  Future<void> _waitForConnection() async {
    final completer = Completer<void>();
    bool isCompleted = false;
    Timer? timeoutTimer;

    void onConnect(_) {
      if (!isCompleted) {
        isCompleted = true;
        timeoutTimer?.cancel();
        _connectionStatusController.add(ConnectionStatus.connected);
        completer.complete();
      }
    }

    void onConnectError(error) {
      if (!isCompleted) {
        isCompleted = true;
        timeoutTimer?.cancel();

        _connectionStatusController.add(ConnectionStatus.error);

        completer.complete();
      }
    }

    void onError(error) {
      if (!isCompleted) {}
    }

    try {
      _socket!.onConnect(onConnect);
      _socket!.onConnectError(onConnectError);
      _socket!.onError(onError);

      timeoutTimer = Timer(AppConfig.connectionTimeout, () {
        if (!isCompleted) {
          isCompleted = true;

          completer.complete();
        }
      });

      await completer.future;
    } catch (e) {
      timeoutTimer?.cancel();

      if (!isCompleted) {
        isCompleted = true;
        completer.complete();
      }
    }
  }

  void _setupEventListeners() {
    if (_socket == null) return;

    _socket!.onConnect((_) {
      _connectionStatusController.add(ConnectionStatus.connected);

      if (_userId != null && _userRole != null) {
        _socket!.emit('authenticate', {'token': _getAuthToken()});
      }
    });

    _socket!.onDisconnect((_) {
      _connectionStatusController.add(ConnectionStatus.disconnected);
    });

    _socket!.onConnectError((error) {
      _connectionStatusController.add(ConnectionStatus.error);
    });

    _socket!.onReconnect((_) {
      _connectionStatusController.add(ConnectionStatus.connected);
    });

    _socket!.onReconnectError((error) {
      _connectionStatusController.add(ConnectionStatus.reconnecting);
    });

    _socket!.on(WebSocketEvents.authenticated, (data) {});

    _socket!.on(WebSocketEvents.authenticationFailed, (data) {
      _connectionStatusController.add(ConnectionStatus.error);
    });

    _socket!.on(WebSocketEvents.roomJoined, (data) {});

    _socket!.on(WebSocketEvents.roomLeft, (data) {});

    _socket!.on(WebSocketEvents.messageSent, (data) {
      _messageController.add({
        'event': WebSocketEvents.messageSent,
        'data': _safeMap(data),
      });
    });

    _socket!.on(WebSocketEvents.messageReceived, (data) {
      _messageController.add({
        'event': WebSocketEvents.messageReceived,
        'data': _safeMap(data),
      });
    });

    _socket!.on(WebSocketEvents.messageRead, (data) {
      _messageController.add({
        'event': WebSocketEvents.messageRead,
        'data': _safeMap(data),
      });
    });

    try {
      (_socket as dynamic).onAny((String event, dynamic data) {
        if (event.startsWith('message')) {
          _messageController.add({'event': event, 'data': _safeMap(data)});
        }
      });
    } catch (_) {}

    _socket!.on(WebSocketEvents.payslipRequestCreated, (data) {
      final enrichedData = _safeMap(data);
      enrichedData['event'] = 'payslip_request_created';
      _payslipController.add(enrichedData);
    });

    _socket!.on(WebSocketEvents.payslipRequestApproved, (data) {
      final enrichedData = _safeMap(data);
      enrichedData['event'] = 'payslip_request_approved';
      _payslipController.add(enrichedData);
    });

    _socket!.on(WebSocketEvents.payslipRequestRejected, (data) {
      final enrichedData = _safeMap(data);
      enrichedData['event'] = 'payslip_request_rejected';
      _payslipController.add(enrichedData);
    });

    _socket!.on(WebSocketEvents.payslipGenerated, (data) {
      final enrichedData = _safeMap(data);
      enrichedData['event'] = 'payslip_generated';
      _payslipController.add(enrichedData);
    });

    _socket!.on(WebSocketEvents.leaveRequestCreated, (data) {
      _leaveController.add(data);
    });

    _socket!.on(WebSocketEvents.leaveRequestApproved, (data) {
      _leaveController.add(data);
    });

    _socket!.on(WebSocketEvents.leaveRequestRejected, (data) {
      _leaveController.add(data);
    });

    _socket!.on(WebSocketEvents.leaveBalanceUpdated, (data) {
      _leaveController.add(data);
    });

    _socket!.on(WebSocketEvents.leaveCalendarUpdated, (data) {
      _leaveController.add(data);
    });

    _socket!.on(WebSocketEvents.employeeCreated, (data) {
      _employeeController.add(data);
    });

    _socket!.on(WebSocketEvents.employeeUpdated, (data) {
      _employeeController.add(data);
    });

    _socket!.on(WebSocketEvents.employeeDeleted, (data) {
      _employeeController.add(data);
    });

    _socket!.on(WebSocketEvents.employeeStatusChanged, (data) {
      _employeeController.add(data);
    });

    _socket!.on(WebSocketEvents.employeeProfileUpdated, (data) {
      _employeeController.add(data);
    });

    _socket!.on(WebSocketEvents.eodSubmitted, (data) {
      _eodController.add(data);
    });

    _socket!.on(WebSocketEvents.eodApproved, (data) {
      _eodController.add(data);
    });

    _socket!.on(WebSocketEvents.eodRejected, (data) {
      _eodController.add(data);
    });

    _socket!.on(WebSocketEvents.eodReminder, (data) {
      _eodController.add(data);
    });

    _socket!.on(WebSocketEvents.announcementCreated, (data) {
      _announcementController.add(data);
    });

    _socket!.on(WebSocketEvents.announcementUpdated, (data) {
      _announcementController.add(data);
    });

    _socket!.on(WebSocketEvents.announcementDeleted, (data) {
      _announcementController.add(data);
    });

    _socket!.on(WebSocketEvents.notificationSent, (data) {
      _notificationController.add(data);
    });

    _socket!.on(WebSocketEvents.systemAlert, (data) {
      _notificationController.add(data);
    });

    _socket!.on(WebSocketEvents.userConnected, (data) {
      _presenceController.add({
        'event': WebSocketEvents.userConnected,
        ..._safeMap(data),
      });
    });

    _socket!.on(WebSocketEvents.userDisconnected, (data) {
      _presenceController.add({
        'event': WebSocketEvents.userDisconnected,
        ..._safeMap(data),
      });
    });

    _socket!.on(WebSocketEvents.typingIndicator, (data) {
      _typingController.add({
        'event': WebSocketEvents.typingIndicator,
        ..._safeMap(data),
      });
    });

    _socket!.on(WebSocketEvents.typingStopped, (data) {
      _typingController.add({
        'event': WebSocketEvents.typingStopped,
        ..._safeMap(data),
      });
    });

    _socket!.on(WebSocketEvents.error, (data) {
      _connectionStatusController.add(ConnectionStatus.error);
    });

    _socket!.on(WebSocketEvents.rateLimitExceeded, (data) {
      _notificationController.add(data);
    });
  }

  void emitEvent(String event, Map<String, dynamic> data) {
    if (_socket?.connected == true) {
      _socket!.emit(event, data);
    } else {}
  }

  void joinRoom(String roomName) {
    if (_socket?.connected == true) {
      _socket!.emit(WebSocketEvents.joinRoom, roomName);
    } else {}
  }

  void leaveRoom(String roomName) {
    if (_socket?.connected == true) {
      _socket!.emit(WebSocketEvents.leaveRoom, roomName);
    } else {}
  }

  void _startIntervalRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(_refreshInterval, (timer) {
      _triggerIntervalRefresh();
    });
  }

  void _stopIntervalRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = null;
  }

  void _triggerIntervalRefresh() {
    if (_socket?.connected == true) {
      _checkConnectionStability().then((isStable) {
        if (isStable) {
          _socket!.emit('request_refresh', {
            'userId': _userId,
            'userRole': _userRole,
            'timestamp': DateTime.now().millisecondsSinceEpoch,
          });

          _messageController.add({
            'event': 'interval_refresh',
            'timestamp': DateTime.now().millisecondsSinceEpoch,
          });
        } else {}
      });
    }
  }

  Future<bool> _checkConnectionStability() async {
    try {
      final httpStable = await testHttpConnectivity();
      if (!httpStable) {
        return false;
      }

      if (_socket?.connected != true) {
        return false;
      }

      return true;
    } catch (e) {
      return false;
    }
  }

  Future<void> disconnect() async {
    _stopIntervalRefresh();
    if (_socket != null) {
      _socket!.disconnect();
      _socket!.dispose();
      _socket = null;
    }
    _userId = null;
    _userRole = null;
    _token = null;
    _connectionStatusController.add(ConnectionStatus.disconnected);
  }

  Future<bool> testHttpConnectivity() async {
    HttpClient? client;
    try {
      final uri = Uri.parse('${AppConfig.websocketUrl}/health');
      client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 15);
      client.idleTimeout = const Duration(seconds: 15);

      final request = await client
          .getUrl(uri)
          .timeout(const Duration(seconds: 10));
      final response = await request.close().timeout(
        const Duration(seconds: 10),
      );

      final statusCode = response.statusCode;

      client.close(force: true);
      client = null;

      return statusCode == 200;
    } catch (e) {
      if (client != null) {
        try {
          client.close(force: true);
        } catch (closeError) {}
      }
      return false;
    }
  }

  Future<bool> testConnection() async {
    IO.Socket? testSocket;
    Timer? timeoutTimer;
    try {
      final httpConnected = await testHttpConnectivity();
      if (!httpConnected) {
        return false;
      }

      testSocket = IO.io(
        AppConfig.websocketUrl,
        IO.OptionBuilder()
            .setTransports(['websocket', 'polling'])
            .disableAutoConnect()
            .setTimeout(15000)
            .setExtraHeaders({'Connection': 'Upgrade'})
            .setPath('/socket.io/')
            .enableForceNew()
            .build(),
      );

      final completer = Completer<bool>();
      bool isCompleted = false;

      testSocket.onConnect((_) {
        if (!isCompleted) {
          isCompleted = true;
          timeoutTimer?.cancel();

          testSocket?.disconnect();
          testSocket?.dispose();
          testSocket = null;
          completer.complete(true);
        }
      });

      testSocket?.onConnectError((error) {
        if (!isCompleted) {
          isCompleted = true;
          timeoutTimer?.cancel();

          testSocket?.disconnect();
          testSocket?.dispose();
          testSocket = null;
          completer.complete(false);
        }
      });

      testSocket?.connect();

      timeoutTimer = Timer(const Duration(seconds: 5), () {
        if (!isCompleted) {
          isCompleted = true;

          testSocket?.disconnect();
          testSocket?.dispose();
          testSocket = null;
          completer.complete(false);
        }
      });

      return await completer.future;
    } catch (e) {
      timeoutTimer?.cancel();

      if (testSocket != null) {
        try {
          testSocket?.disconnect();
          testSocket?.dispose();
        } catch (disposeError) {}
      }

      return false;
    }
  }

  void dispose() {
    disconnect();
    _connectionStatusController.close();
    _messageController.close();
    _notificationController.close();
    _payslipController.close();
    _leaveController.close();
    _employeeController.close();
    _eodController.close();
    _announcementController.close();
    _presenceController.close();
    _typingController.close();
  }

  Map<String, dynamic> _safeMap(dynamic data) {
    if (data is Map<String, dynamic>) return data;
    return {};
  }
}
