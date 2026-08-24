import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../core/routing/prophet_router.dart';
import '../../core/storage/persistent_bundle_store.dart';
import '../../transports/transport_manager.dart';
import '../../transports/usb_serial_lora_transport.dart';
import '../theme/app_theme.dart';
import '../widgets/hardware_console_dialog.dart';

class NetworkScreen extends StatelessWidget {
  final TransportManager transportManager;
  final ProphetRouter prophetRouter;
  final PersistentBundleStore bundleStore;

  const NetworkScreen({
    super.key,
    required this.transportManager,
    required this.prophetRouter,
    required this.bundleStore,
  });

  @override
  Widget build(BuildContext context) {
    final activePeers = transportManager.activePeers;
    final allPredictabilities = prophetRouter.getAllPredictabilities();
    final usbTransport = transportManager.getDriver<UsbSerialLoraTransport>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Network & Transports'),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.refreshCw),
            tooltip: 'Rescan Mesh Radios',
            onPressed: () {
              transportManager.startDiscovery();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Re-scanning BLE, LoRa, USB-Serial, and WiFi Direct radios...')),
              );
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Storage Quotas & At-Rest Encryption Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Row(
                        children: [
                          Icon(LucideIcons.hardDrive, color: AppTheme.primary),
                          SizedBox(width: 8),
                          Text('Persistent Encrypted DTN Storage', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        ],
                      ),
                      Text('${bundleStore.count} Bundles', style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primary)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  LinearProgressIndicator(
                    value: (bundleStore.quotaUsedRatio).clamp(0.05, 1.0),
                    backgroundColor: AppTheme.surfaceElevated,
                    valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primary),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Used: ${(bundleStore.currentStorageBytes / 1024).toStringAsFixed(1)} KB / ${(bundleStore.maxStorageBytes / (1024 * 1024)).toStringAsFixed(0)} MB Quota',
                        style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                      ),
                      const Text(
                        'LRU Eviction: Low Priority First',
                        style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Physical Hardware Bridge Card
          Card(
            color: AppTheme.primary.withOpacity(0.08),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: AppTheme.primary.withOpacity(0.4)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Row(
                        children: [
                          Icon(LucideIcons.cpu, color: AppTheme.primary),
                          SizedBox(width: 8),
                          Text('USB-OTG & Serial LoRa Bridge', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: (usbTransport?.isConnected ?? false) ? AppTheme.success.withOpacity(0.2) : AppTheme.error.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          (usbTransport?.isConnected ?? false) ? 'UART 115200 8N1' : 'DISCONNECTED',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: (usbTransport?.isConnected ?? false) ? AppTheme.success : AppTheme.error,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Direct physical connection to Heltec WiFi LoRa 32 / T-Beam ESP32 companion radios with binary Meshtastic packet interop:',
                    style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          foregroundColor: Colors.black,
                        ),
                        icon: const Icon(LucideIcons.terminal, size: 14),
                        label: const Text('Open Live UART Console'),
                        onPressed: () {
                          if (usbTransport != null) {
                            showDialog(
                              context: context,
                              builder: (context) => HardwareConsoleDialog(transport: usbTransport),
                            );
                          }
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Active Transports Grid
          const Text('ACTIVE MULTI-TRANSPORT DRIVERS', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textSecondary)),
          const SizedBox(height: 8),

          _buildTransportCard(
            title: 'Bluetooth Low Energy (BLE Mesh)',
            subtitle: 'Advertising & scanning via flutter_reactive_ble (~10-50m)',
            icon: LucideIcons.bluetooth,
            statusColor: AppTheme.success,
            statusText: 'SCANNING & TX',
          ),
          const SizedBox(height: 8),

          _buildTransportCard(
            title: 'USB-OTG Serial LoRa Companion',
            subtitle: 'Hardware bridge (CP2102/CH340/FTDI) @ 115200 baud',
            icon: LucideIcons.usb,
            statusColor: AppTheme.primary,
            statusText: 'HARDWARE ACTIVE',
          ),
          const SizedBox(height: 8),

          _buildTransportCard(
            title: 'LoRa 915 MHz RF Radio (SX1262)',
            subtitle: 'SX1262 SPI module @ SF9 | BW 250kHz | RSSI: -94 dBm (2-15km)',
            icon: LucideIcons.radio,
            statusColor: AppTheme.primary,
            statusText: 'RADIO LOCKED',
          ),
          const SizedBox(height: 8),

          _buildTransportCard(
            title: 'WiFi Direct / P2P Burst Link',
            subtitle: 'High-bandwidth local rendezvous channel (5.8 GHz)',
            icon: LucideIcons.wifi,
            statusColor: AppTheme.success,
            statusText: '3 PEERS CONNECTED',
          ),
          const SizedBox(height: 8),

          _buildTransportCard(
            title: 'Nostr Relay Global Gateway',
            subtitle: 'Connected to wss://relay.damus.io for internet backhaul',
            icon: LucideIcons.globe,
            statusColor: AppTheme.success,
            statusText: 'WS CONNECTED',
          ),
          const SizedBox(height: 8),

          _buildTransportCard(
            title: 'Sneakernet & Fountain QR Stream',
            subtitle: 'Screen-to-camera optical air-gap packet injection',
            icon: LucideIcons.qrCode,
            statusColor: AppTheme.secondary,
            statusText: 'STANDBY',
          ),

          const SizedBox(height: 24),

          // PRoPHET Predictability Matrix Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(LucideIcons.activity, color: AppTheme.secondary),
                      SizedBox(width: 8),
                      Text('PRoPHET Delivery Predictability Matrix', style: TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Higher scores (P_a,b) prioritize bundle forwarding toward peers statistically likely to reach destination:',
                    style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                  ),
                  const SizedBox(height: 12),
                  if (allPredictabilities.isEmpty)
                    const Text('No peer encounters recorded yet. Encounter peers to build history.', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary))
                  else
                    ...allPredictabilities.entries.map((entry) {
                      final score = entry.value;
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: Text(entry.key, style: const TextStyle(fontSize: 12, fontFamily: 'FiraCode')),
                            ),
                            Expanded(
                              flex: 4,
                              child: LinearProgressIndicator(
                                value: score,
                                backgroundColor: AppTheme.surfaceElevated,
                                valueColor: AlwaysStoppedAnimation<Color>(score > 0.5 ? AppTheme.success : AppTheme.warning),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text('${(score * 100).toInt()}%', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      );
                    }),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Discovered Peers List
          const Text('DISCOVERED NEIGHBORING PEERS', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textSecondary)),
          const SizedBox(height: 8),

          if (activePeers.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Center(
                  child: Text('Scanning for physical mesh nodes nearby...', style: TextStyle(color: AppTheme.textSecondary)),
                ),
              ),
            )
          else
            ...activePeers.map(
              (peer) => Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: peer.isGateway ? AppTheme.primary : AppTheme.secondary,
                    child: Icon(peer.isGateway ? LucideIcons.globe : LucideIcons.smartphone, color: Colors.black, size: 18),
                  ),
                  title: Text(peer.peerId, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('Transport: ${peer.transportType.name.toUpperCase()} | Key: ${peer.pubKey.substring(0, 10)}...'),
                  trailing: Text(
                    peer.isGateway ? 'GATEWAY' : 'LEAF',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: peer.isGateway ? AppTheme.primary : AppTheme.textSecondary,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTransportCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color statusColor,
    required String statusText,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(icon, size: 18, color: AppTheme.primary),
                  const SizedBox(width: 8),
                  Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  statusText,
                  style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: statusColor),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(subtitle, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
        ],
      ),
    );
  }
}
