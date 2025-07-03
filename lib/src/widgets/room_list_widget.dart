import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:talklynk_sdk/src/models/room.dart';
import 'package:talklynk_sdk/src/providers/room_provider.dart';

class RoomListWidget extends StatefulWidget {
  final Function(Room)? onRoomTap;
  final Function(Room)? onRoomJoin;

  const RoomListWidget({
    Key? key,
    this.onRoomTap,
    this.onRoomJoin,
  }) : super(key: key);

  @override
  State<RoomListWidget> createState() => _RoomListWidgetState();
}

class _RoomListWidgetState extends State<RoomListWidget> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<RoomProvider>().loadRooms();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<RoomProvider>(
      builder: (context, roomProvider, child) {
        if (roomProvider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (roomProvider.error != null) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  roomProvider.error!,
                  style: const TextStyle(color: Colors.red),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => roomProvider.loadRooms(),
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }

        if (roomProvider.rooms.isEmpty) {
          return const Center(
            child: Text(
              'No rooms available.\nCreate a new room to get started!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () => roomProvider.loadRooms(),
          child: ListView.builder(
            itemCount: roomProvider.rooms.length,
            itemBuilder: (context, index) {
              final room = roomProvider.rooms[index];
              return _buildRoomCard(room);
            },
          ),
        );
      },
    );
  }

  Widget _buildRoomCard(Room room) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: CircleAvatar(
          backgroundColor: _getRoomTypeColor(room.type),
          child: Icon(
            _getRoomTypeIcon(room.type),
            color: Colors.white,
          ),
        ),
        title: Text(
          room.name,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  Icons.people,
                  size: 16,
                  color: Colors.grey[600],
                ),
                const SizedBox(width: 4),
                Text(
                  '${room.participantCount}/${room.maxParticipants}',
                  style: TextStyle(color: Colors.grey[600]),
                ),
                const SizedBox(width: 16),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: room.isActive ? Colors.green : Colors.grey,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    room.status.name.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            if (room.isOneToOne) ...[
              const SizedBox(height: 4),
              const Text(
                'One-to-One Call',
                style: TextStyle(
                  color: Colors.blue,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ],
        ),
        trailing: room.isFull
            ? const Icon(Icons.lock, color: Colors.grey)
            : const Icon(Icons.arrow_forward_ios),
        onTap: () {
          if (widget.onRoomTap != null) {
            widget.onRoomTap!(room);
          } else if (!room.isFull) {
            widget.onRoomJoin?.call(room);
          }
        },
      ),
    );
  }

  Color _getRoomTypeColor(RoomType type) {
    switch (type) {
      case RoomType.video:
        return Colors.blue;
      case RoomType.audio:
        return Colors.green;
      case RoomType.chat:
        return Colors.orange;
    }
  }

  IconData _getRoomTypeIcon(RoomType type) {
    switch (type) {
      case RoomType.video:
        return Icons.videocam;
      case RoomType.audio:
        return Icons.mic;
      case RoomType.chat:
        return Icons.chat;
    }
  }
}
