import 'package:flutter_test/flutter_test.dart';
import 'package:mesh_messenger/core/crypto/fountain_qr.dart';

void main() {
  group('Fountain QR Sneakernet Stream Tests', () {
    test('Encodes payload into serialized fountain droplets and reconstructs cleanly', () {
      final engine = FountainQrEngine(maxChunkChars: 30);
      final rawPayload = 'AIR_GAP_ENCRYPTED_DTN_PAYLOAD_TRANSFER_STREAM_RECONSTRUCTION_TEST_DATA';
      final droplets = engine.encodePayload(rawPayload);

      expect(droplets.length, greaterThan(1));

      final decoder = FountainQrDecoder();
      for (final droplet in droplets) {
        final serialized = droplet.serialize();
        expect(serialized.startsWith('FQ:1:'), isTrue);

        final isDone = decoder.ingestScannedString(serialized);
        if (droplet == droplets.last) {
          expect(isDone, isTrue);
        }
      }

      expect(decoder.isComplete, isTrue);
      expect(decoder.progress, equals(1.0));
      expect(decoder.getReconstructedPayload(), equals(rawPayload));
    });

    test('Handles out-of-order and duplicate fountain droplets gracefully', () {
      final engine = FountainQrEngine(maxChunkChars: 25);
      final payload = 'DTN_FOUNTAIN_STREAM_SCRAMBLED_DROPS';
      final droplets = engine.encodePayload(payload);

      final decoder = FountainQrDecoder();

      // Send duplicated and scrambled droplets
      final stream = [...droplets, ...droplets]..shuffle();
      for (final d in stream) {
        decoder.ingestScannedString(d.serialize());
      }

      expect(decoder.isComplete, isTrue);
      expect(decoder.getReconstructedPayload(), equals(payload));
    });
  });
}
