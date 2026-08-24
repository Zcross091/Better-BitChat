import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../core/models/bundle.dart';
import '../../core/models/conversation.dart';
import '../../core/storage/contact_store.dart';
import '../theme/app_theme.dart';
import '../widgets/create_group_dialog.dart';
import 'civilian_chat_screen.dart';

class ConversationsListScreen extends StatefulWidget {
  final ContactStore contactStore;
  final Function(Bundle) onBroadcastBundle;

  const ConversationsListScreen({
    super.key,
    required this.contactStore,
    required this.onBroadcastBundle,
  });

  @override
  State<ConversationsListScreen> createState() => _ConversationsListScreenState();
}

class _ConversationsListScreenState extends State<ConversationsListScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedFilter = 'All';

  @override
  Widget build(BuildContext context) {
    var conversations = widget.contactStore.searchConversations(_searchQuery);

    if (_selectedFilter == 'Unread') {
      conversations = conversations.where((c) => c.unreadCount > 0).toList();
    } else if (_selectedFilter == 'Groups') {
      conversations = conversations.where((c) => c.isGroup).toList();
    } else if (_selectedFilter == 'Channels') {
      conversations = conversations.where((c) => c.isChannel).toList();
    }

    final myProfile = widget.contactStore.myProfile;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: _getSeedColor(myProfile.avatarSeed),
              child: Text(
                myProfile.displayName.substring(0, 1).toUpperCase(),
                style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Mesh Messenger', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                Text('${myProfile.handle} • Offline-Ready', style: const TextStyle(fontSize: 11, color: AppTheme.primary)),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.userPlus, color: AppTheme.primary),
            tooltip: 'New Group',
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => CreateGroupDialog(
                  contactStore: widget.contactStore,
                  onGroupCreated: (newGroup) {
                    setState(() {});
                    _openChat(newGroup);
                  },
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search chats, groups, or messages...',
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
          ),

          // Filter Chips (All, Unread, Groups, Channels)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: ['All', 'Unread', 'Groups', 'Channels'].map((filter) {
                final isSelected = _selectedFilter == filter;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(filter, style: TextStyle(fontSize: 12, color: isSelected ? Colors.black : AppTheme.textPrimary)),
                    selected: isSelected,
                    selectedColor: AppTheme.primary,
                    backgroundColor: AppTheme.surfaceElevated,
                    onSelected: (selected) {
                      if (selected) setState(() => _selectedFilter = filter);
                    },
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 6),

          // Conversation List
          Expanded(
            child: conversations.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(LucideIcons.messageCircle, size: 48, color: AppTheme.textSecondary.withOpacity(0.4)),
                        const SizedBox(height: 12),
                        const Text('No conversations found.', style: TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
                        const SizedBox(height: 6),
                        const Text('Tap + below to start a new chat or group!', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                      ],
                    ),
                  )
                : ListView.separated(
                    itemCount: conversations.length,
                    separatorBuilder: (context, index) => const Divider(height: 1, indent: 72, color: AppTheme.border),
                    itemBuilder: (context, index) {
                      final conv = conversations[index];
                      return _buildConversationTile(conv);
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.black,
        tooltip: 'New Chat / Group',
        onPressed: _showNewChatMenu,
        child: const Icon(LucideIcons.messageSquarePlus),
      ),
    );
  }

  Widget _buildConversationTile(Conversation conv) {
    final timeStr = _formatTimestamp(conv.lastMessageTimeMs);

    return ListTile(
      onTap: () => _openChat(conv),
      leading: Stack(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: _getSeedColor(conv.avatarSeed),
            child: Icon(
              conv.isGroup ? LucideIcons.users : (conv.isChannel ? LucideIcons.globe : LucideIcons.user),
              color: Colors.black,
              size: 22,
            ),
          ),
          if (conv.isGroup)
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: const BoxDecoration(color: AppTheme.primary, shape: BoxShape.circle),
                child: const Icon(LucideIcons.lock, size: 10, color: Colors.black),
              ),
            ),
        ],
      ),
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              conv.title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(timeStr, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
        ],
      ),
      subtitle: Row(
        children: [
          Expanded(
            child: Text(
              conv.lastMessageText.isNotEmpty ? conv.lastMessageText : 'Tap to open chat',
              style: TextStyle(
                fontSize: 12,
                color: conv.unreadCount > 0 ? AppTheme.textPrimary : AppTheme.textSecondary,
                fontWeight: conv.unreadCount > 0 ? FontWeight.bold : FontWeight.normal,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (conv.unreadCount > 0)
            Container(
              margin: const EdgeInsets.only(left: 6),
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: AppTheme.primary,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${conv.unreadCount}',
                style: const TextStyle(color: Colors.black, fontSize: 10, fontWeight: FontWeight.bold),
              ),
            ),
        ],
      ),
    );
  }

  void _openChat(Conversation conv) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CivilianChatScreen(
          conversation: conv,
          contactStore: widget.contactStore,
          onBroadcastBundle: widget.onBroadcastBundle,
        ),
      ),
    ).then((_) => setState(() {}));
  }

  void _showNewChatMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: AppTheme.primary,
                  child: Icon(LucideIcons.users, color: Colors.black, size: 20),
                ),
                title: const Text('Create New Private Group', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text('Encrypted with Signal-style Group Sender Keys', style: TextStyle(fontSize: 12)),
                onTap: () {
                  Navigator.pop(context);
                  showDialog(
                    context: context,
                    builder: (context) => CreateGroupDialog(
                      contactStore: widget.contactStore,
                      onGroupCreated: (newGroup) {
                        setState(() {});
                        _openChat(newGroup);
                      },
                    ),
                  );
                },
              ),
              const Divider(),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: AppTheme.secondary,
                  child: Icon(LucideIcons.globe, color: Colors.black, size: 20),
                ),
                title: const Text('Join Public Mesh Channel', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text('Nostr relay & physical radio open broadcasts', style: TextStyle(fontSize: 12)),
                onTap: () {
                  Navigator.pop(context);
                  _joinPublicChannelPrompt();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _joinPublicChannelPrompt() {
    final channelNameController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text('Join Public Mesh Channel'),
        content: TextField(
          controller: channelNameController,
          decoration: const InputDecoration(
            hintText: 'e.g. #relief, #crypto, #ham-radio',
            prefixText: '#',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary, foregroundColor: Colors.black),
            onPressed: () {
              final name = channelNameController.text.trim();
              if (name.isEmpty) return;

              final channelConv = Conversation(
                id: 'channel_${name.replaceAll('#', '')}',
                title: '#${name.replaceAll('#', '')}',
                type: ConversationType.publicChannel,
                participantPubKeys: ['all'],
                lastMessageTimeMs: DateTime.now().millisecondsSinceEpoch,
                avatarSeed: 9,
              );

              widget.contactStore.addOrUpdateConversation(channelConv);
              Navigator.pop(context);
              setState(() {});
              _openChat(channelConv);
            },
            child: const Text('Join Channel'),
          ),
        ],
      ),
    );
  }

  String _formatTimestamp(int ms) {
    if (ms == 0) return '';
    final dt = DateTime.fromMillisecondsSinceEpoch(ms);
    return "${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";
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
