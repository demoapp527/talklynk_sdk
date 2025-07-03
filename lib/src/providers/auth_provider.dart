import 'package:flutter/foundation.dart';
import 'package:talklynk_sdk/src/models/user.dart';
import 'package:talklynk_sdk/src/services/api_service.dart';

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
      final user = await _apiService.createUser(
        name: username,
        externalId: externalId,
        avatarUrl: avatarUrl,
        metadata: metadata,
      );

      _currentUser = user;
      _isAuthenticated = true;

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
}
