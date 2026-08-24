import 'dart:convert';
import '../../transports/transport_manager.dart';

/// Represents a contact in the user's address book with safety number and nearby radio telemetry.
class Contact {
  final String pubKeyHex;
  String username;
  String displayName;
  String customNickname;
  String bio;
  int avatarSeed;
  bool isSafetyNumberVerified;
  int lastSeenMs;
  TransportType? activeTransport;
  double? lastRssi;

  Contact({
    required this.pubKeyHex,
    required this.username,
    required this.displayName,
    this.customNickname = '',
    this.bio = '',
    this.avatarSeed = 2,
    this.isSafetyNumberVerified = false,
    required this.lastSeenMs,
    this.activeTransport,
    this.lastRssi,
  });

  String get effectiveName => customNickname.isNotEmpty ? customNickname : displayName;
  String get handle => '@$username';

  bool get isOnline {
    final now = DateTime.now().millisecondsSinceEpoch;
    return (now - lastSeenMs) < 120000; // Seen in last 2 minutes
  }

  Map<String, dynamic> toJson() => {
        'pub_key_hex': pubKeyHex,
        'username': username,
        'display_name': displayName,
        'custom_nickname': customNickname,
        'bio': bio,
        'avatar_seed': avatarSeed,
        'is_safety_verified': isSafetyNumberVerified,
        'last_seen_ms': lastSeenMs,
        'active_transport': activeTransport?.index,
        'last_rssi': lastRssi,
      };

  factory Contact.fromJson(Map<String, dynamic> json) => Contact(
        pubKeyHex: json['pub_key_hex'] as String,
        username: json['username'] as String? ?? 'peer',
        displayName: json['display_name'] as String? ?? 'Mesh Peer',
        customNickname: json['custom_nickname'] as String? ?? '',
        bio: json['bio'] as String? ?? '',
        avatarSeed: json['avatar_seed'] as int? ?? 2,
        isSafetyNumberVerified: json['is_safety_verified'] as bool? ?? false,
        lastSeenMs: json['last_seen_ms'] as int? ?? 0,
        activeTransport: json['active_transport'] != null
            ? TransportType.values[(json['active_transport'] as int).clamp(0, TransportType.values.length - 1)]
            : null,
        lastRssi: (json['last_rssi'] as num?)?.toDouble(),
      );
}
