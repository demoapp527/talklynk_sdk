import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:talklynk_sdk/src/models/call.dart';
import 'package:talklynk_sdk/src/providers/auth_provider.dart';
import 'package:talklynk_sdk/src/providers/call_provider.dart';

class IncomingCallOverlay extends StatelessWidget {
  final Call call;
  final VoidCallback? onCallAccepted;
  final VoidCallback? onCallRejected;

  const IncomingCallOverlay({
    Key? key,
    required this.call,
    this.onCallAccepted,
    this.onCallRejected,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withOpacity(0.9),
      child: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Caller info
            _buildCallerInfo(),

            const SizedBox(height: 40),

            // Call type indicator
            _buildCallTypeIndicator(),

            const SizedBox(height: 60),

            // Action buttons
            _buildActionButtons(context),
          ],
        ),
      ),
    );
  }

  Widget _buildCallerInfo() {
    return Column(
      children: [
        // Avatar
        CircleAvatar(
          radius: 80,
          backgroundImage: call.caller.avatarUrl != null
              ? NetworkImage(call.caller.avatarUrl!)
              : null,
          backgroundColor: Colors.blue,
          child: call.caller.avatarUrl == null
              ? Text(
                  call.caller.name.isNotEmpty
                      ? call.caller.name[0].toUpperCase()
                      : '?',
                  style: const TextStyle(
                    fontSize: 40,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                )
              : null,
        ),

        const SizedBox(height: 20),

        // Caller name
        Text(
          call.caller.name,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.w600,
          ),
        ),

        const SizedBox(height: 8),

        // "Incoming call" text
        const Text(
          'Incoming call',
          style: TextStyle(
            color: Colors.white70,
            fontSize: 16,
          ),
        ),
      ],
    );
  }

  Widget _buildCallTypeIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white24,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            call.type == CallType.video ? Icons.videocam : Icons.phone,
            color: Colors.white,
            size: 20,
          ),
          const SizedBox(width: 8),
          Text(
            call.type == CallType.video ? 'Video Call' : 'Audio Call',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        // Reject button
        _buildActionButton(
          icon: Icons.call_end,
          backgroundColor: Colors.red,
          onPressed: () => _rejectCall(context),
        ),

        // Accept button
        _buildActionButton(
          icon: Icons.call,
          backgroundColor: Colors.green,
          onPressed: () => _acceptCall(context),
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required Color backgroundColor,
    required VoidCallback onPressed,
  }) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          color: backgroundColor,
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          color: Colors.white,
          size: 40,
        ),
      ),
    );
  }

  void _acceptCall(BuildContext context) {
    final currentUser = context.read<AuthProvider>().currentUser;
    if (currentUser != null) {
      context
          .read<CallProvider>()
          .acceptCall(currentUser.externalId ?? currentUser.id);
      onCallAccepted?.call();
    }
  }

  void _rejectCall(BuildContext context) {
    final currentUser = context.read<AuthProvider>().currentUser;
    if (currentUser != null) {
      context
          .read<CallProvider>()
          .rejectCall(currentUser.externalId ?? currentUser.id);
      onCallRejected?.call();
    }
  }
}
