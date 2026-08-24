import 'dart:convert';
import '../models/bundle.dart';
import '../models/bundle_fragment.dart';

class ReassemblyBuffer {
  final String bundleId;
  final int totalFragments;
  final int totalBundleSize;
  final Map<int, BundleFragment> fragments = {};
  final int createdAt;

  ReassemblyBuffer({
    required this.bundleId,
    required this.totalFragments,
    required this.totalBundleSize,
    required this.createdAt,
  });

  bool get isComplete => fragments.length == totalFragments;
  double get progress => totalFragments == 0 ? 0.0 : fragments.length / totalFragments;
}

/// Implements RFC 9171 Section 5.8 Bundle Fragmentation and Reassembly Engine.
class FragmentationEngine {
  final int defaultMtuBytes;
  final Map<String, ReassemblyBuffer> _buffers = {};

  FragmentationEngine({this.defaultMtuBytes = 220});

  /// Fragments a large bundle into micro-fragments that fit low-MTU transports (LoRa / BLE)
  List<BundleFragment> fragmentBundle(Bundle bundle, {int? mtuBytes}) {
    final chunkSize = mtuBytes ?? defaultMtuBytes;
    final payload = bundle.payload;
    final totalSize = payload.length;

    if (totalSize <= chunkSize) {
      // Single chunk needed
      return [
        BundleFragment(
          bundleId: bundle.bundleId,
          fragmentIndex: 0,
          totalFragments: 1,
          fragmentOffset: 0,
          totalBundleSize: totalSize,
          payloadChunk: payload,
          checksum: BundleFragment.calculateChecksum(payload),
        ),
      ];
    }

    final fragments = <BundleFragment>[];
    final totalFragments = (totalSize / chunkSize).ceil();

    for (int i = 0; i < totalFragments; i++) {
      final start = i * chunkSize;
      final end = (start + chunkSize > totalSize) ? totalSize : start + chunkSize;
      final chunk = payload.substring(start, end);

      fragments.add(
        BundleFragment(
          bundleId: bundle.bundleId,
          fragmentIndex: i,
          totalFragments: totalFragments,
          fragmentOffset: start,
          totalBundleSize: totalSize,
          payloadChunk: chunk,
          checksum: BundleFragment.calculateChecksum(chunk),
        ),
      );
    }

    return fragments;
  }

  /// Processes an incoming micro-fragment. Returns true if this fragment completes the entire bundle.
  bool ingestFragment(BundleFragment fragment) {
    if (!fragment.isChecksumValid) {
      return false; // Corrupted fragment dropped
    }

    final buffer = _buffers.putIfAbsent(
      fragment.bundleId,
      () => ReassemblyBuffer(
        bundleId: fragment.bundleId,
        totalFragments: fragment.totalFragments,
        totalBundleSize: fragment.totalBundleSize,
        createdAt: DateTime.now().millisecondsSinceEpoch,
      ),
    );

    buffer.fragments[fragment.fragmentIndex] = fragment;
    return buffer.isComplete;
  }

  /// Checks if a bundle has been 100% reassembled
  bool isComplete(String bundleId) {
    return _buffers[bundleId]?.isComplete ?? false;
  }

  /// Returns reassembly progress ratio between 0.0 and 1.0
  double getProgress(String bundleId) {
    return _buffers[bundleId]?.progress ?? 0.0;
  }

  /// Returns total and received count: (received, total)
  Map<String, int> getFragmentCounts(String bundleId) {
    final buf = _buffers[bundleId];
    if (buf == null) return {'received': 0, 'total': 0};
    return {'received': buf.fragments.length, 'total': buf.totalFragments};
  }

  /// Reassembles the full bundle payload from buffered fragments
  Bundle? reassembleBundle(
    String bundleId, {
    required String senderPubkey,
    required String destPubkey,
    required int createdAt,
    required int ttlHours,
    required int hopCount,
    required BundlePriority priority,
    required String signature,
  }) {
    final buffer = _buffers[bundleId];
    if (buffer == null || !buffer.isComplete) return null;

    final sortedIndexes = buffer.fragments.keys.toList()..sort();
    final bufferBuilder = StringBuffer();

    for (final index in sortedIndexes) {
      bufferBuilder.write(buffer.fragments[index]!.payloadChunk);
    }

    final fullPayload = bufferBuilder.toString();
    _buffers.remove(bundleId); // Clean up buffer upon completion

    return Bundle(
      bundleId: bundleId,
      senderPubkey: senderPubkey,
      destPubkey: destPubkey,
      createdAt: createdAt,
      ttlHours: ttlHours,
      hopCount: hopCount,
      priority: priority,
      payload: fullPayload,
      signature: signature,
    );
  }

  /// Prunes stale reassembly buffers older than maxAgeHours
  void pruneStaleBuffers({int maxAgeHours = 48}) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final maxAgeMs = maxAgeHours * 3600 * 1000;
    _buffers.removeWhere((id, buf) => (now - buf.createdAt) > maxAgeMs);
  }

  void clear() {
    _buffers.clear();
  }
}
