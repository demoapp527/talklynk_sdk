import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:talklynk_sdk/talklynk_sdk.dart';

class CallScreen extends StatefulWidget {
  final Call call;
  final VoidCallback? onCallEnded;

  const CallScreen({
    Key? key,
    required this.call,
    this.onCallEnded,
  }) : super(key: key);

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  WebRTCService? _webrtcService;
  bool _isMuted = false;
  bool _isVideoEnabled = true;
  bool _isSpeakerOn = false;
  bool _isConnecting = true;
  bool _showControls = true;
  bool _isInitializing = true;
  bool _checkingPermissions = true;
  String? _initializationError;
  DateTime? _callStartTime;

  // Permission states
  bool _hasCameraPermission = false;
  bool _hasMicrophonePermission = false;
  bool _permissionsRequested = false;

  @override
  void initState() {
    super.initState();
    _callStartTime = DateTime.now();
    _checkAndRequestPermissions();

    // Auto hide controls after 5 seconds
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted && _showControls) {
        setState(() {
          _showControls = false;
        });
      }
    });
  }

  Future<void> _checkAndRequestPermissions() async {
    try {
      setState(() {
        _checkingPermissions = true;
        _initializationError = null;
      });

      print('🔐 Checking permissions...');

      // Check current permission status
      final cameraStatus = await Permission.camera.status;
      final microphoneStatus = await Permission.microphone.status;

      print('🔐 Camera permission: $cameraStatus');
      print('🔐 Microphone permission: $microphoneStatus');

      _hasCameraPermission = cameraStatus.isGranted;
      _hasMicrophonePermission = microphoneStatus.isGranted;

      // Request permissions if not granted
      if (!_hasCameraPermission || !_hasMicrophonePermission) {
        await _requestPermissions();
      }

      setState(() {
        _checkingPermissions = false;
        _permissionsRequested = true;
      });

      // Proceed with WebRTC initialization if we have required permissions
      if (_hasRequiredPermissions()) {
        await _initializeWebRTC();
      } else {
        setState(() {
          _initializationError =
              'Camera and microphone permissions are required for calls';
        });
      }
    } catch (e) {
      print('❌ Error checking permissions: $e');
      setState(() {
        _checkingPermissions = false;
        _initializationError = 'Failed to check permissions: $e';
      });
    }
  }

  Future<void> _requestPermissions() async {
    try {
      print('🔐 Requesting permissions...');

      Map<Permission, PermissionStatus> statuses;

      // For video calls, request both camera and microphone
      if (widget.call.type == CallType.video) {
        statuses = await [
          Permission.camera,
          Permission.microphone,
        ].request();
      } else {
        // For audio calls, only request microphone
        statuses = await [
          Permission.microphone,
        ].request();
      }

      print('🔐 Permission results: $statuses');

      _hasCameraPermission = statuses[Permission.camera]?.isGranted ?? false;
      _hasMicrophonePermission =
          statuses[Permission.microphone]?.isGranted ?? false;

      // Show permission dialog if any permission was denied
      if (!_hasRequiredPermissions()) {
        _showPermissionDialog();
      }
    } catch (e) {
      print('❌ Error requesting permissions: $e');
      setState(() {
        _initializationError = 'Failed to request permissions: $e';
      });
    }
  }

  bool _hasRequiredPermissions() {
    if (widget.call.type == CallType.video) {
      return _hasCameraPermission && _hasMicrophonePermission;
    } else {
      return _hasMicrophonePermission;
    }
  }

  void _showPermissionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Permissions Required'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.call.type == CallType.video
                  ? 'This video call requires camera and microphone access.'
                  : 'This audio call requires microphone access.',
            ),
            const SizedBox(height: 16),
            if (!_hasMicrophonePermission)
              const Row(
                children: [
                  Icon(Icons.mic, color: Colors.red, size: 20),
                  SizedBox(width: 8),
                  Text('Microphone access denied'),
                ],
              ),
            if (widget.call.type == CallType.video && !_hasCameraPermission)
              const Row(
                children: [
                  Icon(Icons.videocam, color: Colors.red, size: 20),
                  SizedBox(width: 8),
                  Text('Camera access denied'),
                ],
              ),
            const SizedBox(height: 16),
            const Text(
              'Please grant permissions in Settings to continue with the call.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context); // Exit call screen
            },
            child: const Text('Cancel Call'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              openAppSettings();
            },
            child: const Text('Open Settings'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _checkAndRequestPermissions();
            },
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Future<void> _initializeWebRTC() async {
    try {
      setState(() {
        _isInitializing = true;
        _initializationError = null;
      });

      print('🎥 Initializing WebRTC with permissions...');
      print(
          '🎥 Camera: $_hasCameraPermission, Microphone: $_hasMicrophonePermission');

      // Try to get WebRTC service from provider first
      try {
        _webrtcService = context.read<WebRTCService>();
        print('🎥 Using WebRTC service from provider');
      } catch (e) {
        print('🎥 Provider not found, creating new WebRTC service');
        // Fallback: Create our own WebRTC service instance
        _webrtcService = WebRTCService(
          apiService: TalkLynkSDK.instance.api,
          webSocketService: TalkLynkSDK.instance.websocket,
          baseUrl: TalkLynkSDK.instance.api.baseUrl,
          enableLogs: true,
        );
      }

      // Initialize WebRTC service if not already initialized
      if (!_webrtcService!.isInitialized) {
        await _webrtcService!.initialize();
      }

      final currentUser = context.read<AuthProvider>().currentUser;
      if (currentUser == null) {
        throw Exception('No current user found');
      }

      final isOutgoingCall = widget.call.caller.id == currentUser.id;
      final remoteUserId = isOutgoingCall
          ? (widget.call.callee.externalId ?? widget.call.callee.id)
          : (widget.call.caller.externalId ?? widget.call.caller.id);
      final currentUserId = currentUser.externalId ?? currentUser.id;

      print('🎥 Starting WebRTC call - Room: ${widget.call.callId}');
      print('🎥 Current User: $currentUserId, Remote User: $remoteUserId');
      print('🎥 Is Outgoing: $isOutgoingCall, Call Type: ${widget.call.type}');

      if (isOutgoingCall) {
        // Caller - start the call
        await _webrtcService!.startCall(
          roomId: widget.call.callId,
          userId: currentUserId,
          remoteUserId: remoteUserId,
          callType: widget.call.type,
        );
      } else {
        // Callee - answer the call
        await _webrtcService!.answerCall(
          roomId: widget.call.callId,
          userId: currentUserId,
          remoteUserId: remoteUserId,
          callType: widget.call.type,
        );
      }

      // Listen for connection state changes
      _webrtcService!.connectionStateStream.listen((state) {
        if (mounted) {
          setState(() {
            _isConnecting = state != WebRTCConnectionState.connected;
          });
          print('🎥 Connection state changed: $state');
        }
      });

      // Listen for media state changes
      _webrtcService!.mediaStatesStream.listen((mediaStates) {
        if (mounted) {
          setState(() {
            _isMuted = mediaStates.audio == MediaState.disabled;
            _isVideoEnabled = mediaStates.video == MediaState.enabled;
            _isSpeakerOn = mediaStates.speaker == MediaState.enabled;
          });
          print(
              '🎥 Media states changed: Audio: ${mediaStates.audio}, Video: ${mediaStates.video}');
        }
      });

      setState(() {
        _isInitializing = false;
        _isConnecting = true; // Still connecting until WebRTC connects
      });

      print('✅ WebRTC initialization completed');
    } catch (e, stackTrace) {
      print('❌ Error initializing WebRTC: $e');
      print('Stack trace: $stackTrace');

      if (mounted) {
        setState(() {
          _isInitializing = false;
          _initializationError = e.toString();
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to initialize call: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    print('🎥 Disposing CallScreen...');
    _webrtcService?.endCall();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Show permission check screen
    if (_checkingPermissions) {
      return _buildPermissionCheckingScreen();
    }

    // Show loading screen while initializing
    if (_isInitializing) {
      return _buildInitializingScreen();
    }

    // Show error screen if initialization failed
    if (_initializationError != null) {
      return _buildErrorScreen();
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: () {
          setState(() {
            _showControls = !_showControls;
          });

          // Auto hide controls after 5 seconds
          if (_showControls) {
            Future.delayed(const Duration(seconds: 5), () {
              if (mounted && _showControls) {
                setState(() {
                  _showControls = false;
                });
              }
            });
          }
        },
        child: Consumer<CallProvider>(
          builder: (context, callProvider, child) {
            final currentCall = callProvider.currentCall ?? widget.call;

            return SafeArea(
              child: Stack(
                children: [
                  // Main video area
                  _buildVideoArea(currentCall),

                  // Overlay UI
                  if (_showControls || _isConnecting) ...[
                    // Top overlay with call info
                    _buildTopOverlay(currentCall),

                    // Bottom overlay with controls
                    _buildBottomOverlay(currentCall),
                  ],

                  // Connection indicator
                  if (_isConnecting) _buildConnectionIndicator(),

                  // Permission warning overlay
                  if (!_hasRequiredPermissions() && _permissionsRequested)
                    _buildPermissionWarningOverlay(),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildPermissionCheckingScreen() {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(color: Colors.white),
              const SizedBox(height: 20),
              const Text(
                'Checking permissions...',
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
              const SizedBox(height: 10),
              Text(
                widget.call.type == CallType.video
                    ? 'Requesting camera and microphone access'
                    : 'Requesting microphone access',
                style: const TextStyle(color: Colors.white70, fontSize: 14),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInitializingScreen() {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(color: Colors.white),
              const SizedBox(height: 20),
              const Text(
                'Initializing call...',
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
              const SizedBox(height: 10),
              Text(
                'Setting up ${widget.call.type.name} call',
                style: const TextStyle(color: Colors.white70, fontSize: 14),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorScreen() {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.error_outline,
                  color: Colors.red,
                  size: 64,
                ),
                const SizedBox(height: 20),
                const Text(
                  'Call Failed',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  _initializationError!,
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 30),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton(
                      onPressed: _checkAndRequestPermissions,
                      child: const Text('Retry'),
                    ),
                    if (!_hasRequiredPermissions())
                      ElevatedButton(
                        onPressed: openAppSettings,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                        ),
                        child: const Text('Settings'),
                      ),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                      ),
                      child: const Text('Close'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPermissionWarningOverlay() {
    return Positioned(
      top: 100,
      left: 16,
      right: 16,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.orange.withOpacity(0.9),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Row(
              children: [
                const Icon(Icons.warning, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    !_hasRequiredPermissions()
                        ? 'Permissions required for call'
                        : 'Limited functionality',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                TextButton(
                  onPressed: openAppSettings,
                  child: const Text(
                    'Settings',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
                TextButton(
                  onPressed: _checkAndRequestPermissions,
                  child: const Text(
                    'Retry',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoArea(Call call) {
    if (call.type == CallType.video &&
        _webrtcService != null &&
        _hasCameraPermission) {
      return Stack(
        children: [
          // Remote video (full screen)
          Positioned.fill(
            child: Container(
              color: Colors.black,
              child: _webrtcService!.remoteStream != null
                  ? RTCVideoView(_webrtcService!.remoteRenderer)
                  : _buildParticipantAvatar(
                      call.caller.id ==
                              context.read<AuthProvider>().currentUser?.id
                          ? call.callee
                          : call.caller,
                      isLarge: true,
                    ),
            ),
          ),

          // Local video (picture-in-picture)
          Positioned(
            top: 60,
            right: 20,
            child: Container(
              width: 120,
              height: 160,
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white24, width: 2),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: _webrtcService!.localStream != null &&
                        _isVideoEnabled &&
                        _hasCameraPermission
                    ? RTCVideoView(_webrtcService!.localRenderer, mirror: true)
                    : _buildParticipantAvatar(
                        context.read<AuthProvider>().currentUser!,
                        isLarge: false,
                      ),
              ),
            ),
          ),
        ],
      );
    } else {
      // Audio call or no camera permission - show avatar only
      return Container(
        width: double.infinity,
        color: Colors.black,
        child: Center(
          child: _buildParticipantAvatar(
            call.caller.id == context.read<AuthProvider>().currentUser?.id
                ? call.callee
                : call.caller,
            isLarge: true,
          ),
        ),
      );
    }
  }

  Widget _buildTopOverlay(Call call) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black.withOpacity(0.7),
              Colors.transparent,
            ],
          ),
        ),
        child: Column(
          children: [
            Text(
              _getCallTitle(call),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _getCallStatus(call),
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
              ),
            ),
            if (!_isConnecting && _callStartTime != null)
              Text(
                _formatCallDuration(),
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomOverlay(Call call) {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [
              Colors.black.withOpacity(0.8),
              Colors.transparent,
            ],
          ),
        ),
        child: _buildCallControls(call),
      ),
    );
  }

  Widget _buildConnectionIndicator() {
    return Positioned(
      top: 120,
      left: 20,
      right: 20,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.orange.withOpacity(0.9),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
            SizedBox(width: 8),
            Text(
              'Connecting...',
              style: TextStyle(color: Colors.white, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildParticipantAvatar(dynamic user, {required bool isLarge}) {
    final size = isLarge ? 120.0 : 60.0;
    final name = user is Call ? user.caller.name : user.name;
    final avatarUrl = user is Call ? user.caller.avatarUrl : user.avatarUrl;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        CircleAvatar(
          radius: size / 2,
          backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
          backgroundColor: Colors.blue,
          child: avatarUrl == null
              ? Text(
                  name.isNotEmpty ? name[0].toUpperCase() : '?',
                  style: TextStyle(
                    fontSize: size / 3,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                )
              : null,
        ),
        if (isLarge) ...[
          const SizedBox(height: 16),
          Text(
            name,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildCallControls(Call call) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        // Mute button
        _buildControlButton(
          icon: _isMuted ? Icons.mic_off : Icons.mic,
          onPressed: (_webrtcService != null && _hasMicrophonePermission)
              ? () async {
                  try {
                    await _webrtcService!.toggleAudio();
                  } catch (e) {
                    print('Error toggling audio: $e');
                  }
                }
              : null,
          backgroundColor: _isMuted
              ? Colors.red
              : (_hasMicrophonePermission ? Colors.white24 : Colors.grey),
          tooltip: _isMuted ? 'Unmute' : 'Mute',
        ),

        // Video toggle (only for video calls)
        if (call.type == CallType.video)
          _buildControlButton(
            icon: _isVideoEnabled ? Icons.videocam : Icons.videocam_off,
            onPressed: (_webrtcService != null && _hasCameraPermission)
                ? () async {
                    try {
                      await _webrtcService!.toggleVideo();
                    } catch (e) {
                      print('Error toggling video: $e');
                    }
                  }
                : null,
            backgroundColor: !_isVideoEnabled
                ? Colors.red
                : (_hasCameraPermission ? Colors.white24 : Colors.grey),
            tooltip: _isVideoEnabled ? 'Turn off camera' : 'Turn on camera',
          ),

        // Speaker toggle
        _buildControlButton(
          icon: _isSpeakerOn ? Icons.volume_up : Icons.volume_down,
          onPressed: _webrtcService != null
              ? () async {
                  try {
                    await _webrtcService!.toggleSpeaker();
                  } catch (e) {
                    print('Error toggling speaker: $e');
                  }
                }
              : null,
          backgroundColor: _isSpeakerOn ? Colors.blue : Colors.white24,
          tooltip: _isSpeakerOn ? 'Speaker off' : 'Speaker on',
        ),

        // Camera switch (only for video calls with camera permission)
        if (call.type == CallType.video && _hasCameraPermission)
          _buildControlButton(
            icon: Icons.flip_camera_ios,
            onPressed: _webrtcService != null
                ? () async {
                    try {
                      await _webrtcService!.switchCamera();
                    } catch (e) {
                      print('Error switching camera: $e');
                    }
                  }
                : null,
            backgroundColor: Colors.white24,
            tooltip: 'Switch camera',
          ),

        // End call button
        _buildControlButton(
          icon: Icons.call_end,
          onPressed: () async {
            await _endCall();
          },
          backgroundColor: Colors.red,
          isLarge: true,
          tooltip: 'End call',
        ),
      ],
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required VoidCallback? onPressed,
    required Color backgroundColor,
    bool isLarge = false,
    String? tooltip,
  }) {
    final size = isLarge ? 60.0 : 50.0;
    final isDisabled = onPressed == null;

    Widget button = GestureDetector(
      onTap: onPressed,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: backgroundColor,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: backgroundColor.withOpacity(0.3),
              blurRadius: 8,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Icon(
          icon,
          color: Colors.white,
          size: isLarge ? 30 : 24,
        ),
      ),
    );

    if (tooltip != null) {
      return Tooltip(
        message: tooltip,
        child: button,
      );
    }

    return button;
  }

  Future<void> _endCall() async {
    try {
      final currentUser = context.read<AuthProvider>().currentUser;
      if (currentUser != null) {
        await context.read<CallProvider>().endCall(
              userId: currentUser.externalId ?? currentUser.id,
              reason: 'manual',
            );
      }

      // End WebRTC call
      if (_webrtcService != null) {
        await _webrtcService!.endCall();
      }

      widget.onCallEnded?.call();

      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      print('Error ending call: $e');
      if (mounted) {
        Navigator.pop(context);
      }
    }
  }

  String _getCallTitle(Call call) {
    final currentUser = context.read<AuthProvider>().currentUser;
    if (currentUser?.id == call.caller.id) {
      return call.callee.name;
    } else {
      return call.caller.name;
    }
  }

  String _getCallStatus(Call call) {
    if (_checkingPermissions) {
      return 'Checking permissions...';
    }

    if (_isInitializing) {
      return 'Initializing...';
    }

    if (_isConnecting) {
      return 'Connecting...';
    }

    if (!_hasRequiredPermissions()) {
      return 'Permissions required';
    }

    switch (call.status) {
      case CallStatus.ringing:
        return 'Ringing...';
      case CallStatus.active:
        return 'Connected';
      case CallStatus.ended:
        return 'Call ended';
      case CallStatus.rejected:
        return 'Call rejected';
      case CallStatus.missed:
        return 'Missed call';
    }
  }

  String _formatCallDuration() {
    if (_callStartTime == null) return '';

    final duration = DateTime.now().difference(_callStartTime!);
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}
