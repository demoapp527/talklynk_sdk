import 'package:flutter/foundation.dart';
import 'package:talklynk_sdk/talklynk_sdk.dart';

class AuthProvider extends ChangeNotifier {
  final ApiService _apiService;

  User? _currentUser;
  bool _isAuthenticated = false;
  bool _isLoading = false;
  String? _error;

  AuthProvider(this._apiService);

  // Getters
  User? get currentUser => _currentUser;
  bool get isAuthenticated => _isAuthenticated;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // Login with username (creates user if doesn't exist)
  Future<bool> login({
    required String username,
    String? externalId,
    String? avatarUrl,
    Map<String, dynamic>? metadata,
  }) async {
    _setLoading(true);
    _setError(null);

    try {
      // Try to create user (will return existing if already exists)
      final user = await _apiService.loginOrCreateUser(
        username: username,
        externalId: externalId,
        avatarUrl: avatarUrl,
        metadata: metadata,
      );

      _currentUser = user;
      _isAuthenticated = true;
      await _subscribeToUserChannel(user);
      await _setupCallEventListeners();
      _setLoading(false);
      notifyListeners();
      return true;
    } catch (e) {
      _setError('Login failed: $e');
      _setLoading(false);
      return false;
    }
  }

  void logout() {
    _currentUser = null;
    _isAuthenticated = false;
    _setError(null);
    notifyListeners();
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String? error) {
    _error = error;
    if (error != null) notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  Future<void> _subscribeToUserChannel(User user) async {
    try {
      // Connect to WebSocket if not already connected
      if (!TalkLynkSDK.instance.websocket.isConnected) {
        await TalkLynkSDK.instance.websocket.connect();
      }

      // Subscribe to user's personal channel for receiving calls
      TalkLynkSDK.instance.websocket.subscribeToUserChannel(
          user.externalId ?? user.id,
          user.clientId.toString() ??
              'default_client_id' // You need to get this from your user model
          );
    } catch (e) {
      print('Failed to subscribe to user channel: $e');
    }
  }

  Future<void> _setupCallEventListeners() async {
    try {
      print('📞 Setting up call event listeners after login...');

      // Get the CallProvider from the global context and setup listeners
      final callProvider = TalkLynkSDK.instance.callProvider;
      if (callProvider != null) {
        callProvider.ensureListenersSetup();
        print('✅ Call event listeners setup completed');
      } else {
        print('❌ CallProvider not available');
      }
    } catch (e) {
      print('Failed to setup call event listeners: $e');
    }
  }
}
