import 'package:flutter_test/flutter_test.dart';
import 'package:mesh_messenger/core/models/bundle.dart';
import 'package:mesh_messenger/core/models/bundle_fragment.dart';
import 'package:mesh_messenger/core/routing/fragmentation_engine.dart';

void main() {
  group('RFC 9171 Section 5.8 Bundle Fragmentation & Reassembly Tests', () {
    late FragmentationEngine engine;

    setUp(() {
      engine = FragmentationEngine(defaultMtuBytes: 50);
    });

    test('Slices large payload into multiple micro-fragments with valid checksums', () {
      final largePayload = 'A' * 230; // 230 chars with MTU=50 -> 5 fragments
      final bundle = Bundle(
        bundleId: 'bundle_test_frag_01',
        senderPubkey: 'sender_pub_01',
        destPubkey: 'dest_pub_01',
        createdAt: 1700000000,
        ttlHours: 24,
        hopCount: 0,
        priority: BundlePriority.normal,
        payload: largePayload,
        signature: 'sig_test',
      );

      final fragments = engine.fragmentBundle(bundle, mtuBytes: 50);
      expect(fragments.length, equals(5));
      expect(fragments.first.fragmentIndex, equals(0));
      expect(fragments.last.fragmentIndex, equals(4));
      expect(fragments.first.totalFragments, equals(5));

      for (final f in fragments) {
        expect(f.isChecksumValid, isTrue);
      }
    });

    test('Reassembles out-of-order arriving fragments into complete bundle', () {
      final text = 'THE_QUICK_BROWN_FOX_JUMPS_OVER_THE_LAZY_DOG_1234567890_DTN_MESH_PAYLOAD';
      final bundle = Bundle(
        bundleId: 'bundle_test_frag_02',
        senderPubkey: 'sender_pub_02',
        destPubkey: 'dest_pub_02',
        createdAt: 1700000000,
        ttlHours: 24,
        hopCount: 0,
        priority: BundlePriority.high,
        payload: text,
        signature: 'sig_test_02',
      );

      final fragments = engine.fragmentBundle(bundle, mtuBytes: 20);
      expect(fragments.length, greaterThan(1));

      // Ingest in scrambled / out-of-order sequence: [2, 0, 3, 1, ...]
      final scrambled = List<BundleFragment>.from(fragments)..shuffle();

      for (int i = 0; i < scrambled.length; i++) {
        final isComplete = engine.ingestFragment(scrambled[i]);
        if (i == scrambled.length - 1) {
          expect(isComplete, isTrue);
        }
      }

      expect(engine.isComplete(bundle.bundleId), isTrue);

      final reassembled = engine.reassembleBundle(
        bundle.bundleId,
        senderPubkey: bundle.senderPubkey,
        destPubkey: bundle.destPubkey,
        createdAt: bundle.createdAt,
        ttlHours: bundle.ttlHours,
        hopCount: bundle.hopCount,
        priority: bundle.priority,
        signature: bundle.signature,
      );

      expect(reassembled, isNotNull);
      expect(reassembled!.payload, equals(text));
    });

    test('Drops corrupt fragment with invalid checksum', () {
      final corrupted = BundleFragment(
        bundleId: 'bundle_corrupt',
        fragmentIndex: 0,
        totalFragments: 1,
        fragmentOffset: 0,
        totalBundleSize: 20,
        payloadChunk: 'VALID_PAYLOAD_CHUNK',
        checksum: 'WRONG_CHECKSUM',
      );

      expect(corrupted.isChecksumValid, isFalse);
      final accepted = engine.ingestFragment(corrupted);
      expect(accepted, isFalse);
      expect(engine.isComplete('bundle_corrupt'), isFalse);
    });
  });
}
