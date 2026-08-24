import 'package:flutter_test/flutter_test.dart';
import 'package:mesh_messenger/core/models/bundle.dart';
import 'package:mesh_messenger/core/storage/persistent_bundle_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PersistentBundleStore & Priority Quota Eviction Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('Stores bundle, records custody, and enforces deduplication', () async {
      final store = PersistentBundleStore(maxCapacity: 10);
      await store.hydrate();

      final bundle = Bundle(
        bundleId: 'bundle_custody_01',
        senderPubkey: 'sender_pub_01',
        destPubkey: 'all',
        createdAt: DateTime.now().millisecondsSinceEpoch,
        ttlHours: 24,
        hopCount: 0,
        priority: BundlePriority.normal,
        payload: 'Payload test',
        signature: 'sig',
      );

      final addedFirst = store.storeBundle(bundle, ingressTransport: 'ble');
      expect(addedFirst, isTrue);
      expect(store.count, equals(1));

      final custody = store.getCustodyRecord('bundle_custody_01');
      expect(custody, isNotNull);
      expect(custody!.ingressTransport, equals('ble'));
      expect(custody.forwardedCount, equals(0));

      store.recordForwarded('bundle_custody_01');
      expect(store.getCustodyRecord('bundle_custody_01')!.forwardedCount, equals(1));

      // Deduplication: re-adding same bundle ID returns false
      final addedAgain = store.storeBundle(bundle);
      expect(addedAgain, isFalse);
      expect(store.count, equals(1));
    });

    test('Priority LRU Eviction evicts Low Priority before Normal or High SOS', () async {
      final store = PersistentBundleStore(maxCapacity: 2); // Max 2 items
      await store.hydrate();

      final highBundle = Bundle(
        bundleId: 'bundle_high_sos',
        senderPubkey: 's',
        destPubkey: 'd',
        createdAt: DateTime.now().millisecondsSinceEpoch,
        ttlHours: 48,
        hopCount: 0,
        priority: BundlePriority.high,
        payload: 'EMERGENCY_SOS',
        signature: 'sig',
      );

      final lowBundle = Bundle(
        bundleId: 'bundle_low_bulk',
        senderPubkey: 's',
        destPubkey: 'd',
        createdAt: DateTime.now().millisecondsSinceEpoch,
        ttlHours: 12,
        hopCount: 0,
        priority: BundlePriority.low,
        payload: 'BULK_TELEMETRY',
        signature: 'sig',
      );

      final normalBundle = Bundle(
        bundleId: 'bundle_normal_chat',
        senderPubkey: 's',
        destPubkey: 'd',
        createdAt: DateTime.now().millisecondsSinceEpoch,
        ttlHours: 24,
        hopCount: 0,
        priority: BundlePriority.normal,
        payload: 'CHAT_MESSAGE',
        signature: 'sig',
      );

      store.storeBundle(highBundle);
      store.storeBundle(lowBundle);
      expect(store.count, equals(2));

      // Adding 3rd item triggers LRU eviction. Low priority must be evicted!
      store.storeBundle(normalBundle);
      expect(store.count, equals(2));

      expect(store.getBundle('bundle_low_bulk'), isNull); // Evicted!
      expect(store.getBundle('bundle_high_sos'), isNotNull); // Protected!
      expect(store.getBundle('bundle_normal_chat'), isNotNull);
    });
  });
}
