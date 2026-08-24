import 'dart:async';
import 'dart:typed_data';
import '../core/hardware/meshtastic_interop.dart';
import '../core/hardware/serial_port_driver.dart';
import '../core/models/bundle.dart';
import 'transport_manager.dart';

/// Hardware Serial Transport Driver for USB-C OTG cables & Bluetooth SPP companion radios
/// (Heltec WiFi LoRa 32, LilyGO T-Beam, SX1262 LoRa modules) running Meshtastic firmware @ 115200 baud.
class UsbSerialLoraTransport implements TransportDriver {
  final SerialPortDriver serialDriver;

  @override
  String get name => 'USB-OTG Serial Radio (115200 Baud)';

  @override
  TransportType get type => TransportType.usbSerialLora;

  @override
  bool get isConnected => serialDriver.isOpen;

  final StreamController<Bundle> _incomingController = StreamController<Bundle>.broadcast();
  @override
  Stream<Bundle> get incomingBundles => _incomingController.stream;

  StreamSubscription? _rxSubscription;

  UsbSerialLoraTransport({SerialPortDriver? driver})
      : serialDriver = driver ?? SerialPortDriver();

  @override
  Future<void> initialize() async {
    await serialDriver.open();
    _rxSubscription = serialDriver.rxStream.listen(_handleIncomingBytes);
  }

  @override
  Future<void> startDiscovery() async {
    if (!serialDriver.isOpen) {
      await serialDriver.open();
    }
  }

  @override
  Future<void> stopDiscovery() async {
    await serialDriver.close();
  }

  @override
  Future<bool> sendBundle(Bundle bundle, {String? targetPeerId}) async {
    if (!isConnected) return false;

    // Convert DTN bundle into Meshtastic binary packet frame
    final meshPacket = MeshtasticPacket.fromDtnBundle(bundle);
    final framedBytes = meshPacket.toFramedBytes();

    final summary = 'TX MESH [!${meshPacket.toNode.toRadixString(16)}]: ${bundle.bundleId.substring(0, 8)} (${framedBytes.length}b)';
    return await serialDriver.write(framedBytes, summary: summary);
  }

  void _handleIncomingBytes(Uint8List bytes) {
    try {
      final packet = MeshtasticPacket.fromFramedBytes(bytes);
      if (packet != null) {
        final dtnBundle = packet.toDtnBundle();
        _incomingController.add(dtnBundle);
      }
    } catch (_) {}
  }

  /// Ingests a raw byte array into the transport (used by physical bridge and unit tests)
  void injectRawUartBytes(Uint8List bytes) {
    serialDriver.injectIncomingBytes(bytes);
  }

  @override
  Future<void> dispose() async {
    await _rxSubscription?.cancel();
    await serialDriver.dispose();
    await _incomingController.close();
  }
}
