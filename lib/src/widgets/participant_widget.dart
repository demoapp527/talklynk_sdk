import 'package:flutter/material.dart';
import 'package:talklynk_sdk/src/models/participant.dart';

class ParticipantWidget extends StatelessWidget {
  final Participant participant;
  final bool isLocal;
  final bool showControls;
  final VoidCallback? onMute;
  final VoidCallback? onKick;

  const ParticipantWidget({
    Key? key,
    required this.participant,
    this.isLocal = false,
    this.showControls = false,
    this.onMute,
    this.onKick,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isLocal ? Colors.blue : Colors.grey[300]!,
          width: isLocal ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Avatar and info
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundImage: participant.user?.avatarUrl != null
                    ? NetworkImage(participant.user!.avatarUrl!)
                    : null,
                backgroundColor: Colors.blue,
                child: participant.user?.avatarUrl == null
                    ? Text(
                        participant.displayName.isNotEmpty
                            ? participant.displayName[0].toUpperCase()
                            : '?',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      participant.displayName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                    Row(
                      children: [
                        if (participant.isAdmin)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.orange,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'ADMIN',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        if (isLocal) ...[
                          if (participant.isAdmin) const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.blue,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'YOU',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Controls
          if (showControls && !isLocal) ...[
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                IconButton(
                  icon: const Icon(Icons.mic_off),
                  onPressed: onMute,
                  tooltip: 'Mute',
                ),
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline),
                  onPressed: onKick,
                  tooltip: 'Remove',
                  color: Colors.red,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
