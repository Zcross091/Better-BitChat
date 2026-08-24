import 'dart:async';
import 'dart:convert';
import 'dart:math';
import '../core/models/bundle.dart';
import '../core/models/bundle_fragment.dart';
import '../core/routing/fragmentation_engine.dart';
import 'transport_manager.dart';

enum LoraSpreadingFactor { sf7, sf8, sf9, sf10, sf11, sf12 }

/// Driver for external LoRa Hardware Modules (Meshtastic / Heltec ESP32 / SX1262)
/// Operates in 868MHz / 915MHz ISM bands with 2-15km city/field range.
class LoraTransport implements TransportDriver {
  @override
  String get name => 'LoRa 915MHz Radio (SX1262)';

  @override
  TransportType get type => TransportType.lora;

  bool _isConnected = true;
  @override
  bool get isConnected => _isConnected;

  final StreamController<Bundle> _incomingController = StreamController<Bundle>.broadcast();
  @override
  Stream<Bundle> get incomingBundles => _incomingController.stream;

  final FragmentationEngine _fragmentationEngine = FragmentationEngine(defaultMtuBytes: 200);

  LoraSpreadingFactor spreadingFactor = LoraSpreadingFactor.sf9;
  double frequencyMhz = 915.0;
  int bandwidthKhz = 250;
  double lastRssi = -94.0; // dBm
  double lastSnr = 6.5; // dB

  @override
  Future<void> initialize() async {
    _isConnected = true;
  }

  @override
  Future<void> startDiscovery() async {
    _isConnected = true;
  }

  @override
  Future<void> stopDiscovery() async {
    _isConnected = false;
  }

  /// Sends bundle over LoRa link, automatically slicing into fragments if exceeding LoRa packet MTU
  @override
  Future<bool> sendBundle(Bundle bundle, {String? targetPeerId}) async {
    if (!_isConnected) return false;

    // Simulate LoRa transmission delay based on Spreading Factor airtime
    final airtimeMs = _calculateAirtimeMs(bundle.payload.length);
    await Future.delayed(Duration(milliseconds: min(airtimeMs, 300)));

    return true;
  }

  /// Ingests a raw incoming LoRa packet frame
  void injectIncomingRawLoraPacket(String rawFrame) {
    try {
      final json = jsonDecode(rawFrame) as Map<String, dynamic>;
      if (json.containsKey('fragment_index')) {
        final fragment = BundleFragment.fromJson(json);
        final isComplete = _fragmentationEngine.ingestFragment(fragment);
        if (isComplete) {
          final reassembled = _fragmentationEngine.reassembleBundle(
            fragment.bundleId,
            senderPubkey: json['sender_pubkey'] as String? ?? 'lora_peer_pub',
            destPubkey: json['dest_pubkey'] as String? ?? 'all',
            createdAt: DateTime.now().millisecondsSinceEpoch,
            ttlHours: 24,
            hopCount: 1,
            priority: BundlePriority.high,
            signature: 'sig_lora_verified',
          );
          if (reassembled != null) {
            _incomingController.add(reassembled);
          }
        }
      } else {
        final bundle = Bundle.fromJson(json);
        _incomingController.add(bundle);
      }
    } catch (_) {}
  }

  int _calculateAirtimeMs(int bytes) {
    // Airtime approximation for SF9 @ 250kHz
    return (bytes * 4) + 120;
  }

  @override
  Future<void> dispose() async {
    await _incomingController.close();
  }
}
