import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../core/models/bundle.dart';
import '../theme/app_theme.dart';

class ChatScreen extends StatefulWidget {
  final List<Bundle> storedBundles;
  final Function(String message, BundlePriority priority) onSendMessage;

  const ChatScreen({
    super.key,
    required this.storedBundles,
    required this.onSendMessage,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _msgController = TextEditingController();
  BundlePriority _selectedPriority = BundlePriority.normal;
  String _activePeerName = 'Eve (Receiver)';
  String _activePeerPubKey = 'pub_eve_ed25519_05';

  @override
  Widget build(BuildContext context) {
    final relevantBundles = widget.storedBundles
        .where((b) => b.destPubkey == _activePeerPubKey || b.senderPubkey == _activePeerPubKey || b.destPubkey == 'all')
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAlignment.start,
          children: [
            Text(_activePeerName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(color: AppTheme.success, shape: BoxShape.circle),
                ),
                const SizedBox(width: 6),
                const Text('DTN Multi-Transport Mesh Active', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.shieldCheck, color: AppTheme.primary),
            tooltip: 'Key Safety Number',
            onPressed: () {
              _showKeyInfoDialog();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Peer selector bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: AppTheme.surface,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildPeerChip('Eve (Receiver)', 'pub_eve_ed25519_05', LucideIcons.user),
                  const SizedBox(width: 8),
                  _buildPeerChip('Bob (Relay Node)', 'pub_bob_ed25519_02', LucideIcons.cpu),
                  const SizedBox(width: 8),
                  _buildPeerChip('Nostr Internet Gateway', 'pub_dave_gtw_04', LucideIcons.globe),
                  const SizedBox(width: 8),
                  _buildPeerChip('#broadcast-mesh', 'all', LucideIcons.hash),
                ],
              ),
            ),
          ),

          // Message stream
          Expanded(
            child: relevantBundles.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(LucideIcons.messageSquare, size: 48, color: AppTheme.textSecondary),
                        const SizedBox(height: 12),
                        const Text('No DTN Bundles in Storage yet', style: TextStyle(color: AppTheme.textSecondary)),
                        const SizedBox(height: 6),
                        Text(
                          'Send a message to create a signed & encrypted DTN bundle.',
                          style: TextStyle(fontSize: 12, color: AppTheme.textSecondary.withOpacity(0.7)),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: relevantBundles.length,
                    itemBuilder: (context, index) {
                      final bundle = relevantBundles[index];
                      final isMe = bundle.senderPubkey == 'pub_alice_ed25519_01';

                      return _buildBundleBubble(bundle, isMe);
                    },
                  ),
          ),

          // Priority selection pill & input bar
          _buildInputBar(),
        ],
      ),
    );
  }

  Widget _buildPeerChip(String name, String pubKey, IconData icon) {
    final isSelected = _activePeerPubKey == pubKey;
    return ChoiceChip(
      avatar: Icon(icon, size: 14, color: isSelected ? Colors.black : AppTheme.primary),
      label: Text(name),
      selected: isSelected,
      selectedColor: AppTheme.primary,
      backgroundColor: AppTheme.surfaceElevated,
      labelStyle: TextStyle(
        color: isSelected ? Colors.black : AppTheme.textPrimary,
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      onSelected: (selected) {
        if (selected) {
          setState(() {
            _activePeerName = name;
            _activePeerPubKey = pubKey;
          });
        }
      },
    );
  }

  Widget _buildBundleBubble(Bundle bundle, bool isMe) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        maxConstraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.8),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isMe ? AppTheme.primary.withOpacity(0.15) : AppTheme.surfaceElevated,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isMe ? AppTheme.primary.withOpacity(0.4) : AppTheme.border,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAlignment.start,
          children: [
            // DTN Header metadata badge
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(LucideIcons.lock, size: 12, color: AppTheme.primary),
                const SizedBox(width: 4),
                Text(
                  'Bundle ID: ${bundle.bundleId.substring(0, 8)}',
                  style: const TextStyle(fontSize: 10, fontFamily: 'FiraCode', color: AppTheme.textSecondary),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: _getPriorityColor(bundle.priority).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    bundle.priority.name.toUpperCase(),
                    style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: _getPriorityColor(bundle.priority)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),

            // Message Payload Content
            Text(
              bundle.payload,
              style: const TextStyle(fontSize: 14, color: AppTheme.textPrimary),
            ),
            const SizedBox(height: 8),

            // Hop count & TTL Footer
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(LucideIcons.share2, size: 11, color: AppTheme.textSecondary),
                const SizedBox(width: 4),
                Text(
                  '${bundle.hopCount} Hops',
                  style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary),
                ),
                const SizedBox(width: 10),
                const Icon(LucideIcons.clock, size: 11, color: AppTheme.textSecondary),
                const SizedBox(width: 4),
                Text(
                  'TTL: ${bundle.ttlHours}h',
                  style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary),
                ),
                const Spacer(),
                const Icon(LucideIcons.checkCheck, size: 14, color: AppTheme.success),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.all(12),
      color: AppTheme.surface,
      child: SafeArea(
        child: Column(
          children: [
            // Priority Selector Bar
            Row(
              children: [
                const Text('Priority:', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                const SizedBox(width: 8),
                _buildPriorityChip(BundlePriority.low, 'Low', AppTheme.textSecondary),
                const SizedBox(width: 6),
                _buildPriorityChip(BundlePriority.normal, 'Normal', AppTheme.primary),
                const SizedBox(width: 6),
                _buildPriorityChip(BundlePriority.high, 'Emergency (High)', AppTheme.warning),
              ],
            ),
            const SizedBox(height: 8),

            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _msgController,
                    style: const TextStyle(color: AppTheme.textPrimary),
                    decoration: InputDecoration(
                      hintText: 'Type encrypted bundle payload...',
                      hintStyle: const TextStyle(color: AppTheme.textSecondary),
                      filled: true,
                      fillColor: AppTheme.background,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppTheme.border),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  style: IconButton.styleFrom(backgroundColor: AppTheme.primary),
                  icon: const Icon(LucideIcons.send, color: Colors.black),
                  onPressed: () {
                    final text = _msgController.text.trim();
                    if (text.isEmpty) return;

                    widget.onSendMessage(text, _selectedPriority);
                    _msgController.clear();
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPriorityChip(BundlePriority priority, String label, Color color) {
    final isSelected = _selectedPriority == priority;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedPriority = priority;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: isSelected ? color : AppTheme.border),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: isSelected ? color : AppTheme.textSecondary,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Color _getPriorityColor(BundlePriority p) {
    switch (p) {
      case BundlePriority.low:
        return AppTheme.textSecondary;
      case BundlePriority.normal:
        return AppTheme.primary;
      case BundlePriority.high:
        return AppTheme.warning;
    }
  }

  void _showKeyInfoDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: Row(
          children: [
            const Icon(LucideIcons.shieldCheck, color: AppTheme.primary),
            const SizedBox(width: 8),
            Text('Security Verification', style: Theme.of(context).textTheme.titleLarge),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAlignment.start,
          children: [
            const Text('Signal-style Safety Number for verification:'),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.background,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.border),
              ),
              child: const Text(
                '49281  98214  38194  10294',
                style: TextStyle(fontSize: 16, fontFamily: 'FiraCode', fontWeight: FontWeight.bold, color: AppTheme.primary),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Compare this number with your contact out-of-band to ensure zero risk of MITM impersonation.',
              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}
