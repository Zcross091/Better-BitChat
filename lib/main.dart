import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'core/crypto/crypto_engine.dart';
import 'core/models/bundle.dart';
import 'core/models/media_payload.dart';
import 'core/routing/prophet_router.dart';
import 'core/storage/contact_store.dart';
import 'core/storage/persistent_bundle_store.dart';
import 'transports/ble_transport.dart';
import 'transports/lora_transport.dart';
import 'transports/nostr_gateway_transport.dart';
import 'transports/simulator_transport.dart';
import 'transports/sneakernet_transport.dart';
import 'transports/transport_manager.dart';
import 'transports/usb_serial_lora_transport.dart';
import 'transports/wifi_direct_transport.dart';
import 'ui/screens/contacts_directory_screen.dart';
import 'ui/screens/conversations_list_screen.dart';
import 'ui/screens/mesh_simulator_screen.dart';
import 'ui/screens/network_screen.dart';
import 'ui/screens/profile_settings_screen.dart';
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
  final ContactStore _contactStore = ContactStore();
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

  @override
  void initState() {
    super.initState();
    _initAppServices();
  }

  Future<void> _initAppServices() async {
    // 1. Generate local Ed25519 identity keypair
    _myKeyPair = await CryptoEngine.generateKeyPair();

    // 2. Hydrate persistent encrypted storage and contact store from device
    await _bundleStore.hydrate();
    await _contactStore.hydrate(_myKeyPair?.publicKeyHex ?? 'pub_alice_ed25519_01');

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
        setState(() {});
      }
    });

    setState(() {});
  }

  void _handleBroadcastBundle(Bundle bundle) async {
    _bundleStore.storeBundle(bundle);
    _prophetRouter.recordEncounter(bundle.destPubkey);
    await _transportManager.broadcastBundle(bundle);
    setState(() {});
  }

  void _handleImportSneakernetQr(String rawPayload) {
    try {
      _sneakernetTransport.injectScannedQrBundle(rawPayload);
    } catch (_) {}
  }

  void _handlePanicWipe() async {
    await _bundleStore.clearAll();
    await _contactStore.clearAll();
    _prophetRouter.reset();
    _myKeyPair = await CryptoEngine.generateKeyPair();
    await _contactStore.hydrate(_myKeyPair!.publicKeyHex);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      ConversationsListScreen(
        contactStore: _contactStore,
        onBroadcastBundle: _handleBroadcastBundle,
      ),
      ContactsDirectoryScreen(
        contactStore: _contactStore,
        transportManager: _transportManager,
        onBroadcastBundle: _handleBroadcastBundle,
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
          setState(() {});
        },
      ),
      ProfileSettingsScreen(
        contactStore: _contactStore,
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
            label: 'Chats',
          ),
          NavigationDestination(
            icon: Icon(LucideIcons.users),
            selectedIcon: Icon(LucideIcons.users, color: AppTheme.primary),
            label: 'Contacts',
          ),
          NavigationDestination(
            icon: Icon(LucideIcons.network),
            selectedIcon: Icon(LucideIcons.network, color: AppTheme.primary),
            label: 'Radios',
          ),
          NavigationDestination(
            icon: Icon(LucideIcons.activity),
            selectedIcon: Icon(LucideIcons.activity, color: AppTheme.primary),
            label: 'Mesh Sim',
          ),
          NavigationDestination(
            icon: Icon(LucideIcons.shield),
            selectedIcon: Icon(LucideIcons.shield, color: AppTheme.primary),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
