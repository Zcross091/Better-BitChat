import 'dart:async';
import '../core/models/bundle.dart';
import '../core/storage/bundle_store.dart';

enum TransportType { ble, wifiDirect, nostrGateway, sneakernet, simulator, lora }

abstract class TransportDriver {
  String get name;
  TransportType get type;
  bool get isConnected;
  Stream<Bundle> get incomingBundles;

  Future<void> initialize();
  Future<bool> sendBundle(Bundle bundle, {String? targetPeerId});
  Future<void> startDiscovery();
  Future<void> stopDiscovery();
  Future<void> dispose();
}

class PeerContact {
  final String peerId;
  final String pubKey;
  final TransportType transportType;
  final bool isGateway;
  final int lastSeenMs;
  final double rssiOrQuality;

  PeerContact({
    required this.peerId,
    required this.pubKey,
    required this.transportType,
    this.isGateway = false,
    required this.lastSeenMs,
    this.rssiOrQuality = 1.0,
  });
}

class TransportManager {
  final List<TransportDriver> _drivers = [];
  final StreamController<Bundle> _bundleStreamController = StreamController<Bundle>.broadcast();
  final StreamController<List<PeerContact>> _peerStreamController = StreamController<List<PeerContact>>.broadcast();

  final Map<String, PeerContact> _activePeers = {};
  StreamSubscription? _incomingSub;

  Stream<Bundle> get onBundleReceived => _bundleStreamController.stream;
  Stream<List<PeerContact>> get onPeersChanged => _peerStreamController.stream;

  List<PeerContact> get activePeers => _activePeers.values.toList();
  List<TransportDriver> get drivers => List.unmodifiable(_drivers);

  void registerDriver(TransportDriver driver) {
    _drivers.add(driver);
    driver.incomingBundles.listen((bundle) {
      _bundleStreamController.add(bundle);
    });
  }

  Future<void> initializeAll() async {
    for (final driver in _drivers) {
      await driver.initialize();
      await driver.startDiscovery();
    }
  }

  /// Broadcasts bundle over all active transport drivers simultaneously (multi-path send)
  Future<int> broadcastBundle(Bundle bundle) async {
    int successCount = 0;
    for (final driver in _drivers) {
      if (driver.isConnected) {
        final ok = await driver.sendBundle(bundle);
        if (ok) successCount++;
      }
    }
    return successCount;
  }

  void updatePeerContact(PeerContact peer) {
    _activePeers[peer.peerId] = peer;
    _peerStreamController.add(_activePeers.values.toList());
  }

  void removePeerContact(String peerId) {
    _activePeers.remove(peerId);
    _peerStreamController.add(_activePeers.values.toList());
  }

  Future<void> dispose() async {
    await _incomingSub?.cancel();
    for (final driver in _drivers) {
      await driver.dispose();
    }
    await _bundleStreamController.close();
    await _peerStreamController.close();
  }
}
