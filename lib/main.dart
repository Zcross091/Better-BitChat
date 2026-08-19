import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'core/crypto/crypto_engine.dart';
import 'core/models/bundle.dart';
import 'core/routing/prophet_router.dart';
import 'core/storage/bundle_store.dart';
import 'transports/ble_transport.dart';
import 'transports/nostr_gateway_transport.dart';
import 'transports/simulator_transport.dart';
import 'transports/sneakernet_transport.dart';
import 'transports/transport_manager.dart';
import 'ui/screens/chat_screen.dart';
import 'ui/screens/identity_screen.dart';
import 'ui/screens/mesh_simulator_screen.dart';
import 'ui/screens/network_screen.dart';
import 'ui/theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MeshMessengerApp());
}

class MeshMessengerApp extends StatelessWidget {
  const MeshMessengerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mesh Messenger',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: const MainNavigationShell(),
    );
  }
}

class MainNavigationShell extends StatefulWidget {
  const MainNavigationShell({super.key});

  @override
  State<MainNavigationShell> createState() => _MainNavigationShellState();
}

class _MainNavigationShellState extends State<MainNavigationShell> {
  int _currentIndex = 0;

  final BundleStore _bundleStore = BundleStore(maxCapacity: 500);
  final ProphetRouter _prophetRouter = ProphetRouter();
  final TransportManager _transportManager = TransportManager();

  late final BleTransport _bleTransport;
  late final NostrGatewayTransport _nostrTransport;
  late final SneakernetTransport _sneakernetTransport;
  late final SimulatorTransport _simulatorTransport;

  CryptoKeyPair? _myKeyPair;
  List<Bundle> _bundlesList = [];

  @override
  void initState() {
    super.initState();
    _initAppServices();
  }

  Future<void> _initAppServices() async {
    // 1. Generate local Ed25519 identity keypair
    _myKeyPair = await CryptoEngine.generateKeyPair();

    // 2. Initialize transport drivers
    _bleTransport = BleTransport();
    _nostrTransport = NostrGatewayTransport();
    _sneakernetTransport = SneakernetTransport();
    _simulatorTransport = SimulatorTransport();

    _transportManager.registerDriver(_bleTransport);
    _transportManager.registerDriver(_nostrTransport);
    _transportManager.registerDriver(_sneakernetTransport);
    _transportManager.registerDriver(_simulatorTransport);

    await _transportManager.initializeAll();

    // 3. Listen to incoming bundles across all transports
    _transportManager.onBundleReceived.listen((bundle) {
      if (_bundleStore.storeBundle(bundle)) {
        setState(() {
          _bundlesList = _bundleStore.getAllBundles();
        });
      }
    });

    // 4. Seed initial welcome DTN bundle in store
    final initialBundle = Bundle(
      bundleId: Bundle.generateBundleId(
        senderPubkey: 'pub_dave_gtw_04',
        destPubkey: 'all',
        createdAt: DateTime.now().millisecondsSinceEpoch,
        nonce: 'seed_nonce_01',
      ),
      senderPubkey: 'pub_dave_gtw_04',
      destPubkey: 'all',
      createdAt: DateTime.now().millisecondsSinceEpoch,
      ttlHours: 48,
      hopCount: 2,
      priority: BundlePriority.normal,
      payload: 'Welcome to Mesh Messenger DTN! Messages are stored, carried & forwarded across BLE, Nostr, and Sneakernet.',
      signature: 'sig_welcome_ed25519',
    );
    _bundleStore.storeBundle(initialBundle);

    setState(() {
      _bundlesList = _bundleStore.getAllBundles();
    });
  }

  void _handleSendMessage(String text, BundlePriority priority) {
    if (_myKeyPair == null) return;

    final bundle = Bundle(
      bundleId: Bundle.generateBundleId(
        senderPubkey: _myKeyPair!.publicKeyHex,
        destPubkey: 'pub_eve_ed25519_05',
        createdAt: DateTime.now().millisecondsSinceEpoch,
        nonce: UniqueKey().toString(),
      ),
      senderPubkey: _myKeyPair!.publicKeyHex,
      destPubkey: 'pub_eve_ed25519_05',
      createdAt: DateTime.now().millisecondsSinceEpoch,
      ttlHours: 24,
      hopCount: 0,
      priority: priority,
      payload: text,
      signature: 'sig_ed25519_${_myKeyPair!.publicKeyHex.substring(0, 8)}',
    );

    _bundleStore.storeBundle(bundle);
    _transportManager.broadcastBundle(bundle);

    setState(() {
      _bundlesList = _bundleStore.getAllBundles();
    });
  }

  void _handleImportSneakernetQr(String rawPayload) {
    if (_sneakernetTransport.importScannedQrPayload(rawPayload)) {
      setState(() {
        _bundlesList = _bundleStore.getAllBundles();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_myKeyPair == null) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: AppTheme.primary),
              SizedBox(height: 16),
              Text('Generating Ed25519 Identity Keypair...'),
            ],
          ),
        ),
      );
    }

    final screens = [
      ChatScreen(
        storedBundles: _bundlesList,
        onSendMessage: _handleSendMessage,
      ),
      MeshSimulatorScreen(
        simulator: _simulatorTransport,
        onSendSimulatedBundle: (bundle) {
          _bundleStore.storeBundle(bundle);
          setState(() {
            _bundlesList = _bundleStore.getAllBundles();
          });
        },
      ),
      IdentityScreen(
        publicKeyHex: _myKeyPair!.publicKeyHex,
        storedBundles: _bundlesList,
        onImportSneakernetQr: _handleImportSneakernetQr,
      ),
      NetworkScreen(
        transportManager: _transportManager,
        bundleStore: _bundleStore,
        prophetRouter: _prophetRouter,
      ),
    ];

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(LucideIcons.messageSquare),
            label: 'Chat',
          ),
          BottomNavigationBarItem(
            icon: Icon(LucideIcons.network),
            label: 'Simulator',
          ),
          BottomNavigationBarItem(
            icon: Icon(LucideIcons.key),
            label: 'Identity & QR',
          ),
          BottomNavigationBarItem(
            icon: Icon(LucideIcons.activity),
            label: 'Network',
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _transportManager.dispose();
    super.dispose();
  }
}
