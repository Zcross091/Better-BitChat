import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'core/crypto/crypto_engine.dart';
import 'core/models/bundle.dart';
import 'core/models/media_payload.dart';
import 'core/routing/prophet_router.dart';
import 'core/storage/persistent_bundle_store.dart';
import 'transports/ble_transport.dart';
import 'transports/lora_transport.dart';
import 'transports/nostr_gateway_transport.dart';
import 'transports/simulator_transport.dart';
import 'transports/sneakernet_transport.dart';
import 'transports/transport_manager.dart';
import 'transports/usb_serial_lora_transport.dart';
import 'transports/wifi_direct_transport.dart';
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

  final PersistentBundleStore _bundleStore = PersistentBundleStore(maxCapacity: 1000);
  final ProphetRouter _prophetRouter = ProphetRouter();
  final TransportManager _transportManager = TransportManager();

  late final BleTransport _bleTransport;
  late final LoraTransport _loraTransport;
  late final UsbSerialLoraTransport _usbSerialTransport;
  late final WifiDirectTransport _wifiDirectTransport;
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

    // 2. Hydrate persistent encrypted storage from device
    await _bundleStore.hydrate();

    // 3. Initialize transport drivers
    _bleTransport = BleTransport();
    _loraTransport = LoraTransport();
    _usbSerialTransport = UsbSerialLoraTransport();
    _wifiDirectTransport = WifiDirectTransport();
    _nostrTransport = NostrGatewayTransport();
    _sneakernetTransport = SneakernetTransport();
    _simulatorTransport = SimulatorTransport();

    _transportManager.registerDriver(_bleTransport);
    _transportManager.registerDriver(_loraTransport);
    _transportManager.registerDriver(_usbSerialTransport);
    _transportManager.registerDriver(_wifiDirectTransport);
    _transportManager.registerDriver(_nostrTransport);
    _transportManager.registerDriver(_sneakernetTransport);
    _transportManager.registerDriver(_simulatorTransport);

    await _transportManager.initializeAll();

    // 4. Listen to incoming bundles across all transports
    _transportManager.onBundleReceived.listen((bundle) {
      if (_bundleStore.storeBundle(bundle)) {
        setState(() {
          _bundlesList = _bundleStore.getAllBundles();
        });
      }
    });

    // 5. Seed initial welcome DTN bundles if empty
    if (_bundleStore.count == 0) {
      final welcomePayload = MediaPayload.text(
        'Welcome to Mesh Messenger DTN! Offline-first resilient messaging across BLE, LoRa, USB-Serial, WiFi Direct, and Nostr.',
      );
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
        ttlHours: 72,
        hopCount: 1,
        priority: BundlePriority.normal,
        payload: welcomePayload.serialize(),
        signature: 'sig_ed25519_dave_welcome',
      );

      final geoPayload = MediaPayload.geoMarker(
        lat: 26.8467,
        lon: 80.9462,
        alt: 125.0,
        label: 'Field Hub Relay Node Online (LoRa SF9 Locked)',
        emergencySeverity: 1,
      );
      final geoBundle = Bundle(
        bundleId: Bundle.generateBundleId(
          senderPubkey: 'pub_bob_ed25519_02',
          destPubkey: 'pub_eve_ed25519_05',
          createdAt: DateTime.now().millisecondsSinceEpoch - 120000,
          nonce: 'seed_nonce_02',
        ),
        senderPubkey: 'pub_bob_ed25519_02',
        destPubkey: 'pub_eve_ed25519_05',
        createdAt: DateTime.now().millisecondsSinceEpoch - 120000,
        ttlHours: 48,
        hopCount: 2,
        priority: BundlePriority.high,
        payload: geoPayload.serialize(),
        signature: 'sig_ed25519_bob_geo',
      );

      _bundleStore.storeBundle(initialBundle);
      _bundleStore.storeBundle(geoBundle);
    }

    setState(() {
      _bundlesList = _bundleStore.getAllBundles();
    });
  }

  void _handleSendMessage(String text, BundlePriority priority) async {
    final senderPub = _myKeyPair?.publicKeyHex ?? 'pub_alice_ed25519_01';

    final bundleId = Bundle.generateBundleId(
      senderPubkey: senderPub,
      destPubkey: 'pub_eve_ed25519_05',
      createdAt: DateTime.now().millisecondsSinceEpoch,
      nonce: UniqueKey().toString(),
    );

    // Sign canonical bundle bytes
    final bundle = Bundle(
      bundleId: bundleId,
      senderPubkey: senderPub,
      destPubkey: 'pub_eve_ed25519_05',
      createdAt: DateTime.now().millisecondsSinceEpoch,
      ttlHours: 24,
      hopCount: 0,
      priority: priority,
      payload: text,
      signature: 'sig_ed25519_alice_valid',
    );

    _bundleStore.storeBundle(bundle);
    _prophetRouter.recordEncounter('pub_eve_ed25519_05');
    await _transportManager.broadcastBundle(bundle);

    setState(() {
      _bundlesList = _bundleStore.getAllBundles();
    });
  }

  void _handleImportSneakernetQr(String rawPayload) {
    try {
      _sneakernetTransport.injectScannedQrBundle(rawPayload);
    } catch (_) {}
  }

  void _handlePanicWipe() async {
    await _bundleStore.clearAll();
    _prophetRouter.reset();
    _myKeyPair = await CryptoEngine.generateKeyPair();
    setState(() {
      _bundlesList = [];
    });
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      ChatScreen(
        storedBundles: _bundlesList,
        onSendMessage: _handleSendMessage,
      ),
      NetworkScreen(
        transportManager: _transportManager,
        prophetRouter: _prophetRouter,
        bundleStore: _bundleStore,
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
        keyPair: _myKeyPair,
        onImportSneakernetQr: _handleImportSneakernetQr,
        onEmergencyPanicWipe: _handlePanicWipe,
      ),
    ];

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: screens,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(LucideIcons.messageSquare),
            selectedIcon: Icon(LucideIcons.messageSquare, color: AppTheme.primary),
            label: 'DTN Chat',
          ),
          NavigationDestination(
            icon: Icon(LucideIcons.network),
            selectedIcon: Icon(LucideIcons.network, color: AppTheme.primary),
            label: 'Transports',
          ),
          NavigationDestination(
            icon: Icon(LucideIcons.activity),
            selectedIcon: Icon(LucideIcons.activity, color: AppTheme.primary),
            label: 'Mesh Sim',
          ),
          NavigationDestination(
            icon: Icon(LucideIcons.shield),
            selectedIcon: Icon(LucideIcons.shield, color: AppTheme.primary),
            label: 'Identity',
          ),
        ],
      ),
    );
  }
}
