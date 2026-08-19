import 'dart:convert';
import 'package:crypto/crypto.dart';

enum BundlePriority { low, normal, high }

class Bundle {
  final String bundleId;
  final String senderPubkey;
  final String destPubkey;
  final int createdAt; // Milliseconds since Epoch
  final int ttlHours; // Max lifetime in hours
  final int hopCount;
  final BundlePriority priority;
  final String payload; // Ciphertext (Base64/Hex)
  final String signature; // Sender's signature over payload & metadata

  Bundle({
    required this.bundleId,
    required this.senderPubkey,
    required this.destPubkey,
    required this.createdAt,
    required this.ttlHours,
    required this.hopCount,
    required this.priority,
    required this.payload,
    required this.signature,
  });

  /// Derives unique Bundle ID: SHA-256(senderPubkey + destPubkey + createdAt + nonce)
  static String generateBundleId({
    required String senderPubkey,
    required String destPubkey,
    required int createdAt,
    required String nonce,
  }) {
    final raw = '$senderPubkey:$destPubkey:$createdAt:$nonce';
    final bytes = utf8.encode(raw);
    return sha256.convert(bytes).toString();
  }

  /// Calculates whether bundle has expired based on createdAt + ttlHours
  bool get isExpired {
    final now = DateTime.now().millisecondsSinceEpoch;
    final expiryTime = createdAt + (ttlHours * 3600 * 1000);
    return now > expiryTime;
  }

  /// Creates a copy with incremented hop count
  Bundle incrementHop() {
    return Bundle(
      bundleId: bundleId,
      senderPubkey: senderPubkey,
      destPubkey: destPubkey,
      createdAt: createdAt,
      ttlHours: ttlHours,
      hopCount: hopCount + 1,
      priority: priority,
      payload: payload,
      signature: signature,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'bundle_id': bundleId,
      'sender_pubkey': senderPubkey,
      'dest_pubkey': destPubkey,
      'created_at': createdAt,
      'ttl_hours': ttlHours,
      'hop_count': hopCount,
      'priority': priority.index,
      'payload': payload,
      'signature': signature,
    };
  }

  factory Bundle.fromJson(Map<String, dynamic> json) {
    return Bundle(
      bundleId: json['bundle_id'] as String,
      senderPubkey: json['sender_pubkey'] as String,
      destPubkey: json['dest_pubkey'] as String,
      createdAt: json['created_at'] as int,
      ttlHours: json['ttl_hours'] as int,
      hopCount: json['hop_count'] as int,
      priority: BundlePriority.values[json['priority'] as int? ?? 1],
      payload: json['payload'] as String,
      signature: json['signature'] as String? ?? '',
    );
  }

  /// Returns canonical payload bytes to sign
  List<int> getSignableBytes() {
    final canonicalString = '$bundleId:$senderPubkey:$destPubkey:$createdAt:$ttlHours:$payload';
    return utf8.encode(canonicalString);
  }

  @override
  String toString() => 'Bundle(id: ${bundleId.substring(0, 8)}, hops: $hopCount, priority: ${priority.name})';
}
