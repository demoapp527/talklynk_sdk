import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:talklynk_sdk/src/models/call.dart';
import 'package:talklynk_sdk/src/models/user.dart';
import 'package:talklynk_sdk/src/services/api_service.dart';
import 'package:talklynk_sdk/src/services/websocket_service.dart';

class CallProvider extends ChangeNotifier {
  final ApiService _apiService;
  final WebSocketService _webSocketService;

  Call? _currentCall;
  Call? _incomingCall;
  bool _isLoading = false;
  String? _error;

  StreamSubscription? _callEventsSubscription;

  CallProvider(this._apiService, this._webSocketService) {
    _setupCallEventListeners();
  }

  // Getters
  Call? get currentCall => _currentCall;
  Call? get incomingCall => _incomingCall;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasActiveCall => _currentCall?.isActive == true;
  bool get hasIncomingCall => _incomingCall?.isRinging == true;

  void _setupCallEventListeners() {
    // Listen for call ringing events
    _webSocketService.on<Map<String, dynamic>>('call.ringing').listen((data) {
      _handleIncomingCall(data);
    });

    // Listen for call accepted events
    _webSocketService.on<Map<String, dynamic>>('call.accepted').listen((data) {
      _handleCallAccepted(data);
    });

    // Listen for call rejected events
    _webSocketService.on<Map<String, dynamic>>('call.rejected').listen((data) {
      _handleCallRejected(data);
    });

    // Listen for call ended events
    _webSocketService.on<Map<String, dynamic>>('call.ended').listen((data) {
      _handleCallEnded(data);
    });
  }

  // Initiate a call
  Future<bool> initiateCall({
    required String callerId,
    required String calleeId,
    required CallType type,
    Map<String, dynamic>? metadata,
  }) async {
    _setLoading(true);
    _setError(null);

    try {
      final call = await _apiService.initiateCall(
        callerId: callerId,
        calleeId: calleeId,
        type: type,
        metadata: metadata,
      );

      _currentCall = call;
      _setLoading(false);
      notifyListeners();
      return true;
    } catch (e) {
      _setError('Failed to initiate call: $e');
      _setLoading(false);
      return false;
    }
  }

  // Accept incoming call
  Future<bool> acceptCall(String calleeId) async {
    if (_incomingCall == null) return false;

    _setLoading(true);
    _setError(null);

    try {
      final call = await _apiService.acceptCall(
        callId: _incomingCall!.callId,
        calleeId: calleeId,
      );

      _currentCall = call.copyWith(status: CallStatus.active);
      _incomingCall = null;
      _setLoading(false);
      notifyListeners();
      return true;
    } catch (e) {
      _setError('Failed to accept call: $e');
      _setLoading(false);
      return false;
    }
  }

  // Reject incoming call
  Future<bool> rejectCall(String calleeId, {String? reason}) async {
    if (_incomingCall == null) return false;

    _setLoading(true);
    _setError(null);

    try {
      await _apiService.rejectCall(
        callId: _incomingCall!.callId,
        calleeId: calleeId,
        reason: reason,
      );

      _incomingCall = null;
      _setLoading(false);
      notifyListeners();
      return true;
    } catch (e) {
      _setError('Failed to reject call: $e');
      _setLoading(false);
      return false;
    }
  }

  // End current call
  void endCall() {
    if (_currentCall != null) {
      _currentCall = _currentCall!.copyWith(
        status: CallStatus.ended,
        endedAt: DateTime.now(),
      );
      notifyListeners();

      // Clear after a short delay to allow UI to update
      Future.delayed(Duration(seconds: 2), () {
        _currentCall = null;
        notifyListeners();
      });
    }
  }

  // Event handlers
  void _handleIncomingCall(Map<String, dynamic> data) {
    try {
      final call = Call.fromJson(data);
      _incomingCall = call;
      notifyListeners();
    } catch (e) {
      _setError('Failed to handle incoming call: $e');
    }
  }

  void _handleCallAccepted(Map<String, dynamic> data) {
    try {
      if (_currentCall != null && _currentCall!.callId == data['call_id']) {
        _currentCall = _currentCall!.copyWith(
          status: CallStatus.active,
          answeredAt: DateTime.now(),
        );
        notifyListeners();
      }
    } catch (e) {
      _setError('Failed to handle call accepted: $e');
    }
  }

  void _handleCallRejected(Map<String, dynamic> data) {
    try {
      if (_currentCall != null && _currentCall!.callId == data['call_id']) {
        _currentCall = _currentCall!.copyWith(
          status: CallStatus.rejected,
          endedAt: DateTime.now(),
          rejectionReason: data['reason'],
        );
        notifyListeners();

        // Clear after delay
        Future.delayed(Duration(seconds: 3), () {
          _currentCall = null;
          notifyListeners();
        });
      }
    } catch (e) {
      _setError('Failed to handle call rejected: $e');
    }
  }

  void _handleCallEnded(Map<String, dynamic> data) {
    try {
      if (_currentCall != null && _currentCall!.callId == data['call_id']) {
        _currentCall = _currentCall!.copyWith(
          status: CallStatus.ended,
          endedAt: DateTime.now(),
        );
        notifyListeners();

        // Clear after delay
        Future.delayed(Duration(seconds: 2), () {
          _currentCall = null;
          notifyListeners();
        });
      }
    } catch (e) {
      _setError('Failed to handle call ended: $e');
    }
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

  @override
  void dispose() {
    _callEventsSubscription?.cancel();
    super.dispose();
  }
}
