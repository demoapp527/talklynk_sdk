class User {
  final String id;
  final String name;
  final String? email;
  final String? externalId;
  final String? avatarUrl;
  final Map<String, dynamic>? metadata;
  final String status;
  final DateTime? lastActiveAt;
  final DateTime? emailVerifiedAt;
  final bool isAdmin;
  final String? stripeId;
  final String? pmType;
  final String? pmLastFour;
  final DateTime? trialEndsAt;
  final int? clientId;
  final Map<String, dynamic>? settings;
  final DateTime? lastSeenAt;
  final DateTime? suspendedAt;

  const User({
    required this.id,
    required this.name,
    this.email,
    this.externalId,
    this.avatarUrl,
    this.metadata,
    this.status = 'active',
    this.lastActiveAt,
    this.emailVerifiedAt,
    this.isAdmin = false,
    this.stripeId,
    this.pmType,
    this.pmLastFour,
    this.trialEndsAt,
    this.clientId,
    this.settings,
    this.lastSeenAt,
    this.suspendedAt,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id']?.toString() ?? '',
      name: json['name'] ?? '',
      email: json['email'],
      externalId: json['external_id'],
      avatarUrl: json['avatar_url'],
      metadata: json['metadata'],
      status: json['status'] ?? 'active',
      lastActiveAt: json['last_active_at'] != null
          ? DateTime.parse(json['last_active_at'])
          : null,
      emailVerifiedAt: json['email_verified_at'] != null
          ? DateTime.parse(json['email_verified_at'])
          : null,
      // Convert integer to boolean
      isAdmin: _convertToBool(json['is_admin']),
      stripeId: json['stripe_id'],
      pmType: json['pm_type'],
      pmLastFour: json['pm_last_four'],
      trialEndsAt: json['trial_ends_at'] != null
          ? DateTime.parse(json['trial_ends_at'])
          : null,
      clientId: json['client_id'],
      settings: json['settings'],
      lastSeenAt: json['last_seen_at'] != null
          ? DateTime.parse(json['last_seen_at'])
          : null,
      suspendedAt: json['suspended_at'] != null
          ? DateTime.parse(json['suspended_at'])
          : null,
    );
  }

  // Helper method to convert various types to boolean
  static bool _convertToBool(dynamic value) {
    if (value is bool) return value;
    if (value is int) return value != 0;
    if (value is String) return value.toLowerCase() == 'true' || value == '1';
    return false;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'external_id': externalId,
      'avatar_url': avatarUrl,
      'metadata': metadata,
      'status': status,
      'last_active_at': lastActiveAt?.toIso8601String(),
      'email_verified_at': emailVerifiedAt?.toIso8601String(),
      'is_admin': isAdmin,
      'stripe_id': stripeId,
      'pm_type': pmType,
      'pm_last_four': pmLastFour,
      'trial_ends_at': trialEndsAt?.toIso8601String(),
      'client_id': clientId,
      'settings': settings,
      'last_seen_at': lastSeenAt?.toIso8601String(),
      'suspended_at': suspendedAt?.toIso8601String(),
    };
  }

  User copyWith({
    String? id,
    String? name,
    String? email,
    String? externalId,
    String? avatarUrl,
    Map<String, dynamic>? metadata,
    String? status,
    DateTime? lastActiveAt,
    DateTime? emailVerifiedAt,
    bool? isAdmin,
    String? stripeId,
    String? pmType,
    String? pmLastFour,
    DateTime? trialEndsAt,
    int? clientId,
    Map<String, dynamic>? settings,
    DateTime? lastSeenAt,
    DateTime? suspendedAt,
  }) {
    return User(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      externalId: externalId ?? this.externalId,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      metadata: metadata ?? this.metadata,
      status: status ?? this.status,
      lastActiveAt: lastActiveAt ?? this.lastActiveAt,
      emailVerifiedAt: emailVerifiedAt ?? this.emailVerifiedAt,
      isAdmin: isAdmin ?? this.isAdmin,
      stripeId: stripeId ?? this.stripeId,
      pmType: pmType ?? this.pmType,
      pmLastFour: pmLastFour ?? this.pmLastFour,
      trialEndsAt: trialEndsAt ?? this.trialEndsAt,
      clientId: clientId ?? this.clientId,
      settings: settings ?? this.settings,
      lastSeenAt: lastSeenAt ?? this.lastSeenAt,
      suspendedAt: suspendedAt ?? this.suspendedAt,
    );
  }
}
