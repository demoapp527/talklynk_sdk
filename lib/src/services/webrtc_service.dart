// lib/src/services/webrtc_service.dart
// Updated to handle unified webrtc.signaling event with type-based routing

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:logger/logger.dart';
import 'package:talklynk_sdk/talklynk_sdk.dart';

enum WebRTCConnectionState {
  disconnected,
  connecting,
  connected,
  failed,
  closed,
}

enum MediaState {
  enabled,
  disabled,
  unavailable,
}

class MediaStates {
  final MediaState audio;
  final MediaState video;
  final MediaState speaker;

  const MediaStates({
    this.audio = MediaState.enabled,
    this.video = MediaState.enabled,
    this.speaker = MediaState.disabled,
  });

  MediaStates copyWith({
    MediaState? audio,
    MediaState? video,
    MediaState? speaker,
  }) {
    return MediaStates(
      audio: audio ?? this.audio,
      video: video ?? this.video,
      speaker: speaker ?? this.speaker,
    );
  }
}

class TurnCredentials {
  final List<Map<String, dynamic>> iceServers;

  const TurnCredentials({
    required this.iceServers,
  });

  factory TurnCredentials.fromJson(Map<String, dynamic> json) {
    return TurnCredentials(
      iceServers: List<Map<String, dynamic>>.from(json['iceServers'] ?? []),
    );
  }
}

class WebRTCService extends ChangeNotifier {
  final ApiService _apiService;
  final WebSocketService _webSocketService;
  final Logger _logger;
  final String _baseUrl;

  // WebRTC Components
  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  MediaStream? _remoteStream;

  // State Management
  WebRTCConnectionState _connectionState = WebRTCConnectionState.disconnected;
  MediaStates _mediaStates = const MediaStates();
  bool _isInitialized = false;
  String? _currentRoomId;
  String? _currentUserId;
  String? _remoteUserId;
  CallType? _currentCallType;

  // TURN Credentials Management
  TurnCredentials? _turnCredentials;

  // Event Streams
  final StreamController<RTCVideoRenderer> _localVideoController =
      StreamController<RTCVideoRenderer>.broadcast();
  final StreamController<RTCVideoRenderer> _remoteVideoController =
      StreamController<RTCVideoRenderer>.broadcast();
  final StreamController<WebRTCConnectionState> _connectionStateController =
      StreamController<WebRTCConnectionState>.broadcast();
  final StreamController<MediaStates> _mediaStatesController =
      StreamController<MediaStates>.broadcast();

  // Video Renderers
  final RTCVideoRenderer localRenderer = RTCVideoRenderer();
  final RTCVideoRenderer remoteRenderer = RTCVideoRenderer();

  // WebSocket Event Subscriptions
  StreamSubscription? _signalingSubscription;

  // Store pending ICE candidates
  final List<RTCIceCandidate> _pendingCandidates = [];

  // Default STUN servers (fallback)
  static const List<Map<String, dynamic>> _defaultStunServers = [
    {'urls': 'stun:stun.l.google.com:19302'},
    {'urls': 'stun:stun1.l.google.com:19302'},
    {'urls': 'stun:stun2.l.google.com:19302'},
  ];

  // FIXED: Updated configuration for Unified Plan
  static const Map<String, dynamic> _config = {
    'mandatory': {},
    'optional': [
      {'DtlsSrtpKeyAgreement': true},
    ]
  };

  // FIXED: Updated constraints for Unified Plan
  static const Map<String, dynamic> _constraints = {
    'mandatory': {
      'OfferToReceiveAudio': true,
      'OfferToReceiveVideo': true,
    },
    'optional': [],
  };

  WebRTCService({
    required ApiService apiService,
    required WebSocketService webSocketService,
    required String baseUrl,
    bool enableLogs = false,
  })  : _apiService = apiService,
        _webSocketService = webSocketService,
        _baseUrl = baseUrl,
        _logger = Logger(
          printer: enableLogs ? PrettyPrinter() : PrettyPrinter(methodCount: 0),
          level: enableLogs ? Level.debug : Level.off,
        ) {
    _setupWebSocketListeners();
  }

  // Getters
  WebRTCConnectionState get connectionState => _connectionState;
  MediaStates get mediaStates => _mediaStates;
  bool get isInitialized => _isInitialized;
  bool get isConnected => _connectionState == WebRTCConnectionState.connected;
  bool get isAudioEnabled => _mediaStates.audio == MediaState.enabled;
  bool get isVideoEnabled => _mediaStates.video == MediaState.enabled;
  bool get isSpeakerEnabled => _mediaStates.speaker == MediaState.enabled;
  MediaStream? get localStream => _localStream;
  MediaStream? get remoteStream => _remoteStream;

  // Streams
  Stream<RTCVideoRenderer> get localVideoStream => _localVideoController.stream;
  Stream<RTCVideoRenderer> get remoteVideoStream =>
      _remoteVideoController.stream;
  Stream<WebRTCConnectionState> get connectionStateStream =>
      _connectionStateController.stream;
  Stream<MediaStates> get mediaStatesStream => _mediaStatesController.stream;

  /// Initialize WebRTC service
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      _logger.d('🎥 Initializing WebRTC service...');

      // Initialize video renderers
      await localRenderer.initialize();
      await remoteRenderer.initialize();

      // Fetch TURN credentials
      await _fetchTurnCredentials();

      _isInitialized = true;
      _logger.d('✅ WebRTC service initialized successfully');
    } catch (e, stackTrace) {
      _logger.e('❌ Failed to initialize WebRTC service: $e');
      throw WebRTCException('Failed to initialize WebRTC service: $e');
    }
  }

  /// Fetch TURN credentials from API
  Future<void> _fetchTurnCredentials() async {
    try {
      _logger.d('🔄 Fetching TURN credentials...');

      final response = await _apiService.getTurnCredentials();

      _turnCredentials = response;
      _logger.d('✅ TURN credentials fetched successfully');
      _logger.d('🔧 ICE Servers count: ${_turnCredentials!.iceServers.length}');

      // Log TURN server details for debugging
      for (final server in _turnCredentials!.iceServers) {
        _logger.d('🌐 ICE Server: ${server['urls']}');
        if (server.containsKey('username')) {
          _logger.d('👤 Username: ${server['username']}');
        }
      }
    } catch (e) {
      _logger.e('❌ Error fetching TURN credentials: $e');
      // Use default STUN servers as fallback
      _turnCredentials = const TurnCredentials(iceServers: _defaultStunServers);
    }
  }

  /// FIXED: Get ICE servers configuration with explicit Unified Plan
  Map<String, dynamic> _getIceServersConfig() {
    final iceServers = <Map<String, dynamic>>[];

    // Add STUN servers (always include for fallback)
    iceServers.addAll(_defaultStunServers);

    // Add TURN servers from credentials
    if (_turnCredentials != null) {
      iceServers.addAll(_turnCredentials!.iceServers);
    }

    return {
      'iceServers': iceServers,
      'sdpSemantics': 'unified-plan', // CRITICAL: Explicitly set Unified Plan
    };
  }

  /// Start a call (caller side)
  Future<void> startCall({
    required String roomId,
    required String userId,
    required String remoteUserId,
    required CallType callType,
  }) async {
    try {
      _logger.d('📞 Starting call - Room: $roomId, Type: ${callType.name}');

      _currentRoomId = roomId;
      _currentUserId = userId;
      _remoteUserId = remoteUserId;
      _currentCallType = callType;
      _webSocketService.subscribeToRoom(roomId);
      // Create peer connection
      await _createPeerConnection();

      // Get user media
      await _getUserMedia(callType);

      // Create and send offer
      await _createOffer();
    } catch (e, stackTrace) {
      _logger.e('❌ Failed to start call: $e');
      await _cleanup();
      throw WebRTCException('Failed to start call: $e');
    }
  }

  /// Answer a call (callee side)
  Future<void> answerCall({
    required String roomId,
    required String userId,
    required String remoteUserId,
    required CallType callType,
  }) async {
    try {
      _logger.d('📞 Answering call - Room: $roomId, Type: ${callType.name}');
      _webSocketService.subscribeToRoom(roomId);
      _currentRoomId = roomId;
      _currentUserId = userId;
      _remoteUserId = remoteUserId;
      _currentCallType = callType;

      // Create peer connection
      await _createPeerConnection();

      // Get user media
      await _getUserMedia(callType);

      _updateConnectionState(WebRTCConnectionState.connecting);
    } catch (e, stackTrace) {
      _logger.e('❌ Failed to answer call: $e');
      await _cleanup();
      throw WebRTCException('Failed to answer call: $e');
    }
  }

  /// FIXED: Create peer connection with proper event handlers
  Future<void> _createPeerConnection() async {
    try {
      _logger.d('🔗 Creating peer connection...');

      final configuration = _getIceServersConfig();
      _logger.d('🔧 ICE Configuration: $configuration');

      _peerConnection = await createPeerConnection(configuration, _config);

      // FIXED: Set up event handlers for Unified Plan
      _peerConnection!.onIceCandidate = _onIceCandidate;
      _peerConnection!.onIceConnectionState = _onIceConnectionState;

      // FIXED: Use onTrack instead of onAddStream for Unified Plan
      _peerConnection!.onTrack = _onTrack;
      _peerConnection!.onRemoveStream = _onRemoveStream;
      _peerConnection!.onDataChannel = _onDataChannel;
      _peerConnection!.onRenegotiationNeeded = _onRenegotiationNeeded;

      _logger.d('✅ Peer connection created successfully');
    } catch (e, stackTrace) {
      _logger.e('❌ Failed to create peer connection: $e');
      throw WebRTCException('Failed to create peer connection: $e');
    }
  }

  /// FIXED: Get user media and add tracks individually
  Future<void> _getUserMedia(CallType callType) async {
    try {
      _logger.d('🎤 Getting user media for ${callType.name} call...');

      final mediaConstraints = <String, dynamic>{
        'audio': {
          'echoCancellation': true,
          'noiseSuppression': true,
          'autoGainControl': true,
        },
        'video': callType == CallType.video
            ? {
                'mandatory': {
                  'minWidth': '640',
                  'minHeight': '480',
                  'minFrameRate': '15',
                  'maxFrameRate': '30',
                },
                'facingMode': 'user',
                'optional': [],
              }
            : false,
      };

      _localStream =
          await navigator.mediaDevices.getUserMedia(mediaConstraints);

      if (_localStream != null) {
        // FIXED: Add tracks individually instead of using addStream
        for (final track in _localStream!.getTracks()) {
          await _peerConnection!.addTrack(track, _localStream!);
          _logger.d('➕ Added ${track.kind} track to peer connection');
        }

        // Set local video
        localRenderer.srcObject = _localStream;
        _localVideoController.add(localRenderer);

        // Update media states
        _updateMediaStates(_mediaStates.copyWith(
          audio: MediaState.enabled,
          video: callType == CallType.video
              ? MediaState.enabled
              : MediaState.disabled,
        ));

        _logger.d('✅ User media obtained and tracks added successfully');
      }
    } catch (e, stackTrace) {
      _logger.e('❌ Failed to get user media: $e');
      throw WebRTCException('Failed to access camera/microphone: $e');
    }
  }

  /// Create and send offer
  Future<void> _createOffer() async {
    try {
      _logger.d('📤 Creating offer...');

      final offer = await _peerConnection!.createOffer(_constraints);
      await _peerConnection!.setLocalDescription(offer);

      // Send offer via API
      await _apiService.postOffer(data: {
        'room_id': _currentRoomId,
        'target_user_id': _remoteUserId,
        'caller_id': _currentUserId,
        'offer': {
          'type': offer.type,
          'sdp': offer.sdp,
        },
      });

      _updateConnectionState(WebRTCConnectionState.connecting);
      _logger.d('✅ Offer created and sent successfully');
    } catch (e, stackTrace) {
      _logger.e('❌ Failed to create offer: $e');
      throw WebRTCException('Failed to create offer: $e');
    }
  }

  /// FIXED: Create and send answer with proper ICE candidate handling
  Future<void> _createAnswer(Map<String, dynamic> offer) async {
    try {
      _logger.d('📤 Creating answer...');

      final remoteDesc = RTCSessionDescription(offer['sdp'], offer['type']);
      await _peerConnection!.setRemoteDescription(remoteDesc);

      // FIXED: Add any pending ICE candidates after setting remote description
      for (final candidate in _pendingCandidates) {
        await _peerConnection!.addCandidate(candidate);
        _logger.d('➕ Added pending ICE candidate');
      }
      _pendingCandidates.clear();

      final answer = await _peerConnection!.createAnswer(_constraints);
      await _peerConnection!.setLocalDescription(answer);

      // Send answer via API
      await _apiService.postAnswer(data: {
        'room_id': _currentRoomId,
        'target_user_id': _remoteUserId,
        'answerer_id': _currentUserId,
        'answer': {
          'type': answer.type,
          'sdp': answer.sdp,
        },
      });

      _logger.d('✅ Answer created and sent successfully');
    } catch (e, stackTrace) {
      _logger.e('❌ Failed to create answer: $e');
      throw WebRTCException('Failed to create answer: $e');
    }
  }

  /// UPDATED: Unified WebRTC signaling handler based on type
  void _handleWebRTCSignaling(Map<String, dynamic> data) {
    try {
      _logger.d('🔔 Received WebRTC signaling: $data');

      // Extract signaling type and data
      final type = data['type'] as String?;
      final signalingData = data['data'] as Map<String, dynamic>?;
      final fromUser = data['from_user'] as Map<String, dynamic>?;
      final toUser = data['to_user'] as Map<String, dynamic>?;
      final roomId = data['room_id'] as String?;

      if (type == null || signalingData == null) {
        _logger.w('⚠️ Invalid signaling data: missing type or data');
        return;
      }

      // Verify this message is intended for the current user
      final targetUserId = toUser?['external_id'] ?? toUser?['id'];
      if (targetUserId != null && targetUserId != _currentUserId) {
        _logger.d(
            '📭 Signaling not for current user ($targetUserId != $_currentUserId)');
        return;
      }

      // Verify this is for the current room
      if (roomId != null && roomId != _currentRoomId) {
        _logger.d(
            '📭 Signaling not for current room ($roomId != $_currentRoomId)');
        return;
      }

      // Route based on signaling type
      switch (type.toLowerCase()) {
        case 'offer':
          _logger.d('📥 Processing WebRTC offer');
          _handleOffer(signalingData);
          break;

        case 'answer':
          _logger.d('📥 Processing WebRTC answer');
          _handleAnswer(signalingData);
          break;

        case 'ice_candidate':
        case 'ice-candidate':
        case 'candidate':
          _logger.d('📥 Processing ICE candidate');
          _handleIceCandidate(signalingData);
          break;

        default:
          _logger.w('⚠️ Unknown WebRTC signaling type: $type');
      }
    } catch (e, stackTrace) {
      _logger.e('❌ Failed to handle WebRTC signaling: $e');
      _logger.e('Stack trace: $stackTrace');
    }
  }

  /// UPDATED: Setup WebSocket listeners for unified signaling
  void _setupWebSocketListeners() {
    _logger
        .d('🔗 Setting up unified WebSocket listeners for WebRTC signaling...');

    // Listen for unified webrtc.signaling events
    _signalingSubscription = _webSocketService
        .on<Map<String, dynamic>>('webrtc.signaling')
        .listen((data) {
      _handleWebRTCSignaling(data);
    });

    _logger.d('✅ WebRTC signaling listener configured');
  }

  /// Handle incoming WebRTC offer
  void _handleOffer(Map<String, dynamic> data) async {
    try {
      _logger.d('📥 Processing offer data: $data');

      // Extract offer from the data structure
      Map<String, dynamic>? offer;

      // Handle different possible data structures
      if (data.containsKey('offer')) {
        offer = data['offer'] as Map<String, dynamic>?;
      } else if (data.containsKey('sdp') && data.containsKey('type')) {
        offer = data;
      }

      if (offer != null && _peerConnection != null) {
        await _createAnswer(offer);
      } else {
        _logger.w('⚠️ Invalid offer data structure');
      }
    } catch (e, stackTrace) {
      _logger.e('❌ Failed to handle offer: $e');
    }
  }

  /// FIXED: Handle incoming WebRTC answer with pending ICE candidates
  void _handleAnswer(Map<String, dynamic> data) async {
    try {
      _logger.d('📥 Processing answer data: $data');

      // Extract answer from the data structure
      Map<String, dynamic>? answer;

      // Handle different possible data structures
      if (data.containsKey('answer')) {
        answer = data['answer'] as Map<String, dynamic>?;
      } else if (data.containsKey('sdp') && data.containsKey('type')) {
        answer = data;
      }

      if (answer != null && _peerConnection != null) {
        final remoteDesc = RTCSessionDescription(answer['sdp'], answer['type']);
        await _peerConnection!.setRemoteDescription(remoteDesc);

        // FIXED: Add any pending ICE candidates after setting remote description
        for (final candidate in _pendingCandidates) {
          await _peerConnection!.addCandidate(candidate);
          _logger.d('➕ Added pending ICE candidate');
        }
        _pendingCandidates.clear();

        _logger.d('✅ Remote description set successfully');
      } else {
        _logger.w('⚠️ Invalid answer data structure');
      }
    } catch (e, stackTrace) {
      _logger.e('❌ Failed to handle answer: $e');
    }
  }

  /// FIXED: Handle incoming ICE candidate with proper queuing
  void _handleIceCandidate(Map<String, dynamic> data) async {
    try {
      _logger.d('📥 Processing ICE candidate data: $data');

      // Extract candidate from the data structure
      Map<String, dynamic>? candidate;

      // Handle different possible data structures
      if (data.containsKey('candidate')) {
        candidate = data['candidate'] as Map<String, dynamic>?;
      } else if (data.containsKey('sdpMid') &&
          data.containsKey('sdpMLineIndex')) {
        candidate = data;
      }

      if (candidate != null && _peerConnection != null) {
        final iceCandidate = RTCIceCandidate(
          candidate['candidate'],
          candidate['sdpMid'],
          candidate['sdpMLineIndex'],
        );

        // FIXED: Queue candidates if remote description isn't set yet
        if (_peerConnection!.getRemoteDescription() != null) {
          await _peerConnection!.addCandidate(iceCandidate);
          _logger.d('✅ ICE candidate added successfully');
        } else {
          _pendingCandidates.add(iceCandidate);
          _logger.d('📋 ICE candidate queued (waiting for remote description)');
        }
      } else {
        _logger.w('⚠️ Invalid ICE candidate data structure');
      }
    } catch (e, stackTrace) {
      _logger.e('❌ Failed to handle ICE candidate: $e');
    }
  }

  /// ICE candidate event handler
  void _onIceCandidate(RTCIceCandidate candidate) {
    _logger.d('🧊 ICE candidate generated: ${candidate.candidate}');

    // Send ICE candidate via API
    _apiService.postIceCandidate(data: {
      'room_id': _currentRoomId,
      'target_user_id': _remoteUserId,
      'sender_id': _currentUserId,
      'candidate': {
        'candidate': candidate.candidate,
        'sdpMid': candidate.sdpMid,
        'sdpMLineIndex': candidate.sdpMLineIndex,
      },
    }).catchError((e) {
      _logger.e('❌ Failed to send ICE candidate: $e');
    });
  }

  /// ICE connection state change handler
  void _onIceConnectionState(RTCIceConnectionState state) {
    _logger.d('🧊 ICE connection state: $state');

    switch (state) {
      case RTCIceConnectionState.RTCIceConnectionStateConnected:
        _updateConnectionState(WebRTCConnectionState.connected);
        break;
      case RTCIceConnectionState.RTCIceConnectionStateDisconnected:
        _updateConnectionState(WebRTCConnectionState.disconnected);
        break;
      case RTCIceConnectionState.RTCIceConnectionStateFailed:
        _updateConnectionState(WebRTCConnectionState.failed);
        break;
      case RTCIceConnectionState.RTCIceConnectionStateClosed:
        _updateConnectionState(WebRTCConnectionState.closed);
        break;
      case RTCIceConnectionState.RTCIceConnectionStateChecking:
        _updateConnectionState(WebRTCConnectionState.connecting);
        break;
      default:
        break;
    }
  }

  /// FIXED: Handle remote tracks (replaces onAddStream for Unified Plan)
  void _onTrack(RTCTrackEvent event) {
    _logger.d('📺 Remote track received: ${event.track.kind}');

    if (event.streams.isNotEmpty) {
      _remoteStream = event.streams[0];
      remoteRenderer.srcObject = _remoteStream;
      _remoteVideoController.add(remoteRenderer);
      notifyListeners();
      _logger.d('✅ Remote stream set to renderer');
    }
  }

  /// Remote stream removed handler
  void _onRemoveStream(MediaStream stream) {
    _logger.d('📺 Remote stream removed');

    _remoteStream = null;
    remoteRenderer.srcObject = null;
    notifyListeners();
  }

  /// Data channel handler
  void _onDataChannel(RTCDataChannel channel) {
    _logger.d('📡 Data channel created: ${channel.label}');
  }

  /// Renegotiation needed handler
  void _onRenegotiationNeeded() {
    _logger.d('🔄 Renegotiation needed');
  }

  /// Toggle audio mute
  Future<void> toggleAudio() async {
    if (_localStream == null) return;

    try {
      final audioTracks = _localStream!.getAudioTracks();
      if (audioTracks.isNotEmpty) {
        final enabled = !audioTracks[0].enabled;
        audioTracks[0].enabled = enabled;

        _updateMediaStates(_mediaStates.copyWith(
          audio: enabled ? MediaState.enabled : MediaState.disabled,
        ));

        _logger.d('🎤 Audio ${enabled ? 'enabled' : 'muted'}');
      }
    } catch (e) {
      _logger.e('❌ Failed to toggle audio: $e');
    }
  }

  /// Toggle video
  Future<void> toggleVideo() async {
    if (_localStream == null) return;

    try {
      final videoTracks = _localStream!.getVideoTracks();
      if (videoTracks.isNotEmpty) {
        final enabled = !videoTracks[0].enabled;
        videoTracks[0].enabled = enabled;

        _updateMediaStates(_mediaStates.copyWith(
          video: enabled ? MediaState.enabled : MediaState.disabled,
        ));

        _logger.d('📹 Video ${enabled ? 'enabled' : 'disabled'}');
      }
    } catch (e) {
      _logger.e('❌ Failed to toggle video: $e');
    }
  }

  /// Switch camera (front/back)
  Future<void> switchCamera() async {
    if (_localStream == null) return;

    try {
      final videoTracks = _localStream!.getVideoTracks();
      if (videoTracks.isNotEmpty) {
        await Helper.switchCamera(videoTracks[0]);
        _logger.d('📱 Camera switched');
      }
    } catch (e) {
      _logger.e('❌ Failed to switch camera: $e');
    }
  }

  /// Enable/disable speaker
  Future<void> toggleSpeaker() async {
    try {
      final enabled = _mediaStates.speaker == MediaState.disabled;
      await Helper.setSpeakerphoneOn(enabled);

      _updateMediaStates(_mediaStates.copyWith(
        speaker: enabled ? MediaState.enabled : MediaState.disabled,
      ));

      _logger.d('🔊 Speaker ${enabled ? 'enabled' : 'disabled'}');
    } catch (e) {
      _logger.e('❌ Failed to toggle speaker: $e');
    }
  }

  /// Set audio output to speaker
  Future<void> setSpeakerOn(bool enabled) async {
    try {
      await Helper.setSpeakerphoneOn(enabled);

      _updateMediaStates(_mediaStates.copyWith(
        speaker: enabled ? MediaState.enabled : MediaState.disabled,
      ));

      _logger.d('🔊 Speaker ${enabled ? 'enabled' : 'disabled'}');
    } catch (e) {
      _logger.e('❌ Failed to set speaker: $e');
    }
  }

  /// Mute/unmute audio
  Future<void> setAudioEnabled(bool enabled) async {
    if (_localStream == null) return;

    try {
      final audioTracks = _localStream!.getAudioTracks();
      if (audioTracks.isNotEmpty) {
        audioTracks[0].enabled = enabled;

        _updateMediaStates(_mediaStates.copyWith(
          audio: enabled ? MediaState.enabled : MediaState.disabled,
        ));

        _logger.d('🎤 Audio ${enabled ? 'enabled' : 'muted'}');
      }
    } catch (e) {
      _logger.e('❌ Failed to set audio: $e');
    }
  }

  /// Enable/disable video
  Future<void> setVideoEnabled(bool enabled) async {
    if (_localStream == null) return;

    try {
      final videoTracks = _localStream!.getVideoTracks();
      if (videoTracks.isNotEmpty) {
        videoTracks[0].enabled = enabled;

        _updateMediaStates(_mediaStates.copyWith(
          video: enabled ? MediaState.enabled : MediaState.disabled,
        ));

        _logger.d('📹 Video ${enabled ? 'enabled' : 'disabled'}');
      }
    } catch (e) {
      _logger.e('❌ Failed to set video: $e');
    }
  }

  /// Get current call statistics
  Future<List<StatsReport>?> getStats() async {
    if (_peerConnection == null) return null;

    try {
      final stats = await _peerConnection!.getStats();
      return stats;
    } catch (e) {
      _logger.e('❌ Failed to get stats: $e');
      return null;
    }
  }

  /// End call and cleanup
  Future<void> endCall() async {
    try {
      _logger.d('📞 Ending call...');
      await _cleanup();
      _logger.d('✅ Call ended successfully');
    } catch (e) {
      _logger.e('❌ Error ending call: $e');
    }
  }

  /// Update connection state
  void _updateConnectionState(WebRTCConnectionState newState) {
    if (_connectionState != newState) {
      _connectionState = newState;
      _connectionStateController.add(newState);
      notifyListeners();
      _logger.d('🔗 Connection state: $newState');
    }
  }

  /// Update media states
  void _updateMediaStates(MediaStates newStates) {
    _mediaStates = newStates;
    _mediaStatesController.add(newStates);
    notifyListeners();
  }

  /// Cleanup resources
  Future<void> _cleanup() async {
    try {
      // Close peer connection
      await _peerConnection?.close();
      _peerConnection = null;

      // Stop local stream
      if (_localStream != null) {
        _localStream!.getTracks().forEach((track) {
          track.stop();
        });
        await _localStream!.dispose();
        _localStream = null;
      }

      // Clear remote stream
      _remoteStream = null;

      // Clear renderers
      localRenderer.srcObject = null;
      remoteRenderer.srcObject = null;

      // Clear pending candidates
      _pendingCandidates.clear();

      // Reset state
      _currentRoomId = null;
      _currentUserId = null;
      _remoteUserId = null;
      _currentCallType = null;

      _updateConnectionState(WebRTCConnectionState.disconnected);
      _updateMediaStates(const MediaStates());
    } catch (e) {
      _logger.e('❌ Error during cleanup: $e');
    }
  }

  /// Dispose service
  @override
  void dispose() {
    _logger.d('🗑️ Disposing WebRTC service...');

    // Cancel subscriptions
    _signalingSubscription?.cancel();

    // Close controllers
    _localVideoController.close();
    _remoteVideoController.close();
    _connectionStateController.close();
    _mediaStatesController.close();

    // Cleanup WebRTC resources
    _cleanup();

    // Dispose renderers
    localRenderer.dispose();
    remoteRenderer.dispose();

    super.dispose();
  }
}
