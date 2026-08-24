import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:mesh_messenger/core/hardware/meshtastic_interop.dart';
import 'package:mesh_messenger/core/models/bundle.dart';

void main() {
  group('Meshtastic Protocol Interop & Binary Framing Tests', () {
    test('Encodes MeshtasticPacket into framed bytes and decodes back with 100% fidelity', () {
      final packet = MeshtasticPacket(
        fromNode: 0x11223344,
        toNode: 0x55667788,
        id: 0xAABBCCDD,
        hopLimit: 3,
        channel: 0,
        portNum: MeshtasticPortNum.textMessageApp,
        payload: Uint8List.fromList(utf8.encode('Hello Meshtastic Mesh from Flutter DTN!')),
        wantAck: true,
      );

      final framedBytes = packet.toFramedBytes();
      expect(framedBytes[0], equals(MeshtasticPacket.start1)); // 0x94
      expect(framedBytes[1], equals(MeshtasticPacket.start2)); // 0xC3

      final decoded = MeshtasticPacket.fromFramedBytes(framedBytes);
      expect(decoded, isNotNull);
      expect(decoded!.fromNode, equals(0x11223344));
      expect(decoded.toNode, equals(0x55667788));
      expect(decoded.id, equals(0xAABBCCDD));
      expect(decoded.hopLimit, equals(3));
      expect(decoded.portNum, equals(MeshtasticPortNum.textMessageApp));
      expect(decoded.wantAck, isTrue);
      expect(utf8.decode(decoded.payload), equals('Hello Meshtastic Mesh from Flutter DTN!'));
    });

    test('Converts native DTN Bundle to MeshtasticPacket and back seamlessly', () {
      final bundle = Bundle(
        bundleId: 'dtn_bundle_mesh_interop_01',
        senderPubkey: 'pub_alice_ed25519_node_01',
        destPubkey: 'all',
        createdAt: 1700000000,
        ttlHours: 48,
        hopCount: 2,
        priority: BundlePriority.high,
        payload: 'EMERGENCY_COORDINATES_RELIEF_GRID_44',
        signature: 'sig_ed25519_alice',
      );

      final meshPacket = MeshtasticPacket.fromDtnBundle(bundle);
      expect(meshPacket.toNode, equals(MeshtasticPacket.broadcastAddr)); // 0xFFFFFFFF
      expect(meshPacket.portNum, equals(MeshtasticPortNum.dtnBundleApp));
      expect(meshPacket.wantAck, isTrue);

      final framed = meshPacket.toFramedBytes();
      final rxPacket = MeshtasticPacket.fromFramedBytes(framed);
      expect(rxPacket, isNotNull);

      final convertedBundle = rxPacket!.toDtnBundle();
      expect(convertedBundle.destPubkey, equals('all'));
      expect(convertedBundle.payload, equals('EMERGENCY_COORDINATES_RELIEF_GRID_44'));
      expect(convertedBundle.priority, equals(BundlePriority.high));
    });

    test('Rejects invalid binary frames with wrong start markers or short length', () {
      final invalidStart = Uint8List.fromList([0x00, 0x00, 0x00, 0x10, 0x11, 0x22]);
      expect(MeshtasticPacket.fromFramedBytes(invalidStart), isNull);

      final tooShort = Uint8List.fromList([0x94, 0xC3, 0x00, 0x05]);
      expect(MeshtasticPacket.fromFramedBytes(tooShort), isNull);
    });
  });
}
