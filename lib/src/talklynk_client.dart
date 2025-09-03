import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:talklynk_sdk/talklynk_sdk.dart';

class TalkLynkSDK {
  static TalkLynkSDK? _instance;
  static TalkLynkSDK get instance => _instance!;

  late final ApiService _apiService;
  late final WebSocketService _webSocketService;
  late final AuthProvider _authProvider;
  late final CallProvider _callProvider;
  late final RoomProvider _roomProvider;
  late final EventProvider _eventProvider;

  bool _initialized = false;

  CallProvider? get callProvider => _callProvider;

  TalkLynkSDK._();

  static Future<TalkLynkSDK> initialize({
    required String baseUrl,
    required String wsUrl,
    required String apiKey,
    required String pusherAppKey,
    bool enableLogs = false,
  }) async {
    if (_instance != null) {
      throw Exception('TalkLynkSDK already initialized');
    }

    _instance = TalkLynkSDK._();
    await _instance!._init(
      baseUrl: baseUrl,
      wsUrl: wsUrl,
      apiKey: apiKey,
      pusherAppKey: pusherAppKey,
      enableLogs: enableLogs,
    );

    return _instance!;
  }

  Future<void> _init({
    required String baseUrl,
    required String wsUrl,
    required String apiKey,
    required String pusherAppKey,
    bool enableLogs = false,
  }) async {
    // Initialize services
    _apiService = ApiService(
      baseUrl: baseUrl,
      apiKey: apiKey,
      enableLogs: enableLogs,
    );

    _webSocketService = WebSocketService(
      baseUrl: baseUrl,
      wsUrl: wsUrl,
      apiKey: apiKey,
      pusherAppKey: pusherAppKey,
      enableLogs: enableLogs,
    );

    // Initialize providers
    _authProvider = AuthProvider(_apiService);
    _callProvider = CallProvider(_apiService, _webSocketService);
    _roomProvider = RoomProvider(_apiService, _webSocketService);
    _eventProvider = EventProvider(_webSocketService);

    _initialized = true;
  }

  /// Wrap your app with this to provide SDK contexts
  Widget wrapApp(Widget app) {
    if (!_initialized) {
      throw Exception(
          'TalkLynkSDK not initialized. Call TalkLynkSDK.initialize() first.');
    }

    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: _authProvider),
        ChangeNotifierProvider.value(value: _callProvider),
        ChangeNotifierProvider.value(value: _roomProvider),
        ChangeNotifierProvider.value(value: _eventProvider),
        ChangeNotifierProvider(
          create: (context) => WebRTCService(
            apiService: TalkLynkSDK.instance.api,
            webSocketService: TalkLynkSDK.instance.websocket,
            baseUrl: TalkLynkSDK.instance.api.baseUrl,
            enableLogs: true,
          ),
        ),
      ],
      child: app,
    );
  }

  // Getters for providers
  AuthProvider get auth => _authProvider;
  CallProvider get call => _callProvider;
  RoomProvider get room => _roomProvider;
  EventProvider get event => _eventProvider;

  // Services
  ApiService get api => _apiService;
  WebSocketService get websocket => _webSocketService;

  Future<void> dispose() async {
    _webSocketService.disconnect();
    _apiService.dispose();
    _initialized = false;
    _instance = null;
  }
}
