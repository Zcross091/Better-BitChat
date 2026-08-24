import 'dart:convert';
import 'package:crypto/crypto.dart';

/// Represents a single micro-fragment of a DTN bundle (RFC 9171 Section 5.8).
/// Used when payload exceeds transport MTU (e.g., 200 bytes for LoRa/BLE).
class BundleFragment {
  final String bundleId;
  final int fragmentIndex;
  final int totalFragments;
  final int fragmentOffset;
  final int totalBundleSize;
  final String payloadChunk; // Base64 encoded slice
  final String checksum; // SHA-256 slice integrity hash

  BundleFragment({
    required this.bundleId,
    required this.fragmentIndex,
    required this.totalFragments,
    required this.fragmentOffset,
    required this.totalBundleSize,
    required this.payloadChunk,
    required this.checksum,
  });

  /// Derives fragment checksum
  static String calculateChecksum(String chunk) {
    return sha256.convert(utf8.encode(chunk)).toString().substring(0, 8);
  }

  Map<String, dynamic> toJson() {
    return {
      'bundle_id': bundleId,
      'fragment_index': fragmentIndex,
      'total_fragments': totalFragments,
      'fragment_offset': fragmentOffset,
      'total_bundle_size': totalBundleSize,
      'payload_chunk': payloadChunk,
      'checksum': checksum,
    };
  }

  factory BundleFragment.fromJson(Map<String, dynamic> json) {
    return BundleFragment(
      bundleId: json['bundle_id'] as String,
      fragmentIndex: json['fragment_index'] as int,
      totalFragments: json['total_fragments'] as int,
      fragmentOffset: json['fragment_offset'] as int,
      totalBundleSize: json['total_bundle_size'] as int,
      payloadChunk: json['payload_chunk'] as String,
      checksum: json['checksum'] as String,
    );
  }

  bool get isChecksumValid => calculateChecksum(payloadChunk) == checksum;

  @override
  String toString() => 'BundleFragment(id: ${bundleId.substring(0, 8)}, part: ${fragmentIndex + 1}/$totalFragments)';
}
