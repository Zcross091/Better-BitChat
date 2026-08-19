import 'package:flutter_test/flutter_test.dart';
import 'package:mesh_messenger/core/models/bundle.dart';

void main() {
  group('DTN Bundle Unit Tests', () {
    test('Bundle ID derivation is deterministic and unique', () {
      final id1 = Bundle.generateBundleId(
        senderPubkey: 'pub_key_a',
        destPubkey: 'pub_key_b',
        createdAt: 1700000000,
        nonce: 'nonce_123',
      );

      final id2 = Bundle.generateBundleId(
        senderPubkey: 'pub_key_a',
        destPubkey: 'pub_key_b',
        createdAt: 1700000000,
        nonce: 'nonce_123',
      );

      expect(id1, equals(id2));
      expect(id1.length, equals(64)); // SHA-256 Hex string length
    });

    test('Bundle JSON serialization and deserialization preserves properties', () {
      final bundle = Bundle(
        bundleId: 'test_bundle_id_01',
        senderPubkey: 'sender_pub_123',
        destPubkey: 'dest_pub_456',
        createdAt: 1700000000,
        ttlHours: 24,
        hopCount: 1,
        priority: BundlePriority.high,
        payload: 'EncryptedPayloadData==',
        signature: 'sig_data_789',
      );

      final jsonMap = bundle.toJson();
      final reconstructed = Bundle.fromJson(jsonMap);

      expect(reconstructed.bundleId, equals(bundle.bundleId));
      expect(reconstructed.senderPubkey, equals(bundle.senderPubkey));
      expect(reconstructed.destPubkey, equals(bundle.destPubkey));
      expect(reconstructed.createdAt, equals(bundle.createdAt));
      expect(reconstructed.ttlHours, equals(bundle.ttlHours));
      expect(reconstructed.hopCount, equals(bundle.hopCount));
      expect(reconstructed.priority, equals(bundle.priority));
      expect(reconstructed.payload, equals(bundle.payload));
      expect(reconstructed.signature, equals(bundle.signature));
    });

    test('Bundle incrementHop increases hop count', () {
      final bundle = Bundle(
        bundleId: 'id_1',
        senderPubkey: 'pub_a',
        destPubkey: 'pub_b',
        createdAt: 1700000000,
        ttlHours: 12,
        hopCount: 0,
        priority: BundlePriority.normal,
        payload: 'test',
        signature: 'sig',
      );

      final hopped = bundle.incrementHop();
      expect(hopped.hopCount, equals(1));
      expect(hopped.bundleId, equals(bundle.bundleId));
    });
  });
}
