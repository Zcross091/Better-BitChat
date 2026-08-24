import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../core/models/bundle.dart';
import '../../core/models/contact.dart';
import '../../core/models/conversation.dart';
import '../../core/storage/contact_store.dart';
import '../../transports/transport_manager.dart';
import '../theme/app_theme.dart';
import 'civilian_chat_screen.dart';

class ContactsDirectoryScreen extends StatefulWidget {
  final ContactStore contactStore;
  final TransportManager transportManager;
  final Function(Bundle) onBroadcastBundle;

  const ContactsDirectoryScreen({
    super.key,
    required this.contactStore,
    required this.transportManager,
    required this.onBroadcastBundle,
  });

  @override
  State<ContactsDirectoryScreen> createState() => _ContactsDirectoryScreenState();
}

class _ContactsDirectoryScreenState extends State<ContactsDirectoryScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final contacts = widget.contactStore.searchContacts(_searchQuery);
    final activePeers = widget.transportManager.activePeers;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Contacts & Nearby Nodes'),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.userPlus, color: AppTheme.primary),
            tooltip: 'Add Contact',
            onPressed: _showAddContactModal,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          // Search Bar
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search by @handle, name, or public key...',
              prefixIcon: const Icon(LucideIcons.search, size: 18, color: AppTheme.textSecondary),
              filled: true,
              fillColor: AppTheme.surfaceElevated,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(LucideIcons.x, size: 16),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                    )
                  : null,
            ),
            onChanged: (val) => setState(() => _searchQuery = val),
          ),
          const SizedBox(height: 16),

          // Nearby Radio Nodes Section
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(LucideIcons.radar, color: AppTheme.primary, size: 16),
                  SizedBox(width: 6),
                  Text('NEARBY PHYSICAL MESH NODES', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textSecondary)),
                ],
              ),
              Text('${activePeers.length} Detected', style: const TextStyle(fontSize: 11, color: AppTheme.primary)),
            ],
          ),
          const SizedBox(height: 8),

          if (activePeers.isEmpty)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.border),
              ),
              child: const Row(
                children: [
                  Icon(LucideIcons.radio, color: AppTheme.textSecondary, size: 18),
                  SizedBox(width: 10),
                  Text('Scanning BLE, LoRa, & WiFi Direct radios nearby...', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                ],
              ),
            )
          else
            ...activePeers.map((peer) => _buildPeerTile(peer)),

          const SizedBox(height: 20),

          // Saved Contacts Address Book Section
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(LucideIcons.users, color: AppTheme.secondary, size: 16),
                  SizedBox(width: 6),
                  Text('SAVED ADDRESS BOOK', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textSecondary)),
                ],
              ),
              Text('${contacts.length} Contacts', style: const TextStyle(fontSize: 11, color: AppTheme.secondary)),
            ],
          ),
          const SizedBox(height: 8),

          if (contacts.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: Text('No contacts found matching search.', style: TextStyle(color: AppTheme.textSecondary))),
            )
          else
            ...contacts.map((contact) => _buildContactCard(contact)),
        ],
      ),
    );
  }

  Widget _buildPeerTile(PeerContact peer) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: peer.isGateway ? AppTheme.primary : AppTheme.secondary,
            child: Icon(peer.isGateway ? LucideIcons.globe : LucideIcons.smartphone, color: Colors.black, size: 16),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(peer.peerId, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                Text(
                  '${peer.transportType.name.toUpperCase()} • Key: ${peer.pubKey.substring(0, 10)}...',
                  style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                ),
              ],
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary.withOpacity(0.18),
              foregroundColor: AppTheme.primary,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              minimumSize: const Size(60, 30),
            ),
            onPressed: () => _startDmWithPeer(peer.peerId, peer.pubKey),
            child: const Text('DM', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildContactCard(Contact contact) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _getSeedColor(contact.avatarSeed),
          child: Text(
            contact.displayName.substring(0, 1).toUpperCase(),
            style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
          ),
        ),
        title: Row(
          children: [
            Text(contact.effectiveName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(width: 6),
            if (contact.isSafetyNumberVerified)
              const Icon(LucideIcons.badgeCheck, size: 14, color: AppTheme.primary),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(contact.handle, style: const TextStyle(fontSize: 12, color: AppTheme.primary)),
            if (contact.bio.isNotEmpty)
              Text(contact.bio, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(LucideIcons.messageSquare, color: AppTheme.primary),
          tooltip: 'Direct Message',
          onPressed: () => _startDmWithContact(contact),
        ),
      ),
    );
  }

  void _startDmWithContact(Contact contact) {
    final myPubKey = widget.contactStore.myProfile.pubKeyHex;
    final convId = 'dm_${contact.pubKeyHex}';

    final conv = Conversation(
      id: convId,
      title: contact.effectiveName,
      type: ConversationType.directMessage,
      participantPubKeys: [myPubKey, contact.pubKeyHex],
      lastMessageTimeMs: DateTime.now().millisecondsSinceEpoch,
      avatarSeed: contact.avatarSeed,
    );

    widget.contactStore.addOrUpdateConversation(conv);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CivilianChatScreen(
          conversation: conv,
          contactStore: widget.contactStore,
          onBroadcastBundle: widget.onBroadcastBundle,
        ),
      ),
    );
  }

  void _startDmWithPeer(String peerName, String pubKey) {
    final myPubKey = widget.contactStore.myProfile.pubKeyHex;
    final convId = 'dm_$pubKey';

    final conv = Conversation(
      id: convId,
      title: peerName,
      type: ConversationType.directMessage,
      participantPubKeys: [myPubKey, pubKey],
      lastMessageTimeMs: DateTime.now().millisecondsSinceEpoch,
      avatarSeed: 3,
    );

    widget.contactStore.addOrUpdateConversation(conv);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CivilianChatScreen(
          conversation: conv,
          contactStore: widget.contactStore,
          onBroadcastBundle: widget.onBroadcastBundle,
        ),
      ),
    );
  }

  void _showAddContactModal() {
    final nameController = TextEditingController();
    final handleController = TextEditingController();
    final pubKeyController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text('Add Contact to Address Book'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Display Name (e.g. Sarah)', filled: true),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: handleController,
                decoration: const InputDecoration(labelText: 'Username Handle (e.g. sarah_99)', prefixText: '@', filled: true),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: pubKeyController,
                decoration: const InputDecoration(labelText: 'Public Key Hex (or scan QR)', filled: true),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary, foregroundColor: Colors.black),
            onPressed: () {
              final name = nameController.text.trim();
              final handle = handleController.text.trim().replaceAll('@', '');
              var key = pubKeyController.text.trim();
              if (name.isEmpty) return;
              if (key.isEmpty) key = 'pub_${handle}_ed25519';

              final newContact = Contact(
                pubKeyHex: key,
                username: handle.isNotEmpty ? handle : 'user_${DateTime.now().millisecond}',
                displayName: name,
                lastSeenMs: DateTime.now().millisecondsSinceEpoch,
              );

              widget.contactStore.addOrUpdateContact(newContact);
              Navigator.pop(context);
              setState(() {});
            },
            child: const Text('Save Contact'),
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
