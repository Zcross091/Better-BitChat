import 'dart:convert';

/// Represents a civilian user profile with custom handles, avatar, and verification badges.
class UserProfile {
  final String pubKeyHex;
  String username; // e.g. "alice_99" (without @)
  String displayName; // e.g. "Alice Walker"
  String bio; // e.g. "Offline-first mesh pioneer 📡"
  int avatarSeed; // Index or seed for generating colorful avatar icons
  String nip05Handle; // e.g. "alice@mesh.nostr"
  bool isVerified;

  UserProfile({
    required this.pubKeyHex,
    required this.username,
    required this.displayName,
    this.bio = 'Available on Mesh Network 📡',
    this.avatarSeed = 1,
    this.nip05Handle = '',
    this.isVerified = false,
  });

  String get handle => '@$username';

  Map<String, dynamic> toJson() => {
        'pub_key_hex': pubKeyHex,
        'username': username,
        'display_name': displayName,
        'bio': bio,
        'avatar_seed': avatarSeed,
        'nip05_handle': nip05Handle,
        'is_verified': isVerified,
      };

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
        pubKeyHex: json['pub_key_hex'] as String,
        username: json['username'] as String? ?? 'user',
        displayName: json['display_name'] as String? ?? 'Anonymous Peer',
        bio: json['bio'] as String? ?? '',
        avatarSeed: json['avatar_seed'] as int? ?? 1,
        nip05Handle: json['nip05_handle'] as String? ?? '',
        isVerified: json['is_verified'] as bool? ?? false,
      );

  UserProfile copyWith({
    String? username,
    String? displayName,
    String? bio,
    int? avatarSeed,
    String? nip05Handle,
    bool? isVerified,
  }) {
    return UserProfile(
      pubKeyHex: pubKeyHex,
      username: username ?? this.username,
      displayName: displayName ?? this.displayName,
      bio: bio ?? this.bio,
      avatarSeed: avatarSeed ?? this.avatarSeed,
      nip05Handle: nip05Handle ?? this.nip05Handle,
      isVerified: isVerified ?? this.isVerified,
    );
  }
}
