import 'dart:convert';
import 'package:crypto/crypto.dart';

class FountainDroplet {
  final int seq;
  final int total;
  final String checksum;
  final String chunk;

  FountainDroplet({
    required this.seq,
    required this.total,
    required this.checksum,
    required this.chunk,
  });

  /// Encodes droplet into compact JSON payload string for QR generation
  String serialize() {
    return 'FQ:1:$seq:$total:$checksum:$chunk';
  }

  static FountainDroplet? deserialize(String raw) {
    if (!raw.startsWith('FQ:1:')) return null;
    final parts = raw.split(':');
    if (parts.length < 6) return null;

    final seq = int.tryParse(parts[2]);
    final total = int.tryParse(parts[3]);
    final checksum = parts[4];
    final chunk = parts.sublist(5).join(':');

    if (seq == null || total == null) return null;

    return FountainDroplet(
      seq: seq,
      total: total,
      checksum: checksum,
      chunk: chunk,
    );
  }
}

/// Implements rapid cycling animated QR fountain streaming (Screen-to-Camera Air Gap transfer)
class FountainQrEngine {
  final int maxChunkChars;

  FountainQrEngine({this.maxChunkChars = 280});

  /// Slices payload string into cycling fountain droplets
  List<FountainDroplet> encodePayload(String rawPayload) {
    final checksum = sha256.convert(utf8.encode(rawPayload)).toString().substring(0, 8);
    final totalChars = rawPayload.length;

    if (totalChars <= maxChunkChars) {
      return [
        FountainDroplet(seq: 0, total: 1, checksum: checksum, chunk: rawPayload),
      ];
    }

    final totalFrames = (totalChars / maxChunkChars).ceil();
    final droplets = <FountainDroplet>[];

    for (int i = 0; i < totalFrames; i++) {
      final start = i * maxChunkChars;
      final end = (start + maxChunkChars > totalChars) ? totalChars : start + maxChunkChars;
      final chunk = rawPayload.substring(start, end);

      droplets.add(
        FountainDroplet(
          seq: i,
          total: totalFrames,
          checksum: checksum,
          chunk: chunk,
        ),
      );
    }

    return droplets;
  }
}

/// Ingests camera-scanned droplets and reconstructs the original payload upon receiving all parts
class FountainQrDecoder {
  final Map<int, String> _receivedChunks = {};
  int _totalFrames = 0;
  String _expectedChecksum = '';

  bool get isComplete => _totalFrames > 0 && _receivedChunks.length == _totalFrames;
  double get progress => _totalFrames == 0 ? 0.0 : _receivedChunks.length / _totalFrames;
  int get receivedCount => _receivedChunks.length;
  int get totalCount => _totalFrames;

  /// Ingests a raw scanned string. Returns true if this droplet completed the full payload.
  bool ingestScannedString(String raw) {
    final droplet = FountainDroplet.deserialize(raw);
    if (droplet == null) return false;

    if (_totalFrames == 0) {
      _totalFrames = droplet.total;
      _expectedChecksum = droplet.checksum;
    } else if (droplet.checksum != _expectedChecksum || droplet.total != _totalFrames) {
      // Different payload detected, reset
      reset();
      _totalFrames = droplet.total;
      _expectedChecksum = droplet.checksum;
    }

    _receivedChunks[droplet.seq] = droplet.chunk;
    return isComplete;
  }

  /// Reconstructs verified payload when complete
  String? getReconstructedPayload() {
    if (!isComplete) return null;

    final sortedIndexes = _receivedChunks.keys.toList()..sort();
    final builder = StringBuffer();
    for (final i in sortedIndexes) {
      builder.write(_receivedChunks[i]);
    }

    final full = builder.toString();
    final actualChecksum = sha256.convert(utf8.encode(full)).toString().substring(0, 8);
    if (actualChecksum != _expectedChecksum) {
      return null; // Integrity failure
    }

    return full;
  }

  void reset() {
    _receivedChunks.clear();
    _totalFrames = 0;
    _expectedChecksum = '';
  }
}
