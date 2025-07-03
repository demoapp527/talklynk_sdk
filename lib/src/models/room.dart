import 'package:talklynk_sdk/talklynk_sdk.dart';

enum RoomType { audio, video, chat }

enum RoomStatus { active, ended, ringing }

class Room {
  final String id;
  final String roomId;
  final String name;
  final RoomType type;
  final RoomStatus status;
  final int maxParticipants;
  final bool isOneToOne;
  final List<Participant> participants;
  final DateTime createdAt;
  final DateTime? startedAt;
  final DateTime? endedAt;
  final Map<String, dynamic>? metadata;

  const Room({
    required this.id,
    required this.roomId,
    required this.name,
    required this.type,
    required this.status,
    required this.maxParticipants,
    this.isOneToOne = false,
    this.participants = const [],
    required this.createdAt,
    this.startedAt,
    this.endedAt,
    this.metadata,
  });

  factory Room.fromJson(Map<String, dynamic> json) {
    return Room(
      id: json['id']?.toString() ?? '',
      roomId: json['room_id'] ?? '',
      name: json['name'] ?? '',
      type: RoomType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => RoomType.video,
      ),
      status: RoomStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => RoomStatus.active,
      ),
      maxParticipants: json['max_participants'] ?? 10,
      isOneToOne: json['is_one_to_one'] ?? false,
      participants: (json['participants'] as List?)
              ?.map((p) => Participant.fromJson(p))
              .toList() ??
          [],
      createdAt: DateTime.parse(
          json['created_at'] ?? DateTime.now().toIso8601String()),
      startedAt: json['started_at'] != null
          ? DateTime.parse(json['started_at'])
          : null,
      endedAt:
          json['ended_at'] != null ? DateTime.parse(json['ended_at']) : null,
      metadata: json['metadata'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'room_id': roomId,
      'name': name,
      'type': type.name,
      'status': status.name,
      'max_participants': maxParticipants,
      'is_one_to_one': isOneToOne,
      'participants': participants.map((p) => p.toJson()).toList(),
      'created_at': createdAt.toIso8601String(),
      'started_at': startedAt?.toIso8601String(),
      'ended_at': endedAt?.toIso8601String(),
      'metadata': metadata,
    };
  }

  int get participantCount => participants.length;
  bool get isFull => participantCount >= maxParticipants;
  bool get isActive => status == RoomStatus.active;
}
