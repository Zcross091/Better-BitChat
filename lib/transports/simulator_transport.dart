import 'dart:async';
import 'dart:math';
import '../core/models/bundle.dart';
import '../core/storage/bundle_store.dart';
import '../core/routing/prophet_router.dart';
import 'transport_manager.dart';

class SimNode {
  final String id;
  final String name;
  final String pubKeyHex;
  double x;
  double y;
  final double range;
  final bool isGateway;
  final BundleStore store;
  final ProphetRouter router;
  bool isOnline;

  SimNode({
    required this.id,
    required this.name,
    required this.pubKeyHex,
    required this.x,
    required this.y,
    this.range = 140.0,
    this.isGateway = false,
    this.isOnline = true,
  })  : store = BundleStore(maxCapacity: 100),
        router = ProphetRouter();

  double distanceTo(SimNode other) {
    return sqrt(pow(x - other.x, 2) + pow(y - other.y, 2));
  }

  bool isInRange(SimNode other) {
    return isOnline && other.isOnline && id != other.id && distanceTo(other) <= range;
  }
}

class SimLink {
  final String nodeAId;
  final String nodeBId;
  final double distance;

  SimLink(this.nodeAId, this.nodeBId, this.distance);
}

class SimPacketHop {
  final String bundleId;
  final String fromNodeId;
  final String toNodeId;
  final double progress; // 0.0 to 1.0 animation

  SimPacketHop({
    required this.bundleId,
    required this.fromNodeId,
    required this.toNodeId,
    required this.progress,
  });
}

class SimulatorTransport implements TransportDriver {
  final StreamController<Bundle> _incomingController = StreamController<Bundle>.broadcast();
  final StreamController<List<SimNode>> _nodeStateController = StreamController<List<SimNode>>.broadcast();
  final StreamController<List<SimLink>> _linkStateController = StreamController<List<SimLink>>.broadcast();

  final List<SimNode> nodes = [];
  Timer? _simulationTimer;
  int _tickCount = 0;

  Stream<List<SimNode>> get onNodesChanged => _nodeStateController.stream;
  Stream<List<SimLink>> get onLinksChanged => _linkStateController.stream;

  SimulatorTransport() {
    _initDefaultTopology();
  }

  void _initDefaultTopology() {
    nodes.clear();
    nodes.addAll([
      SimNode(id: 'node_a', name: 'Alice (Phone)', pubKeyHex: 'pub_alice_ed25519_01', x: 80, y: 120, range: 160),
      SimNode(id: 'node_b', name: 'Bob (Relay)', pubKeyHex: 'pub_bob_ed25519_02', x: 220, y: 180, range: 160),
      SimNode(id: 'node_c', name: 'Field Pi (Relay)', pubKeyHex: 'pub_field_pi_03', x: 380, y: 130, range: 170),
      SimNode(id: 'node_d', name: 'Dave (Gateway)', pubKeyHex: 'pub_dave_gtw_04', x: 540, y: 220, range: 180, isGateway: true),
      SimNode(id: 'node_e', name: 'Eve (Receiver)', pubKeyHex: 'pub_eve_ed25519_05', x: 680, y: 110, range: 150),
    ]);
  }

  @override
  String get name => 'In-App Mesh Simulator';

  @override
  TransportType get type => TransportType.simulator;

  @override
  bool get isConnected => true;

  @override
  Stream<Bundle> get incomingBundles => _incomingController.stream;

  @override
  Future<void> initialize() async {
    _startSimulationLoop();
  }

  void _startSimulationLoop() {
    _simulationTimer?.cancel();
    _simulationTimer = Timer.periodic(const Duration(milliseconds: 1000), (_) {
      _tickSimulation();
    });
  }

  void _tickSimulation() {
    _tickCount++;
    final activeLinks = <SimLink>[];

    // 1. Calculate active spatial links between nodes
    for (int i = 0; i < nodes.length; i++) {
      for (int j = i + 1; j < nodes.length; j++) {
        final nodeA = nodes[i];
        final nodeB = nodes[j];
        if (nodeA.isInRange(nodeB)) {
          final dist = nodeA.distanceTo(nodeB);
          activeLinks.add(SimLink(nodeA.id, nodeB.id, dist));

          // Record mutual encounters in PRoPHET router
          nodeA.router.recordEncounter(nodeB.id);
          nodeB.router.recordEncounter(nodeA.id);
        }
      }
    }

    // 2. Perform summary vector handshakes & store-and-forward bundle propagation
    for (final link in activeLinks) {
      final nodeA = nodes.firstWhere((n) => n.id == link.nodeAId);
      final nodeB = nodes.firstWhere((n) => n.id == link.nodeBId);

      _exchangeBundlesBetweenNodes(nodeA, nodeB);
    }

    _nodeStateController.add(List.unmodifiable(nodes));
    _linkStateController.add(List.unmodifiable(activeLinks));
  }

  void _exchangeBundlesBetweenNodes(SimNode nodeA, SimNode nodeB) {
    // Node A -> Node B
    final vecB = nodeB.store.getSummaryVector();
    final missingInB = nodeA.store.getMissingBundleIds(vecB);
    final bundlesToSend = missingInB.map((id) => nodeA.store.getBundle(id)).whereType<Bundle>().toList();

    final prioritized = nodeA.router.prioritizeBundlesForForwarding(bundlesToSend, nodeB.id, nodeB.isGateway);
    for (final b in prioritized) {
      final hopped = b.incrementHop();
      if (nodeB.store.storeBundle(hopped)) {
        if (nodeB.id == 'node_a') {
          _incomingController.add(hopped);
        }
      }
    }

    // Node B -> Node A
    final vecA = nodeA.store.getSummaryVector();
    final missingInA = nodeB.store.getMissingBundleIds(vecA);
    final bundlesFromB = missingInA.map((id) => nodeB.store.getBundle(id)).whereType<Bundle>().toList();

    final prioritizedFromB = nodeB.router.prioritizeBundlesForForwarding(bundlesFromB, nodeA.id, nodeA.isGateway);
    for (final b in prioritizedFromB) {
      final hopped = b.incrementHop();
      if (nodeA.store.storeBundle(hopped)) {
        if (nodeA.id == 'node_a') {
          _incomingController.add(hopped);
        }
      }
    }
  }

  /// Inject a bundle into a specific virtual node in simulator
  void injectSimulatedBundle(String fromNodeId, Bundle bundle) {
    final node = nodes.firstWhere((n) => n.id == fromNodeId, orElse: () => nodes.first);
    node.store.storeBundle(bundle);
    _tickSimulation();
  }

  /// Update position of a virtual node in the visual simulator graph
  void updateNodePosition(String nodeId, double newX, double newY) {
    final node = nodes.firstWhere((n) => n.id == nodeId);
    node.x = newX;
    node.y = newY;
    _tickSimulation();
  }

  /// Toggle online/offline status of a node to test network partitioning & store-and-forward delay
  void toggleNodeOnline(String nodeId) {
    final node = nodes.firstWhere((n) => n.id == nodeId);
    node.isOnline = !node.isOnline;
    _tickSimulation();
  }

  @override
  Future<bool> sendBundle(Bundle bundle, {String? targetPeerId}) async {
    injectSimulatedBundle('node_a', bundle);
    return true;
  }

  @override
  Future<void> startDiscovery() async {}

  @override
  Future<void> stopDiscovery() async {}

  @override
  Future<void> dispose() async {
    _simulationTimer?.cancel();
    await _nodeStateController.close();
    await _linkStateController.close();
    await _incomingController.close();
  }
}
