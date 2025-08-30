import 'dart:async';
import 'dart:developer';

import 'package:socket_io_client/socket_io_client.dart' as io;

class EmittedSocketDetail {
  EmittedSocketDetail(this.event, this.data);
  final String event;
  final dynamic data;
}

class SocketService {
  SocketService._();

  // Add these new properties
  // bool _isRefreshing = false;
  bool _isReconnecting = false;

  static SocketService? _instance;
  late io.Socket? socket;
  bool isInitialized = false;

  // List of Emitted SocketDetails
  List<EmittedSocketDetail> emittedSocketDetails = <EmittedSocketDetail>[];
  // Map of event names to callbacks
  final Map<String, List<void Function(dynamic)>> _eventListeners =
      <String, List<void Function(dynamic p1)>>{};

  bool get isConnected => socket?.connected ?? false;

  static SocketService get instance {
    _instance ??= SocketService._();
    return _instance!;
  }

  // Future<JSON?>? _attemptRefeshToken(String baseUrl) async {
  // if (_isRefreshing) {
  //   return null;
  // }
  // _isRefreshing = true;

  // try {
  //   final JSON? response = await ApiManager.apiService.get(
  //     endpoint: '/user/me',
  //     requiresAuthToken: true,
  //     converter: (JSON? response) {
  //       return response;
  //     },
  //   );

  //   return (response?['data'] as Map<String, dynamic>)['user']
  //       as Map<String, dynamic>;
  // } finally {
  //   _isRefreshing = false;
  // }
  // }

  Future<void> initialize(
      String baseUrl, String socketBaseUrl, String? accessToken) async {
    if (isInitialized) {
      return;
    }

    try {
      if (accessToken != null) {
        socket = io.io(
          socketBaseUrl,
          io.OptionBuilder()
              .setTransports(<String>['websocket'])
              .setAuth(<String, dynamic>{
                'token': accessToken,
              })
              .disableAutoConnect()
              .enableReconnection()
              .enableForceNewConnection()
              .build(),
        );
        _setupSocketListeners(baseUrl, socketBaseUrl);
        socket?.connect();
        isInitialized = true;
      } else {
        isInitialized = false;
      }
    } catch (e) {
      isInitialized = false;
      log('Socket exception : $e');
    }
  }

  void _setupSocketListeners(String baseUrl, String socketBaseUrl) {
    socket?.onConnect((dynamic event) {
      log('Socket onConnect : $event');

      if (_isReconnecting) {
        for (final EmittedSocketDetail socketEmitted in emittedSocketDetails) {
          socket?.emit(socketEmitted.event, socketEmitted.data);
          log('socketEmitted --- ${socketEmitted.event}');
        }

        // Re-register event listeners
        _reRegisterListeners();
        _isReconnecting = false;
      }
    });

    socket?.onPing((dynamic event) {
      log('---------Socket onPing----------');
    });

    socket?.onPong((dynamic event) {
      log('---------Socket onPong----------');
    });

    socket?.onDisconnect((_) {
      log('Socket onDisconnect');
    });

    socket?.onReconnect((_) {
      log('Socket onReconnect');

      for (final EmittedSocketDetail socketEmitted in emittedSocketDetails) {
        socket?.emit(socketEmitted.event, socketEmitted.data);
        log('socketEmitted --- ${socketEmitted.event}');
      }
    });

    socket?.onError((dynamic error) {
      log('Socket onError: $error');
    });

    socket?.on('connect_error', (dynamic err) {
      log('Socket connect_error: $err');
    });

    socket?.on('error', (dynamic err) async {
      log('Socket error : $err');

      if (err is Map) {
        final String? reason =
            (err['data'] as Map<String, dynamic>?)?['reason'] as String?;

        log('-------err is a map ------$reason');

        // if (reason == SocketAuthErrorReason.Unauthorized.value) {
        //   try {
        //     final JSON? userData = await _attemptRefeshToken(baseUrl);

        //     if (userData != null) {
        //       final SharedPreferences prefs =
        //           await SharedPreferences.getInstance();
        //       final AppUser appUser = AppUser.fromJson(userData);
        //       PreferencesClient(prefs: prefs).saveUser(appUser: appUser);

        //       socket?.dispose();
        //       socket = null;
        //       io.cache.clear();

        //       _isReconnecting = true;
        //       isInitialized = false;
        //       initialize('', '', '');
        //     } else {
        //       dispose();
        //     }
        //   } catch (e) {
        //     log('//////catch _attemptRefeshToken////////////////$e');
        //     dispose();
        //   }
        // }
      } else {
        log('-------err is not a map');
      }
    });
  }

  void emit(String event, dynamic data) {
    try {
      socket?.emit(event, data);

      if (emittedSocketDetails
          .any((EmittedSocketDetail detail) => detail.event == event)) {
        emittedSocketDetails
            .removeWhere((EmittedSocketDetail detail) => detail.event == event);
      }
      emittedSocketDetails.add(EmittedSocketDetail(event, data));
    } catch (e) {
      isInitialized = false;
      log('Socket exception : $e');
    }
  }

  void on(String event, void Function(dynamic) callback) {
    socket?.on(event, callback);

    if (_eventListeners.containsKey(event)) {
      _eventListeners[event]!.add(callback);
    } else {
      _eventListeners[event] = <void Function(dynamic p1)>[callback];
    }
  }

  void _reRegisterListeners() {
    _eventListeners
        .forEach((String event, List<void Function(dynamic p1)> callbacks) {
      for (final void Function(dynamic p1) callback in callbacks) {
        log('socket on --- $event');
        socket?.on(event, callback);
      }
    });
  }

  void _cancelRegisterListeners() {
    _eventListeners
        .forEach((String event, List<void Function(dynamic p1)> callbacks) {
      for (final void Function(dynamic p1) callback in callbacks) {
        log('socket off --- $event');
        socket?.off(event, callback);
      }
    });
  }

  void off(String event) {
    socket?.off(event);
  }

  void disconnect() {
    if (socket?.active ?? false) {
      _cancelRegisterListeners();
      emittedSocketDetails = <EmittedSocketDetail>[];
      _eventListeners.clear();

      socket?.disconnect();
    }
    isInitialized = false;
  }

  void dispose() {
    if (socket?.active ?? false) {
      _cancelRegisterListeners();
      emittedSocketDetails = <EmittedSocketDetail>[];
      _eventListeners.clear();

      socket?.dispose();
      socket = null;
      io.cache.clear();
    }
    isInitialized = false;
  }
}
