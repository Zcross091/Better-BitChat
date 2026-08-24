import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../core/crypto/crypto_engine.dart';
import '../../core/crypto/group_sender_key.dart';
import '../theme/app_theme.dart';
import '../widgets/animated_qr_dialog.dart';

class IdentityScreen extends StatefulWidget {
  final CryptoKeyPair? keyPair;
  final Function(String rawPayload) onImportSneakernetQr;
  final VoidCallback onEmergencyPanicWipe;

  const IdentityScreen({
    super.key,
    required this.keyPair,
    required this.onImportSneakernetQr,
    required this.onEmergencyPanicWipe,
  });

  @override
  State<IdentityScreen> createState() => _IdentityScreenState();
}

class _IdentityScreenState extends State<IdentityScreen> {
  final TextEditingController _importController = TextEditingController();
  late final GroupSenderKeyState _rescueGroupSenderKey;

  @override
  void initState() {
    super.initState();
    final pubKey = widget.keyPair?.publicKeyHex ?? 'pub_alice_ed25519_01';
    _rescueGroupSenderKey = GroupSenderKeyEngine.createMySenderKey('group_rescue_01', pubKey);
  }

  @override
  Widget build(BuildContext context) {
    final pubKey = widget.keyPair?.publicKeyHex ?? 'Generating...';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Identity & Air-Gap Tools'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Public Key Card with QR code
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  const Text(
                    'Your Ed25519 Node Identity',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.primary),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Peers use this public key to encrypt bundles addressed to you:',
                    style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),

                  // Static PubKey QR Code
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: QrImageView(
                      data: 'mesh:pubkey:$pubKey',
                      version: QrVersions.auto,
                      size: 160.0,
                      gapless: true,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // PubKey Text and Copy Button
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.background,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.border),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            pubKey,
                            style: const TextStyle(fontSize: 11, fontFamily: 'FiraCode', color: AppTheme.textPrimary),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(LucideIcons.copy, size: 16, color: AppTheme.primary),
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: pubKey));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Public key copied to clipboard!')),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Group Sender Keys (Signal-style $O(1)$ group encryption) Card
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
                          Icon(LucideIcons.users, color: AppTheme.primary),
                          SizedBox(width: 8),
                          Text('Group Encryption Sender Keys', style: TextStyle(fontWeight: FontWeight.bold)),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.success.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text('RATCHET ACTIVE', style: TextStyle(fontSize: 9, color: AppTheme.success, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Allows $O(1)$ multi-party group broadcasting with forward secrecy. When sending to #rescue-team, all members decrypt with their shared ratchet state:',
                    style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.background,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.border),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Group: ${_rescueGroupSenderKey.groupId}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        Text('Ratchet Step: #${_rescueGroupSenderKey.iteration}', style: const TextStyle(fontSize: 12, fontFamily: 'FiraCode', color: AppTheme.primary)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Air-Gap Animated Fountain QR Sneakernet Stream Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(LucideIcons.radio, color: AppTheme.secondary),
                      SizedBox(width: 8),
                      Text('Optical Air-Gap Fountain QR Stream', style: TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Stream multi-kilobyte encrypted bundles screen-to-camera using rapid cycling fountain QR droplets (for total radio blackout air-gaps):',
                    style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.black,
                    ),
                    icon: const Icon(LucideIcons.play, size: 16),
                    label: const Text('Broadcast Stored Bundles via Fountain QR'),
                    onPressed: () {
                      final samplePayload = jsonEncode({
                        'bundle_id': 'dtn_airgap_stream_sample_01',
                        'sender': pubKey,
                        'dest': 'all',
                        'data': 'AIR_GAP_DTN_PAYLOAD_CHUNK_FOUNTAIN_STREAMING_DATA_RECOVERY_PROTOCOL',
                      });

                      showDialog(
                        context: context,
                        builder: (context) => AnimatedQrBroadcastDialog(
                          payload: samplePayload,
                          title: 'Air-Gap Fountain QR Stream',
                        ),
                      );
                    },
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(LucideIcons.qrCode, color: AppTheme.secondary),
                      SizedBox(width: 8),
                      Text('Manual Bundle Import / Ingestion', style: TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Paste raw bundle JSON or fountain droplet payload to inject into local DTN store:',
                    style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _importController,
                    maxLines: 3,
                    style: const TextStyle(fontSize: 12, fontFamily: 'FiraCode', color: AppTheme.textPrimary),
                    decoration: InputDecoration(
                      hintText: 'Paste {"bundle_id": "...", "payload": "..."} or FQ:1:...',
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
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Emergency Panic Wipe', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.error)),
                        Text('Instantly purge all keys, stored bundles & contacts', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                      ],
                    ),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error, foregroundColor: Colors.white),
                    onPressed: () {
                      _showPanicConfirmationDialog();
                    },
                    child: const Text('PURGE'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showPanicConfirmationDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text('Confirm Emergency Panic Wipe', style: TextStyle(color: AppTheme.error)),
        content: const Text(
          'This action is irreversible. All cryptographic keypairs, message history, cached bundles, and contact predictability data will be permanently overwritten.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error, foregroundColor: Colors.white),
            onPressed: () {
              Navigator.pop(context);
              widget.onEmergencyPanicWipe();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Panic wipe executed. Node memory sanitized.')),
              );
            },
            child: const Text('WIPE EVERYTHING'),
          ),
        ],
      ),
    );
  }
}
