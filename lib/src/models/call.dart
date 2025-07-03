import 'package:talklynk_sdk/talklynk_sdk.dart';

enum CallType { audio, video }

enum CallStatus { ringing, active, ended, rejected, missed }

class Call {
  final String callId;
  final String roomId;
  final User caller;
  final User callee;
  final CallType type;
  final CallStatus status;
  final DateTime initiatedAt;
  final DateTime? answeredAt;
  final DateTime? endedAt;
  final String? rejectionReason;
  final Map<String, dynamic>? metadata;

  const Call({
    required this.callId,
    required this.roomId,
    required this.caller,
    required this.callee,
    required this.type,
    required this.status,
    required this.initiatedAt,
    this.answeredAt,
    this.endedAt,
    this.rejectionReason,
    this.metadata,
  });

  factory Call.fromJson(Map<String, dynamic> json) {
    return Call(
      callId: json['call_id'] ?? json['room_id'] ?? '',
      roomId: json['room_id'] ?? '',
      caller: User.fromJson(json['caller'] ?? {}),
      callee: User.fromJson(json['callee'] ?? {}),
      type: CallType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => CallType.video,
      ),
      status: CallStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => CallStatus.ringing,
      ),
      initiatedAt: DateTime.parse(
          json['initiated_at'] ?? DateTime.now().toIso8601String()),
      answeredAt: json['answered_at'] != null
          ? DateTime.parse(json['answered_at'])
          : null,
      endedAt:
          json['ended_at'] != null ? DateTime.parse(json['ended_at']) : null,
      rejectionReason: json['rejection_reason'],
      metadata: json['metadata'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'call_id': callId,
      'room_id': roomId,
      'caller': caller.toJson(),
      'callee': callee.toJson(),
      'type': type.name,
      'status': status.name,
      'initiated_at': initiatedAt.toIso8601String(),
      'answered_at': answeredAt?.toIso8601String(),
      'ended_at': endedAt?.toIso8601String(),
      'rejection_reason': rejectionReason,
      'metadata': metadata,
    };
  }

  Call copyWith({
    String? callId,
    String? roomId,
    User? caller,
    User? callee,
    CallType? type,
    CallStatus? status,
    DateTime? initiatedAt,
    DateTime? answeredAt,
    DateTime? endedAt,
    String? rejectionReason,
    Map<String, dynamic>? metadata,
  }) {
    return Call(
      callId: callId ?? this.callId,
      roomId: roomId ?? this.roomId,
      caller: caller ?? this.caller,
      callee: callee ?? this.callee,
      type: type ?? this.type,
      status: status ?? this.status,
      initiatedAt: initiatedAt ?? this.initiatedAt,
      answeredAt: answeredAt ?? this.answeredAt,
      endedAt: endedAt ?? this.endedAt,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      metadata: metadata ?? this.metadata,
    );
  }

  Duration? get duration {
    if (answeredAt == null || endedAt == null) return null;
    return endedAt!.difference(answeredAt!);
  }

  bool get isActive => status == CallStatus.active;
  bool get isRinging => status == CallStatus.ringing;
  bool get isEnded =>
      status == CallStatus.ended ||
      status == CallStatus.rejected ||
      status == CallStatus.missed;
}
