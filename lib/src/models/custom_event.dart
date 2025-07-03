import 'package:talklynk_sdk/talklynk_sdk.dart';

class CustomEvent {
  final String eventType;
  final String roomId;
  final User sender;
  final List<String> targetIds;
  final bool broadcastToAll;
  final Map<String, dynamic> data;
  final DateTime timestamp;

  const CustomEvent({
    required this.eventType,
    required this.roomId,
    required this.sender,
    this.targetIds = const [],
    this.broadcastToAll = false,
    this.data = const {},
    required this.timestamp,
  });

  factory CustomEvent.fromJson(Map<String, dynamic> json) {
    return CustomEvent(
      eventType: json['event_type'] ?? '',
      roomId: json['room_id'] ?? '',
      sender: User.fromJson(json['sender'] ?? {}),
      targetIds: List<String>.from(json['target_ids'] ?? []),
      broadcastToAll: json['broadcast_to_all'] ?? false,
      data: json['data'] ?? {},
      timestamp:
          DateTime.parse(json['timestamp'] ?? DateTime.now().toIso8601String()),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'event_type': eventType,
      'room_id': roomId,
      'sender': sender.toJson(),
      'target_ids': targetIds,
      'broadcast_to_all': broadcastToAll,
      'data': data,
      'timestamp': timestamp.toIso8601String(),
    };
  }
}
