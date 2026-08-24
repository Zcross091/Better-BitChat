import 'package:flutter_test/flutter_test.dart';
import 'package:mesh_messenger/core/models/bundle.dart';
import 'package:mesh_messenger/transports/lora_transport.dart';

void main() {
  group('LoRa Companion Radio Transport Driver Tests', () {
    late LoraTransport lora;

    setUp(() {
      lora = LoraTransport();
    });

    test('Initializes LoRa hardware radio parameters and link state', () async {
      await lora.initialize();
      expect(lora.isConnected, isTrue);
      expect(lora.frequencyMhz, equals(915.0));
      expect(lora.spreadingFactor, equals(LoraSpreadingFactor.sf9));
      expect(lora.lastRssi, lessThan(0.0));
    });

    test('Transmits DTN bundle over LoRa physical link', () async {
      await lora.initialize();
      final bundle = Bundle(
        bundleId: 'bundle_lora_tx_01',
        senderPubkey: 'sender_pub_lora',
        destPubkey: 'dest_pub_lora',
        createdAt: DateTime.now().millisecondsSinceEpoch,
        ttlHours: 24,
        hopCount: 0,
        priority: BundlePriority.normal,
        payload: 'LORA_FIELD_TELEMETRY_PACKET',
        signature: 'sig',
      );

      final ok = await lora.sendBundle(bundle);
      expect(ok, isTrue);
    });

    test('Receives and emits raw incoming LoRa packet frames', () async {
      await lora.initialize();

      final incoming = Bundle(
        bundleId: 'bundle_lora_rx_02',
        senderPubkey: 'field_relay_pub',
        destPubkey: 'all',
        createdAt: DateTime.now().millisecondsSinceEpoch,
        ttlHours: 48,
        hopCount: 1,
        priority: BundlePriority.high,
        payload: 'FIELD_SOS_RELIEF_DATA',
        signature: 'sig_relay',
      );

      expectLater(
        lora.incomingBundles,
        emits(predicate<Bundle>((b) => b.bundleId == 'bundle_lora_rx_02')),
      );

      lora.injectIncomingRawLoraPacket(incoming.toJson().toString().replaceAll("'", '"'));
    });
  });
}
