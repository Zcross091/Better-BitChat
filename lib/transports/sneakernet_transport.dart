import 'dart:async';
import 'dart:convert';
import '../models/bundle.dart';
import 'transport_manager.dart';

class SneakernetTransport implements TransportDriver {
  final StreamController<Bundle> _incomingController = StreamController<Bundle>.broadcast();

  @override
  String get name => 'Sneakernet (QR / USB / File)';

  @override
  TransportType get type => TransportType.sneakernet;

  @override
  bool get isConnected => true; // Always available out-of-band

  @override
  Stream<Bundle> get incomingBundles => _incomingController.stream;

  @override
  Future<void> initialize() async {}

  @override
  Future<bool> sendBundle(Bundle bundle, {String? targetPeerId}) async {
    // Sneakernet "send" generates export payload
    return true;
  }

  /// Encodes bundle into a QR string / payload representation
  String encodeBundleToQrPayload(Bundle bundle) {
    return jsonEncode(bundle.toJson());
  }

  /// Injects bundle received via camera QR scan or physical file import
  bool importScannedQrPayload(String rawPayload) {
    try {
      final jsonMap = jsonDecode(rawPayload) as Map<String, dynamic>;
      final bundle = Bundle.fromJson(jsonMap);
      _incomingController.add(bundle);
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> startDiscovery() async {}

  @override
  Future<void> stopDiscovery() async {}

  @override
  Future<void> dispose() async {
    await _incomingController.close();
  }
}
