class UserProfile {
  final String id;
  final String email;
  final String? displayName;
  final String? avatarUrl;
  final String role;
  final String subscriptionTier;
  final String? country;
  final String status;
  final DateTime createdAt;

  const UserProfile({
    required this.id,
    required this.email,
    required this.role,
    required this.subscriptionTier,
    required this.status,
    required this.createdAt,
    this.displayName,
    this.avatarUrl,
    this.country,
  });

  factory UserProfile.fromMap(Map<String, dynamic> map, {required String email}) {
    return UserProfile(
      id: map['id'] as String? ?? '',
      email: email,
      displayName: map['display_name'] as String?,
      avatarUrl: map['avatar_url'] as String?,
      role: map['role'] as String? ?? 'user',
      subscriptionTier: map['subscription_tier'] as String? ?? 'free',
      country: map['country'] as String?,
      status: map['status'] as String? ?? 'active',
      createdAt:
          DateTime.tryParse(map['created_at'] as String? ?? '') ?? DateTime.now(),
    );
  }
}
