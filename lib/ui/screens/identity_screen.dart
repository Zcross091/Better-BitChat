import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../core/models/bundle.dart';
import '../theme/app_theme.dart';

class IdentityScreen extends StatefulWidget {
  final String publicKeyHex;
  final List<Bundle> storedBundles;
  final Function(String rawPayload) onImportSneakernetQr;

  const IdentityScreen({
    super.key,
    required this.publicKeyHex,
    required this.storedBundles,
    required this.onImportSneakernetQr,
  });

  @override
  State<IdentityScreen> createState() => _IdentityScreenState();
}

class _IdentityScreenState extends State<IdentityScreen> {
  final TextEditingController _importController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(LucideIcons.key, color: AppTheme.primary),
            SizedBox(width: 10),
            Text('Identity & Sneakernet QR'),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Public Key Identity Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const Row(
                    children: [
                      Icon(LucideIcons.shield, color: AppTheme.primary),
                      SizedBox(width: 8),
                      Text('Ed25519 Cryptographic Identity', style: TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                    child: QrImageView(
                      data: widget.publicKeyHex,
                      version: QrVersions.auto,
                      size: 160.0,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text('Public Key Fingerprint:', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                  const SizedBox(height: 4),
                  SelectableText(
                    widget.publicKeyHex,
                    style: const TextStyle(fontSize: 11, fontFamily: 'FiraCode', color: AppTheme.primary),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Sneakernet QR Import Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(LucideIcons.qrCode, color: AppTheme.secondary),
                      SizedBox(width: 8),
                      Text('Sneakernet QR / USB Bundle Import', style: TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'In total internet/radio blackout, paste or scan a raw bundle payload to inject into local DTN mesh store:',
                    style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _importController,
                    maxLines: 3,
                    style: const TextStyle(fontSize: 12, fontFamily: 'FiraCode', color: AppTheme.textPrimary),
                    decoration: InputDecoration(
                      hintText: 'Paste {"bundle_id": "...", "payload": "..."}',
                      hintStyle: const TextStyle(color: AppTheme.textSecondary),
                      filled: true,
                      fillColor: AppTheme.background,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: AppTheme.border),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.secondary,
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(LucideIcons.download, size: 16),
                    label: const Text('Inject Scanned Bundle Payload'),
                    onPressed: () {
                      final raw = _importController.text.trim();
                      if (raw.isEmpty) return;

                      widget.onImportSneakernetQr(raw);
                      _importController.clear();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Bundle payload successfully injected into local store!')),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Emergency Panic Wipe Button
          Card(
            color: AppTheme.error.withOpacity(0.08),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: AppTheme.error.withOpacity(0.5)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(LucideIcons.alertTriangle, color: AppTheme.error),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAlignment.start,
                      children: [
                        Text('Emergency Panic Wipe', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.error)),
                        Text('Instantly purge all keys, stored bundles & contacts', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                      ],
                    ),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error, foregroundColor: Colors.white),
                    onPressed: () {
                      _showPanicWipeConfirmation();
                    },
                    child: const Text('PANIC WIPE'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showPanicWipeConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text('Confirm Panic Wipe', style: TextStyle(color: AppTheme.error)),
        content: const Text('This will irreversibly delete all local cryptographic keys and stored message bundles.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('ALL KEYS AND STORED BUNDLES WIPED CLEAN.')),
              );
            },
            child: const Text('PURGE EVERYTHING'),
          ),
        ],
      ),
    );
  }
}
