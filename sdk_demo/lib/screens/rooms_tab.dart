import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sdk_demo/screens/room_screen.dart';
import 'package:talklynk_sdk/talklynk_sdk.dart';

class RoomsTab extends StatelessWidget {
  const RoomsTab({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Create room button
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          child: ElevatedButton.icon(
            onPressed: () => _showCreateRoomDialog(context),
            icon: const Icon(Icons.add),
            label: const Text('Create New Room'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue[600],
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),

        // Rooms list
        Expanded(
          child: RoomListWidget(
            onRoomJoin: (room) => _joinRoom(context, room),
          ),
        ),
      ],
    );
  }

  void _showCreateRoomDialog(BuildContext context) {
    final nameController = TextEditingController();
    RoomType selectedType = RoomType.video;
    int maxParticipants = 10;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Create New Room'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Room Name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<RoomType>(
                value: selectedType,
                decoration: const InputDecoration(
                  labelText: 'Room Type',
                  border: OutlineInputBorder(),
                ),
                items: RoomType.values.map((type) {
                  return DropdownMenuItem(
                    value: type,
                    child: Text(type.name.toUpperCase()),
                  );
                }).toList(),
                onChanged: (type) {
                  if (type != null) {
                    setState(() => selectedType = type);
                  }
                },
              ),
              const SizedBox(height: 16),
              TextField(
                decoration: const InputDecoration(
                  labelText: 'Max Participants',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                onChanged: (value) {
                  maxParticipants = int.tryParse(value) ?? 10;
                },
                controller:
                    TextEditingController(text: maxParticipants.toString()),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => _createRoom(
                context,
                nameController.text,
                selectedType,
                maxParticipants,
              ),
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _createRoom(
    BuildContext context,
    String name,
    RoomType type,
    int maxParticipants,
  ) async {
    if (name.trim().isEmpty) return;

    Navigator.pop(context); // Close dialog

    final room = await context.read<RoomProvider>().createRoom(
          name: name.trim(),
          type: type,
          maxParticipants: maxParticipants,
        );

    if (room != null && context.mounted) {
      _joinRoom(context, room);
    }
  }

  Future<void> _joinRoom(BuildContext context, Room room) async {
    final currentUser = context.read<AuthProvider>().currentUser;
    if (currentUser == null) return;

    final success = await context.read<RoomProvider>().joinRoom(
          roomId: room.roomId,
          username: currentUser.name,
          externalId: currentUser.externalId,
          displayName:
              currentUser.metadata?['display_name'] ?? currentUser.name,
        );

    if (success && context.mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => RoomScreen(room: room),
        ),
      );
    }
  }
}
