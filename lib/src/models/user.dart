class User {
  final String id;
  final String name;
  final String? email;
  final String? externalId;
  final String? avatarUrl;
  final Map<String, dynamic>? metadata;
  final String status;
  final DateTime? lastActiveAt;

  const User({
    required this.id,
    required this.name,
    this.email,
    this.externalId,
    this.avatarUrl,
    this.metadata,
    this.status = 'active',
    this.lastActiveAt,
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
    );
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
    );
  }
}
