import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:talklynk_sdk/talklynk_sdk.dart';

class RoomScreen extends StatefulWidget {
  final Room room;

  const RoomScreen({Key? key, required this.room}) : super(key: key);

  @override
  State<RoomScreen> createState() => _RoomScreenState();
}

class _RoomScreenState extends State<RoomScreen> {
  StreamSubscription? _customEventSubscription;
  final List<CustomEvent> _customEvents = [];

  @override
  void initState() {
    super.initState();
    _setupCustomEventListeners();
  }

  @override
  void dispose() {
    _customEventSubscription?.cancel();
    super.dispose();
  }

  void _setupCustomEventListeners() {
    _customEventSubscription =
        context.read<EventProvider>().onAnyCustomEvent().listen((event) {
      if (event.roomId == widget.room.roomId) {
        setState(() {
          _customEvents.add(event);
        });

        // Show notification for certain events
        if (event.eventType == 'user_raised_hand') {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${event.sender.name} raised their hand'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.room.name),
        backgroundColor: Colors.blue[600],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: _sendHandRaiseEvent,
            icon: const Icon(Icons.back_hand),
            tooltip: 'Raise Hand',
          ),
          IconButton(
            onPressed: _leaveRoom,
            icon: const Icon(Icons.exit_to_app),
            tooltip: 'Leave Room',
          ),
        ],
      ),
      body: Consumer<RoomProvider>(
        builder: (context, roomProvider, child) {
          return Column(
            children: [
              // Room info
              _buildRoomInfo(),

              // Participants
              Expanded(
                child: _buildParticipantsList(
                    roomProvider.currentRoomParticipants),
              ),

              // Custom events feed
              if (_customEvents.isNotEmpty) _buildCustomEventsFeed(),
            ],
          );
        },
      ),
    );
  }

  Widget _buildRoomInfo() {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              widget.room.type == RoomType.video
                  ? Icons.videocam
                  : widget.room.type == RoomType.audio
                      ? Icons.mic
                      : Icons.chat,
              color: Colors.blue,
              size: 32,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.room.name,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '${widget.room.type.name.toUpperCase()} Room',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.green,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'ACTIVE',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildParticipantsList(List<Participant> participants) {
    if (participants.isEmpty) {
      return const Center(
        child: Text('No participants in this room'),
      );
    }

    final currentUser = context.read<AuthProvider>().currentUser;

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: participants.length,
      itemBuilder: (context, index) {
        final participant = participants[index];
        final isCurrentUser = participant.userId == currentUser?.id;

        return ParticipantWidget(
          participant: participant,
          isLocal: isCurrentUser,
          showControls: !isCurrentUser,
        );
      },
    );
  }

  Widget _buildCustomEventsFeed() {
    return Container(
      height: 100,
      margin: const EdgeInsets.all(16),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Activity',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 4),
              Expanded(
                child: ListView.builder(
                  reverse: true,
                  itemCount: _customEvents.length,
                  itemBuilder: (context, index) {
                    final event = _customEvents[index];
                    return Text(
                      '${event.sender.name}: ${event.eventType.replaceAll('_', ' ')}',
                      style: const TextStyle(fontSize: 12),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _sendHandRaiseEvent() async {
    final currentUser = context.read<AuthProvider>().currentUser;
    if (currentUser == null) return;

    try {
      await TalkLynkSDK.instance.api.sendCustomEvent(
        roomId: widget.room.roomId,
        eventType: 'user_raised_hand',
        senderId: currentUser.externalId ?? currentUser.id,
        broadcastToAll: true,
        data: {
          'timestamp': DateTime.now().toIso8601String(),
          'urgent': false,
        },
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to raise hand: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _leaveRoom() async {
    final currentUser = context.read<AuthProvider>().currentUser;
    if (currentUser == null) return;

    final success = await context.read<RoomProvider>().leaveRoom(
          username: currentUser.name,
          externalId: currentUser.externalId,
        );

    if (success && mounted) {
      Navigator.pop(context);
    }
  }
}
