import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import '../models/bundle.dart';

enum MeshtasticPortNum {
  unknownApp(0),
  textMessageApp(1),
  remoteHardwareApp(2),
  positionApp(3),
  nodeInfoApp(4),
  routingApp(5),
  telemetryApp(67),
  dtnBundleApp(72);

  final int value;
  const MeshtasticPortNum(this.value);

  static MeshtasticPortNum fromValue(int val) {
    return MeshtasticPortNum.values.firstWhere(
      (e) => e.value == val,
      orElse: () => MeshtasticPortNum.unknownApp,
    );
  }
}

class MeshtasticPacket {
  static const int start1 = 0x94;
  static const int start2 = 0xC3;
  static const int broadcastAddr = 0xFFFFFFFF;

  final int fromNode;
  final int toNode;
  final int id;
  final int hopLimit;
  final int channel; // Channel hash (0 = Primary Default)
  final MeshtasticPortNum portNum;
  final Uint8List payload;
  final bool wantAck;

  MeshtasticPacket({
    required this.fromNode,
    required this.toNode,
    required this.id,
    this.hopLimit = 3,
    this.channel = 0,
    required this.portNum,
    required this.payload,
    this.wantAck = false,
  });

  /// Encodes this packet into a framed binary byte buffer for UART/Serial transmission
  Uint8List toFramedBytes() {
    final payloadLen = payload.length;
    final totalLen = 2 + 2 + 4 + 4 + 4 + 1 + 1 + 1 + 1 + payloadLen; // Start(2) + Len(2) + Header(16) + Payload
    final byteData = ByteData(totalLen);

    int offset = 0;
    // 1. Framing Start Bytes
    byteData.setUint8(offset++, start1);
    byteData.setUint8(offset++, start2);

    // 2. Length (Big Endian)
    final packetBodyLen = 16 + payloadLen;
    byteData.setUint16(offset, packetBodyLen, Endian.big);
    offset += 2;

    // 3. Header Fields
    byteData.setUint32(offset, fromNode, Endian.big);
    offset += 4;

    byteData.setUint32(offset, toNode, Endian.big);
    offset += 4;

    byteData.setUint32(offset, id, Endian.big);
    offset += 4;

    byteData.setUint8(offset++, hopLimit);
    byteData.setUint8(offset++, channel);
    byteData.setUint8(offset++, portNum.value);
    byteData.setUint8(offset++, wantAck ? 1 : 0);

    // 4. Payload Bytes
    final bufferList = byteData.buffer.asUint8List();
    bufferList.setRange(offset, offset + payloadLen, payload);

    return bufferList;
  }

  /// Parses a framed binary byte buffer received from UART/Serial
  static MeshtasticPacket? fromFramedBytes(Uint8List bytes) {
    if (bytes.length < 20) return null; // Minimum header size

    final byteData = ByteData.sublistView(bytes);
    int offset = 0;

    // 1. Verify Start Bytes
    final s1 = byteData.getUint8(offset++);
    final s2 = byteData.getUint8(offset++);
    if (s1 != start1 || s2 != start2) return null;

    // 2. Read Length
    final bodyLen = byteData.getUint16(offset, Endian.big);
    offset += 2;

    if (bytes.length < 4 + bodyLen) return null; // Incomplete frame

    // 3. Read Header
    final fromNode = byteData.getUint32(offset, Endian.big);
    offset += 4;

    final toNode = byteData.getUint32(offset, Endian.big);
    offset += 4;

    final id = byteData.getUint32(offset, Endian.big);
    offset += 4;

    final hopLimit = byteData.getUint8(offset++);
    final channel = byteData.getUint8(offset++);
    final portNumVal = byteData.getUint8(offset++);
    final wantAckVal = byteData.getUint8(offset++);

    // 4. Read Payload
    final payloadLen = bodyLen - 16;
    final payloadBytes = bytes.sublist(offset, offset + payloadLen);

    return MeshtasticPacket(
      fromNode: fromNode,
      toNode: toNode,
      id: id,
      hopLimit: hopLimit,
      channel: channel,
      portNum: MeshtasticPortNum.fromValue(portNumVal),
      payload: payloadBytes,
      wantAck: wantAckVal == 1,
    );
  }

  /// Converts a standard DTN Bundle into a Meshtastic interoperable packet
  static MeshtasticPacket fromDtnBundle(Bundle bundle) {
    final senderHash = _pubKeyToNodeId(bundle.senderPubkey);
    final destHash = (bundle.destPubkey == 'all' || bundle.destPubkey.startsWith('group_'))
        ? broadcastAddr
        : _pubKeyToNodeId(bundle.destPubkey);

    final payloadBytes = utf8.encode(bundle.payload);

    return MeshtasticPacket(
      fromNode: senderHash,
      toNode: destHash,
      id: bundle.createdAt & 0xFFFFFFFF,
      hopLimit: (7 - bundle.hopCount).clamp(0, 7),
      channel: 0,
      portNum: MeshtasticPortNum.dtnBundleApp,
      payload: Uint8List.fromList(payloadBytes),
      wantAck: bundle.priority == BundlePriority.high,
    );
  }

  /// Converts an incoming Meshtastic packet into a native DTN Bundle
  Bundle toDtnBundle() {
    final senderPub = 'mesh_${fromNode.toRadixString(16).padLeft(8, '0')}';
    final destPub = (toNode == broadcastAddr) ? 'all' : 'mesh_${toNode.toRadixString(16).padLeft(8, '0')}';
    final textPayload = utf8.decode(payload, allowMalformed: true);

    return Bundle(
      bundleId: Bundle.generateBundleId(
        senderPubkey: senderPub,
        destPubkey: destPub,
        createdAt: DateTime.now().millisecondsSinceEpoch,
        nonce: 'meshtastic_${id.toRadixString(16)}',
      ),
      senderPubkey: senderPub,
      destPubkey: destPub,
      createdAt: DateTime.now().millisecondsSinceEpoch,
      ttlHours: 24,
      hopCount: (7 - hopLimit).clamp(0, 7),
      priority: wantAck ? BundlePriority.high : BundlePriority.normal,
      payload: textPayload,
      signature: 'sig_meshtastic_hw',
    );
  }

  static int _pubKeyToNodeId(String pubKey) {
    final bytes = sha256.convert(utf8.encode(pubKey)).bytes;
    return (bytes[0] << 24) | (bytes[1] << 16) | (bytes[2] << 8) | bytes[3];
  }

  @override
  String toString() => 'MeshtasticPacket(from: !${fromNode.toRadixString(16)}, to: !${toNode.toRadixString(16)}, port: ${portNum.name}, bytes: ${payload.length})';
}
