import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';
import 'package:talklynk_sdk/src/models/call.dart';
import 'package:talklynk_sdk/src/services/api_service.dart';
import 'package:talklynk_sdk/src/services/websocket_service.dart';

class CallProvider extends ChangeNotifier {
  final ApiService _apiService;
  final WebSocketService _webSocketService;
  final Logger _logger;

  Call? _currentCall;
  Call? _incomingCall;
  bool _isLoading = false;
  String? _error;
  bool _listenersSetup = false;

  // Add navigation callback
  Function(Call)? _onCallAcceptedCallback;
  Function(Call)? _onIncomingCallCallback;
  Function(Call)? _onCallRejectedCallback;
  Function(Call)? _onCallEndedCallback;

  StreamSubscription? _callEventsSubscription;
  StreamSubscription? _callRingingSubscription;
  StreamSubscription? _callAcceptedSubscription;
  StreamSubscription? _callRejectedSubscription;
  StreamSubscription? _callEndedSubscription;

  // Stream controllers for reactive programming
  final StreamController<Call?> currentCallController =
      StreamController<Call?>.broadcast();
  final StreamController<Call?> incomingCallController =
      StreamController<Call?>.broadcast();
  final StreamController<bool> _loadingController =
      StreamController<bool>.broadcast();
  final StreamController<String?> _errorController =
      StreamController<String?>.broadcast();

  CallProvider(this._apiService, this._webSocketService,
      {bool enableLogs = false})
      : _logger = Logger(
          printer: enableLogs ? PrettyPrinter() : PrettyPrinter(methodCount: 0),
          level: enableLogs ? Level.debug : Level.off,
        ) {
    _logger.d('📞 CallProvider created');
    // Don't setup listeners immediately - wait for explicit call
  }

  // Getters
  Call? get currentCall => _currentCall;
  Call? get incomingCall => _incomingCall;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasActiveCall => _currentCall?.isActive == true;
  bool get hasIncomingCall => _incomingCall?.isRinging == true;
  bool get listenersSetup => _listenersSetup;

  // Set navigation callbacks
  void setCallCallbacks({
    Function(Call)? onCallAccepted,
    Function(Call)? onIncomingCall,
    Function(Call)? onCallRejected,
    Function(Call)? onCallEnded,
  }) {
    _onCallAcceptedCallback = onCallAccepted;
    _onIncomingCallCallback = onIncomingCall;
    _onCallRejectedCallback = onCallRejected;
    _onCallEndedCallback = onCallEnded;
  }

  void _scheduleListenerSetup() {
    // Delay listener setup to ensure WebSocket is ready
    Future.delayed(Duration(milliseconds: 500), () {
      if (!_listenersSetup) {
        _setupCallEventListeners();
      }
    });
  }

  void ensureListenersSetup() {
    if (!_listenersSetup) {
      _logger.d('📞 Manually setting up call event listeners');
      _setupCallEventListeners();
    }
  }

  void _setupCallEventListeners() {
    if (_listenersSetup) {
      _logger.d('📞 Call event listeners already setup');
      return;
    }

    _logger.d('📞 Setting up call event listeners...');

    try {
      // Listen for call ringing events
      _callRingingSubscription = _webSocketService
          .on<Map<String, dynamic>>('call.ringing')
          .listen((data) {
        _logger.d('📞 Received call.ringing event: $data');
        _handleIncomingCall(data);
      });

      // Listen for call accepted events
      _callAcceptedSubscription = _webSocketService
          .on<Map<String, dynamic>>('call.accepted')
          .listen((data) {
        _logger.d('📞 Received call.accepted event: $data');
        _handleCallAccepted(data);
      });

      // Listen for call rejected events
      _callRejectedSubscription = _webSocketService
          .on<Map<String, dynamic>>('call.rejected')
          .listen((data) {
        _logger.d('📞 Received call.rejected event: $data');
        _handleCallRejected(data);
      });

      // Listen for call ended events
      _callEndedSubscription = _webSocketService
          .on<Map<String, dynamic>>('call.ended')
          .listen((data) {
        _logger.d('📞 Received call.ended event: $data');
        _handleCallEnded(data);
      });

      _listenersSetup = true;
      _logger.d('✅ Call event listeners setup completed');
    } catch (e, stackTrace) {
      _logger.e('❌ Failed to setup call event listeners: $e');
      _logger.e('Stack trace: $stackTrace');
    }
  }

  // Initiate a call with timeout handling
  Future<bool> initiateCall({
    required String callerId,
    required String calleeId,
    required CallType type,
    Map<String, dynamic>? metadata,
  }) async {
    _setLoading(true);
    _setError(null);

    try {
      _logger
          .d('📞 Initiating call from $callerId to $calleeId (${type.name})');

      final call = await _apiService.initiateCall(
        callerId: callerId,
        calleeId: calleeId,
        type: type,
        metadata: metadata,
      );

      _currentCall = call;
      _setLoading(false);
      notifyListeners();

      // Start call timeout timer (30 seconds)
      _startCallTimeout(call.callId);

      _logger.d('✅ Call initiated successfully: ${call.callId}');
      return true;
    } catch (e) {
      _logger.e('❌ Failed to initiate call: $e');
      _setError('Failed to initiate call: $e');
      _setLoading(false);
      return false;
    }
  }

  // Start timeout timer for outgoing calls
  Timer? _callTimeoutTimer;

  void _startCallTimeout(String callId) {
    _callTimeoutTimer?.cancel();
    _callTimeoutTimer = Timer(Duration(seconds: 30), () {
      if (_currentCall?.callId == callId &&
          _currentCall?.status == CallStatus.ringing) {
        _logger.w('📞 Call timeout for call: $callId');

        // End the call due to timeout
        _currentCall = _currentCall!.copyWith(
          status: CallStatus.missed,
          endedAt: DateTime.now(),
        );

        // Trigger callback for call timeout
        if (_onCallRejectedCallback != null) {
          _onCallRejectedCallback!(_currentCall!);
        }

        notifyListeners();

        // Clear after delay
        Future.delayed(Duration(seconds: 2), () {
          _currentCall = null;
          notifyListeners();
        });
      }
    });
  }

  // Accept incoming call
  Future<bool> acceptCall(String calleeId) async {
    if (_incomingCall == null) {
      _logger.w('⚠️ No incoming call to accept');
      return false;
    }

    _setLoading(true);
    _setError(null);

    try {
      _logger.d('📞 Accepting call: ${_incomingCall!.callId}');

      final call = await _apiService.acceptCall(
        callId: _incomingCall!.callId,
        calleeId: calleeId,
      );

      _currentCall = call.copyWith(status: CallStatus.active);
      _incomingCall = null;
      _setLoading(false);
      notifyListeners();

      _logger.d('✅ Call accepted successfully');
      return true;
    } catch (e) {
      _logger.e('❌ Failed to accept call: $e');
      _setError('Failed to accept call: $e');
      _setLoading(false);
      return false;
    }
  }

  // Reject incoming call
  Future<bool> rejectCall(String calleeId, {String? reason}) async {
    if (_incomingCall == null) {
      _logger.w('⚠️ No incoming call to reject');
      return false;
    }

    _setLoading(true);
    _setError(null);

    try {
      _logger.d('📞 Rejecting call: ${_incomingCall!.callId}, reason: $reason');

      await _apiService.rejectCall(
        callId: _incomingCall!.callId,
        calleeId: calleeId,
        reason: reason,
      );

      _incomingCall = null;
      _setLoading(false);
      notifyListeners();

      _logger.d('✅ Call rejected successfully');
      return true;
    } catch (e) {
      _logger.e('❌ Failed to reject call: $e');
      _setError('Failed to reject call: $e');
      _setLoading(false);
      return false;
    }
  }

  // End current call
  Future<void> endCall({String? userId, String? reason}) async {
    if (_currentCall == null) {
      _logger.w('⚠️ No current call to end');
      return;
    }

    try {
      _logger.d('📞 Ending call: ${_currentCall!.callId}');

      // Try to send end call request to server
      if (userId != null) {
        await _apiService.endCall(
          callId: _currentCall!.callId,
          userId: userId,
          reason: reason,
        );
      }

      _currentCall = _currentCall!.copyWith(
        status: CallStatus.ended,
        endedAt: DateTime.now(),
      );

      // Cancel timeout timer
      _callTimeoutTimer?.cancel();

      notifyListeners();

      // Clear after a short delay to allow UI to update
      Future.delayed(Duration(seconds: 2), () {
        _currentCall = null;
        notifyListeners();
        _logger.d('📞 Call cleared from state');
      });
    } catch (e) {
      _logger.e('❌ Failed to end call properly: $e');
      // Still update local state even if API call fails
      _currentCall = _currentCall!.copyWith(
        status: CallStatus.ended,
        endedAt: DateTime.now(),
      );
      notifyListeners();
    }
  }

  // Event handlers
  void _handleIncomingCall(Map<String, dynamic> data) {
    try {
      _logger.d('📞 Handling incoming call data: $data');

      final call = Call.fromJson(data);
      _incomingCall = call;

      // Add to incoming call stream
      incomingCallController.add(call);

      // Trigger callback for incoming call (to show incoming call UI)
      if (_onIncomingCallCallback != null) {
        _onIncomingCallCallback!(call);
      }

      notifyListeners();

      _logger.d('✅ Incoming call handled: ${call.callId}');
    } catch (e, stackTrace) {
      _logger.e('❌ Failed to handle incoming call: $e');
      _logger.e('Stack trace: $stackTrace');
      _setError('Failed to handle incoming call: $e');
    }
  }

  void _handleCallAccepted(Map<String, dynamic> data) {
    try {
      _logger.d('📞 Handling call accepted: $data');
      final call = Call.fromJson(data);
      if (_currentCall != call && _currentCall!.callId == call.callId) {
        _currentCall = call;
      }

      final callId = data['call_id'] ?? data['room']?['room_id'];

      if (_currentCall != null && _currentCall!.callId == callId) {
        // Cancel timeout timer since call was accepted
        _callTimeoutTimer?.cancel();

        _currentCall = _currentCall!.copyWith(
          status: CallStatus.active,
          answeredAt: DateTime.now(),
        );

        // Add to current call stream
        currentCallController.add(_currentCall);

        // Trigger callback to navigate to call screen
        if (_onCallAcceptedCallback != null) {
          _onCallAcceptedCallback!(_currentCall!);
        }

        notifyListeners();
        _logger.d('✅ Call accepted handled for: $callId');
      } else {
        _logger.w('⚠️ Call accepted for unknown call: $callId');
      }
    } catch (e, stackTrace) {
      _logger.e('❌ Failed to handle call accepted: $e');
      _logger.e('Stack trace: $stackTrace');
      _setError('Failed to handle call accepted: $e');
    }
  }

  void _handleCallRejected(Map<String, dynamic> data) {
    try {
      _logger.d('📞 Handling call rejected: $data');

      final callId = data['call_id'] ?? data['room']?['room_id'];
      final reason = data['reason'] ?? data['rejection_reason'];

      if (_currentCall != null && _currentCall!.callId == callId) {
        // Cancel timeout timer
        _callTimeoutTimer?.cancel();

        _currentCall = _currentCall!.copyWith(
          status: CallStatus.rejected,
          endedAt: DateTime.now(),
          rejectionReason: reason,
        );

        // Add to current call stream
        currentCallController.add(_currentCall);

        // Trigger callback for call rejection
        if (_onCallRejectedCallback != null) {
          _onCallRejectedCallback!(_currentCall!);
        }

        notifyListeners();
        _logger.d('✅ Call rejected handled for: $callId');

        // Clear after delay
        Future.delayed(Duration(seconds: 3), () {
          _currentCall = null;
          currentCallController.add(null);
          notifyListeners();
        });
      } else {
        _logger.w('⚠️ Call rejected for unknown call: $callId');
      }
    } catch (e, stackTrace) {
      _logger.e('❌ Failed to handle call rejected: $e');
      _logger.e('Stack trace: $stackTrace');
      _setError('Failed to handle call rejected: $e');
    }
  }

  void _handleCallEnded(Map<String, dynamic> data) {
    try {
      _logger.d('📞 Handling call ended: $data');

      final callId = data['call_id'] ?? data['room']?['room_id'];

      if (_currentCall != null && _currentCall!.callId == callId) {
        // Cancel timeout timer
        _callTimeoutTimer?.cancel();

        _currentCall = _currentCall!.copyWith(
          status: CallStatus.ended,
          endedAt: DateTime.now(),
        );

        // Add to current call stream
        currentCallController.add(_currentCall);

        // Trigger callback for call ended
        if (_onCallEndedCallback != null) {
          _onCallEndedCallback!(_currentCall!);
        }

        notifyListeners();
        _logger.d('✅ Call ended handled for: $callId');

        // Clear after delay
        Future.delayed(Duration(seconds: 2), () {
          _currentCall = null;
          currentCallController.add(null);
          notifyListeners();
        });
      } else {
        _logger.w('⚠️ Call ended for unknown call: $callId');
      }

      // Also clear incoming call if it matches
      if (_incomingCall != null && _incomingCall!.callId == callId) {
        _incomingCall = null;
        incomingCallController.add(null);
        notifyListeners();
      }
    } catch (e, stackTrace) {
      _logger.e('❌ Failed to handle call ended: $e');
      _logger.e('Stack trace: $stackTrace');
      _setError('Failed to handle call ended: $e');
    }
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    _loadingController.add(loading);
    notifyListeners();
  }

  void _setError(String? error) {
    _error = error;
    _errorController.add(error);
    if (error != null) {
      _logger.e('📞 CallProvider error: $error');
      notifyListeners();
    }
  }

  void clearError() {
    _error = null;
    _errorController.add(null);
    notifyListeners();
  }

  // Debug method to check listener status
  Map<String, dynamic> getDebugInfo() {
    return {
      'listenersSetup': _listenersSetup,
      'webSocketConnected': _webSocketService.isConnected,
      'hasIncomingCall': hasIncomingCall,
      'hasActiveCall': hasActiveCall,
      'isLoading': _isLoading,
      'error': _error,
      'currentCallId': _currentCall?.callId,
      'incomingCallId': _incomingCall?.callId,
      'currentCallStatus': _currentCall?.status.name,
      'incomingCallStatus': _incomingCall?.status.name,
    };
  }

  // Force re-setup listeners (for debugging)
  void forceSetupListeners() {
    _logger.d('🔄 Forcing listener re-setup');
    _listenersSetup = false;

    // Cancel existing subscriptions
    _callRingingSubscription?.cancel();
    _callAcceptedSubscription?.cancel();
    _callRejectedSubscription?.cancel();
    _callEndedSubscription?.cancel();

    // Setup again
    _setupCallEventListeners();
  }

  // Test method to simulate incoming call (for debugging)
  void simulateIncomingCall({
    String? callId,
    String? callerName,
    CallType type = CallType.video,
  }) {
    _logger.d('🧪 Simulating incoming call for testing');

    final testCallData = {
      'call_id': callId ?? 'test_call_${DateTime.now().millisecondsSinceEpoch}',
      'room': {
        'id': 'test_room',
        'name': 'Test Call',
        'type': type.name,
      },
      'caller': {
        'id': 'test_caller',
        'name': callerName ?? 'Test Caller',
        'external_id': 'test_caller_ext',
      },
      'callee': {
        'id': 'current_user',
        'name': 'Current User',
        'external_id': 'current_user_ext',
      },
      'timestamp': DateTime.now().toIso8601String(),
    };

    _handleIncomingCall(testCallData);
  }

  @override
  void dispose() {
    _logger.d('📞 Disposing CallProvider...');

    _callEventsSubscription?.cancel();
    _callRingingSubscription?.cancel();
    _callAcceptedSubscription?.cancel();
    _callRejectedSubscription?.cancel();
    _callEndedSubscription?.cancel();
    _callTimeoutTimer?.cancel();

    currentCallController.close();
    incomingCallController.close();
    _loadingController.close();
    _errorController.close();

    super.dispose();
  }
}
