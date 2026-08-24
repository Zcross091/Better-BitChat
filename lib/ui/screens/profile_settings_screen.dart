import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../core/crypto/crypto_engine.dart';
import '../../core/models/user_profile.dart';
import '../../core/storage/contact_store.dart';
import '../theme/app_theme.dart';

class ProfileSettingsScreen extends StatefulWidget {
  final ContactStore contactStore;
  final CryptoKeyPair? keyPair;
  final Function(String) onImportSneakernetQr;
  final VoidCallback onEmergencyPanicWipe;

  const ProfileSettingsScreen({
    super.key,
    required this.contactStore,
    required this.keyPair,
    required this.onImportSneakernetQr,
    required this.onEmergencyPanicWipe,
  });

  @override
  State<ProfileSettingsScreen> createState() => _ProfileSettingsScreenState();
}

class _ProfileSettingsScreenState extends State<ProfileSettingsScreen> {
  late TextEditingController _displayNameController;
  late TextEditingController _usernameController;
  late TextEditingController _bioController;
  late TextEditingController _nip05Controller;
  late int _selectedAvatarSeed;

  @override
  void initState() {
    super.initState();
    final p = widget.contactStore.myProfile;
    _displayNameController = TextEditingController(text: p.displayName);
    _usernameController = TextEditingController(text: p.username);
    _bioController = TextEditingController(text: p.bio);
    _nip05Controller = TextEditingController(text: p.nip05Handle);
    _selectedAvatarSeed = p.avatarSeed;
  }

  void _saveProfile() {
    final updated = widget.contactStore.myProfile.copyWith(
      displayName: _displayNameController.text.trim(),
      username: _usernameController.text.trim().replaceAll('@', ''),
      bio: _bioController.text.trim(),
      nip05Handle: _nip05Controller.text.trim(),
      avatarSeed: _selectedAvatarSeed,
    );

    widget.contactStore.saveProfile(updated);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('✅ Profile updated and broadcasted across mesh!')),
    );
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final profile = widget.contactStore.myProfile;
    final pubKey = widget.keyPair?.publicKeyHex ?? profile.pubKeyHex;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile & Identity'),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.save, color: AppTheme.primary),
            tooltip: 'Save Profile',
            onPressed: _saveProfile,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Profile Header Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Stack(
                    children: [
                      CircleAvatar(
                        radius: 40,
                        backgroundColor: _getSeedColor(_selectedAvatarSeed),
                        child: Text(
                          profile.displayName.isNotEmpty ? profile.displayName.substring(0, 1).toUpperCase() : 'A',
                          style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.black),
                        ),
                      ),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: CircleAvatar(
                          radius: 12,
                          backgroundColor: AppTheme.primary,
                          child: const Icon(LucideIcons.check, size: 14, color: Colors.black),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(profile.displayName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 2),
                  Text(profile.handle, style: const TextStyle(fontSize: 13, color: AppTheme.primary, fontWeight: FontWeight.w600)),
                  if (profile.nip05Handle.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.secondary.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'NIP-05: ${profile.nip05Handle}',
                          style: const TextStyle(fontSize: 10, color: AppTheme.secondary, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Edit Profile Details Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('CUSTOMIZE CIVILIAN HANDLE & BIO', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textSecondary)),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _displayNameController,
                    decoration: const InputDecoration(labelText: 'Display Name', prefixIcon: Icon(LucideIcons.user, size: 18), filled: true),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _usernameController,
                    decoration: const InputDecoration(labelText: 'Unique Username', prefixText: '@', prefixIcon: Icon(LucideIcons.atSign, size: 18), filled: true),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _bioController,
                    decoration: const InputDecoration(labelText: 'Bio / Status', prefixIcon: Icon(LucideIcons.info, size: 18), filled: true),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _nip05Controller,
                    decoration: const InputDecoration(labelText: 'Nostr NIP-05 Handle (Optional)', hintText: 'e.g. user@mesh.nostr', prefixIcon: Icon(LucideIcons.globe, size: 18), filled: true),
                  ),
                  const SizedBox(height: 14),

                  // Avatar Color Seed Selector
                  const Text('Avatar Color Theme:', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: List.generate(8, (i) {
                        final seed = i + 1;
                        final isSelected = _selectedAvatarSeed == seed;
                        return GestureDetector(
                          onTap: () => setState(() => _selectedAvatarSeed = seed),
                          child: Container(
                            margin: const EdgeInsets.only(right: 8),
                            padding: const EdgeInsets.all(3),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: isSelected ? AppTheme.primary : Colors.transparent, width: 2),
                            ),
                            child: CircleAvatar(
                              radius: 14,
                              backgroundColor: _getSeedColor(seed),
                              child: Text('$seed', style: const TextStyle(color: Colors.black, fontSize: 10, fontWeight: FontWeight.bold)),
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                  const SizedBox(height: 16),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary, foregroundColor: Colors.black),
                      icon: const Icon(LucideIcons.save, size: 16),
                      label: const Text('Save Profile Changes'),
                      onPressed: _saveProfile,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Share Identity QR Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const Row(
                    children: [
                      Icon(LucideIcons.qrCode, color: AppTheme.primary),
                      SizedBox(width: 8),
                      Text('Share Your Contact QR', style: TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: QrImageView(
                      data: 'mesh:contact:${profile.username}:$pubKey',
                      version: QrVersions.auto,
                      size: 160.0,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text('Public Key: ${pubKey.substring(0, 16)}...', style: const TextStyle(fontSize: 11, fontFamily: 'FiraCode', color: AppTheme.textSecondary)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Security & Anti-Forensic Panic Wipe Card
          Card(
            color: AppTheme.error.withOpacity(0.08),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: AppTheme.error.withOpacity(0.4)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(LucideIcons.alertTriangle, color: AppTheme.error),
                      SizedBox(width: 8),
                      Text('Anti-Forensic Security & Panic Wipe', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.error)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Irreversibly sanitizes all stored private keys, address book contacts, group ratchets, and cached DTN bundles from flash memory:',
                    style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error, foregroundColor: Colors.white),
                    icon: const Icon(LucideIcons.flame, size: 16),
                    label: const Text('Emergency Panic Wipe (Sanitize Device)'),
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          backgroundColor: AppTheme.surface,
                          title: const Text('Confirm Emergency Wipe'),
                          content: const Text('Are you sure? This will wipe all keys, contacts, and messages instantly.'),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
                              onPressed: () {
                                widget.contactStore.clearAll();
                                widget.onEmergencyPanicWipe();
                                Navigator.pop(context);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('🔥 Memory wiped and new cryptographic keys generated.')),
                                );
                              },
                              child: const Text('WIPE ALL DATA'),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getSeedColor(int seed) {
    final colors = [
      AppTheme.primary,
      AppTheme.secondary,
      const Color(0xFFE57373),
      const Color(0xFF81C784),
      const Color(0xFFBA68C8),
      const Color(0xFFFFB74D),
      const Color(0xFF4DD0E1),
      const Color(0xFFAED581),
    ];
    return colors[(seed - 1).clamp(0, colors.length - 1)];
  }
}
