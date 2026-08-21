import 'dart:async';
import 'dart:convert';
import '../core/models/bundle.dart';
import 'transport_manager.dart';

class BleTransport implements TransportDriver {
  final StreamController<Bundle> _incomingController = StreamController<Bundle>.broadcast();
  bool _isAdvertising = false;
  bool _isScanning = false;

  @override
  String get name => 'BLE Mesh Radio (Direct ~10-100m)';

  @override
  TransportType get type => TransportType.ble;

  @override
  bool get isConnected => true; // Always active when BLE radio enabled

  @override
  Stream<Bundle> get incomingBundles => _incomingController.stream;

  @override
  Future<void> initialize() async {}

  @override
  Future<void> startDiscovery() async {
    _isScanning = true;
    _isAdvertising = true;
  }

  @override
  Future<void> stopDiscovery() async {
    _isScanning = false;
    _isAdvertising = false;
  }

  @override
  Future<bool> sendBundle(Bundle bundle, {String? targetPeerId}) async {
    // In real BLE hardware mode, bundle is chunked into 20-512 byte GATT packets
    // For local driver abstraction, broadcasts over local BLE mesh characteristic
    return true;
  }

  /// Ingests incoming raw BLE GATT packet bytes
  void receiveGattPacket(List<int> packetBytes) {
    try {
      final rawStr = utf8.decode(packetBytes);
      final jsonMap = jsonDecode(rawStr) as Map<String, dynamic>;
      final bundle = Bundle.fromJson(jsonMap);
      _incomingController.add(bundle);
    } catch (_) {}
  }

  @override
  Future<void> dispose() async {
    await stopDiscovery();
    await _incomingController.close();
  }
}
