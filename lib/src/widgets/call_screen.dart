import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:talklynk_sdk/src/models/call.dart';
import 'package:talklynk_sdk/src/providers/auth_provider.dart';
import 'package:talklynk_sdk/src/providers/call_provider.dart';

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
  bool _isMuted = false;
  bool _isVideoEnabled = true;
  bool _isSpeakerOn = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Consumer<CallProvider>(
        builder: (context, callProvider, child) {
          final currentCall = callProvider.currentCall ?? widget.call;

          return SafeArea(
            child: Column(
              children: [
                // Call Header
                _buildCallHeader(currentCall),

                // Video/Avatar Area
                Expanded(
                  child: _buildVideoArea(currentCall),
                ),

                // Call Controls
                _buildCallControls(currentCall),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildCallHeader(Call call) {
    return Container(
      padding: const EdgeInsets.all(20),
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
          if (call.isActive && call.duration != null)
            Text(
              _formatDuration(call.duration!),
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildVideoArea(Call call) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(16),
      ),
      child: Stack(
        children: [
          // Remote video/avatar
          Center(
            child: _buildParticipantAvatar(
              call.caller.id == context.read<AuthProvider>().currentUser?.id
                  ? call.callee
                  : call.caller,
              isLarge: true,
            ),
          ),

          // Local video preview (bottom right)
          if (call.type == CallType.video)
            Positioned(
              bottom: 16,
              right: 16,
              child: Container(
                width: 120,
                height: 160,
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white24),
                ),
                child: _buildParticipantAvatar(
                  context.read<AuthProvider>().currentUser!,
                  isLarge: false,
                ),
              ),
            ),
        ],
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
    return Container(
      padding: const EdgeInsets.all(20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Mute button
          _buildControlButton(
            icon: _isMuted ? Icons.mic_off : Icons.mic,
            onPressed: () {
              setState(() {
                _isMuted = !_isMuted;
              });
            },
            backgroundColor: _isMuted ? Colors.red : Colors.white24,
          ),

          // Video toggle (only for video calls)
          if (call.type == CallType.video)
            _buildControlButton(
              icon: _isVideoEnabled ? Icons.videocam : Icons.videocam_off,
              onPressed: () {
                setState(() {
                  _isVideoEnabled = !_isVideoEnabled;
                });
              },
              backgroundColor: !_isVideoEnabled ? Colors.red : Colors.white24,
            ),

          // Speaker toggle
          _buildControlButton(
            icon: _isSpeakerOn ? Icons.volume_up : Icons.volume_down,
            onPressed: () {
              setState(() {
                _isSpeakerOn = !_isSpeakerOn;
              });
            },
            backgroundColor: _isSpeakerOn ? Colors.blue : Colors.white24,
          ),

          // End call button
          _buildControlButton(
            icon: Icons.call_end,
            onPressed: () {
              context.read<CallProvider>().endCall();
              widget.onCallEnded?.call();
              Navigator.pop(context);
            },
            backgroundColor: Colors.red,
            isLarge: true,
          ),
        ],
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required VoidCallback onPressed,
    required Color backgroundColor,
    bool isLarge = false,
  }) {
    final size = isLarge ? 60.0 : 50.0;

    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: backgroundColor,
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          color: Colors.white,
          size: isLarge ? 30 : 24,
        ),
      ),
    );
  }

  String _getCallTitle(Call call) {
    final currentUser = context.read<AuthProvider>().currentUser;
    if (currentUser?.id == call.caller.id) {
      return 'Calling ${call.callee.name}';
    } else {
      return 'Call with ${call.caller.name}';
    }
  }

  String _getCallStatus(Call call) {
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

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}
