import 'package:talklynk_sdk/talklynk_sdk.dart';

enum ParticipantStatus { active, left, kicked, banned }

enum ParticipantRole { admin, participant, caller, callee }

class Participant {
  final String id;
  final String userId;
  final User? user;
  final ParticipantRole role;
  final ParticipantStatus status;
  final DateTime joinedAt;
  final DateTime? leftAt;
  final String? joinedVia;
  final Map<String, dynamic>? metadata;

  const Participant({
    required this.id,
    required this.userId,
    this.user,
    required this.role,
    required this.status,
    required this.joinedAt,
    this.leftAt,
    this.joinedVia,
    this.metadata,
  });

  factory Participant.fromJson(Map<String, dynamic> json) {
    return Participant(
      id: json['id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      user: json['user'] != null ? User.fromJson(json['user']) : null,
      role: ParticipantRole.values.firstWhere(
        (e) => e.name == json['role'],
        orElse: () => ParticipantRole.participant,
      ),
      status: ParticipantStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => ParticipantStatus.active,
      ),
      joinedAt:
          DateTime.parse(json['joined_at'] ?? DateTime.now().toIso8601String()),
      leftAt: json['left_at'] != null ? DateTime.parse(json['left_at']) : null,
      joinedVia: json['joined_via'],
      metadata: json['metadata'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'user': user?.toJson(),
      'role': role.name,
      'status': status.name,
      'joined_at': joinedAt.toIso8601String(),
      'left_at': leftAt?.toIso8601String(),
      'joined_via': joinedVia,
      'metadata': metadata,
    };
  }

  bool get isAdmin => role == ParticipantRole.admin;
  bool get isActive => status == ParticipantStatus.active;
  String get displayName =>
      metadata?['display_name'] ?? user?.name ?? 'Unknown';
}
