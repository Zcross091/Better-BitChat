import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../transports/transport_manager.dart';
import '../../core/storage/bundle_store.dart';
import '../../core/routing/prophet_router.dart';
import '../theme/app_theme.dart';

class NetworkScreen extends StatelessWidget {
  final TransportManager transportManager;
  final BundleStore bundleStore;
  final ProphetRouter prophetRouter;

  const NetworkScreen({
    super.key,
    required this.transportManager,
    required this.bundleStore,
    required this.prophetRouter,
  });

  @override
  Widget build(BuildContext context) {
    final predictabilityMap = prophetRouter.getPredictabilityMap();

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(LucideIcons.activity, color: AppTheme.primary),
            SizedBox(width: 10),
            Text('Network & Transport Dashboard'),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Live Stats Overview Row
          Row(
            children: [
              Expanded(
                child: _buildMetricCard(
                  title: 'Bundles Stored',
                  value: '${bundleStore.count}',
                  subtext: 'Max: ${bundleStore.maxCapacity}',
                  icon: LucideIcons.box,
                  color: AppTheme.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMetricCard(
                  title: 'Seen Deduplication',
                  value: '${bundleStore.seenCount}',
                  subtext: 'Seen Set Cache',
                  icon: LucideIcons.copyCheck,
                  color: AppTheme.secondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Active Transport Drivers Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(LucideIcons.radio, color: AppTheme.primary),
                      SizedBox(width: 8),
                      Text('Active Transport Drivers', style: TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildDriverTile('BLE Mesh Radio Driver', 'Local 10-100m peer hop', true, LucideIcons.bluetooth),
                  const Divider(color: AppTheme.border),
                  _buildDriverTile('Nostr WebSocket Gateway', 'Internet backhaul sync', true, LucideIcons.globe),
                  const Divider(color: AppTheme.border),
                  _buildDriverTile('Sneakernet QR / File Driver', 'Offline QR & file transfers', true, LucideIcons.qrCode),
                  const Divider(color: AppTheme.border),
                  _buildDriverTile('In-App Mesh Simulator', 'Interactive visual topology test', true, LucideIcons.network),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // PRoPHET Encounter History Predictability Matrix
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(LucideIcons.barChart2, color: AppTheme.warning),
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
                  if (predictabilityMap.isEmpty)
                    const Text('No peer encounters recorded yet in current session.', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary))
                  else
                    ...predictabilityMap.entries.map((entry) {
                      final scorePercent = (entry.value * 100).toStringAsFixed(1);
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: Text(entry.key, style: const TextStyle(fontSize: 12, fontFamily: 'FiraCode', color: AppTheme.textPrimary)),
                            ),
                            Expanded(
                              flex: 3,
                              child: LinearProgressIndicator(
                                value: entry.value,
                                backgroundColor: AppTheme.background,
                                color: AppTheme.primary,
                                minHeight: 8,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text('$scorePercent%', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.primary)),
                          ],
                        ),
                      );
                    }),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required String subtext,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
              Icon(icon, size: 18, color: color),
            ],
          ),
          const SizedBox(height: 10),
          Text(value, style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 4),
          Text(subtext, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
        ],
      ),
    );
  }

  Widget _buildDriverTile(String title, String subtitle, bool isActive, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 20, color: isActive ? AppTheme.primary : AppTheme.textSecondary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                Text(subtitle, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppTheme.success.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.success),
            ),
            child: const Text('ACTIVE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.success)),
          ),
        ],
      ),
    );
  }
}
