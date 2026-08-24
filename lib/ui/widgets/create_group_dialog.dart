import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../core/crypto/group_sender_key.dart';
import '../../core/models/contact.dart';
import '../../core/models/conversation.dart';
import '../../core/storage/contact_store.dart';
import '../theme/app_theme.dart';

class CreateGroupDialog extends StatefulWidget {
  final ContactStore contactStore;
  final Function(Conversation) onGroupCreated;

  const CreateGroupDialog({
    super.key,
    required this.contactStore,
    required this.onGroupCreated,
  });

  @override
  State<CreateGroupDialog> createState() => _CreateGroupDialogState();
}

class _CreateGroupDialogState extends State<CreateGroupDialog> {
  final TextEditingController _groupNameController = TextEditingController();
  final Set<String> _selectedContactPubKeys = {};
  int _selectedAvatarSeed = 7;

  @override
  Widget build(BuildContext context) {
    final contacts = widget.contactStore.allContacts;

    return AlertDialog(
      backgroundColor: AppTheme.surface,
      title: const Row(
        children: [
          Icon(LucideIcons.users, color: AppTheme.primary, size: 20),
          SizedBox(width: 8),
          Text('New Private Group Chat', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        ],
      ),
      content: SizedBox(
        width: MediaQuery.of(context).size.width * 0.9,
        height: 460,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Group Name Input
            TextField(
              controller: _groupNameController,
              decoration: InputDecoration(
                labelText: 'Group Name',
                hintText: 'e.g. 🏡 Neighborhood Relief, 🏔️ Hiking',
                prefixIcon: const Icon(LucideIcons.messageSquare, size: 18),
                filled: true,
                fillColor: AppTheme.surfaceElevated,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 12),

            // Avatar Seed Picker
            const Text('Group Icon Color & Seed:', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
            const SizedBox(height: 6),
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
                        border: Border.all(
                          color: isSelected ? AppTheme.primary : Colors.transparent,
                          width: 2,
                        ),
                      ),
                      child: CircleAvatar(
                        radius: 14,
                        backgroundColor: _getSeedColor(seed),
                        child: Text(
                          '$seed',
                          style: const TextStyle(color: Colors.black, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
            const SizedBox(height: 16),

            // Select Members
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Select Members (Signal Sender Keys):', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                Text('${_selectedContactPubKeys.length} selected', style: const TextStyle(fontSize: 11, color: AppTheme.primary)),
              ],
            ),
            const SizedBox(height: 8),

            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: AppTheme.background,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.border),
                ),
                child: ListView.separated(
                  itemCount: contacts.length,
                  separatorBuilder: (c, i) => const Divider(height: 1, color: AppTheme.border),
                  itemBuilder: (context, index) {
                    final contact = contacts[index];
                    final isSelected = _selectedContactPubKeys.contains(contact.pubKeyHex);

                    return CheckboxListTile(
                      value: isSelected,
                      activeColor: AppTheme.primary,
                      checkColor: Colors.black,
                      title: Text(contact.displayName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      subtitle: Text(contact.handle, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                      secondary: CircleAvatar(
                        backgroundColor: _getSeedColor(contact.avatarSeed),
                        radius: 16,
                        child: Text(contact.displayName.substring(0, 1).toUpperCase(), style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                      ),
                      onChanged: (checked) {
                        setState(() {
                          if (checked == true) {
                            _selectedContactPubKeys.add(contact.pubKeyHex);
                          } else {
                            _selectedContactPubKeys.remove(contact.pubKeyHex);
                          }
                        });
                      },
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primary,
            foregroundColor: Colors.black,
          ),
          icon: const Icon(LucideIcons.check, size: 16),
          label: const Text('Create Group'),
          onPressed: () {
            final name = _groupNameController.text.trim();
            if (name.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter a group name.')));
              return;
            }

            final myPubKey = widget.contactStore.myProfile.pubKeyHex;
            final participants = [myPubKey, ..._selectedContactPubKeys];
            final groupId = 'group_${DateTime.now().millisecondsSinceEpoch}';

            final initialSenderKey = GroupSenderKeyEngine.createSenderKey(groupId: groupId);

            final groupConv = Conversation(
              id: groupId,
              title: name,
              type: ConversationType.privateGroup,
              participantPubKeys: participants,
              lastMessageText: 'Group created with forward secrecy ratchets.',
              lastMessageTimeMs: DateTime.now().millisecondsSinceEpoch,
              avatarSeed: _selectedAvatarSeed,
              adminPubKey: myPubKey,
              groupSenderKey: initialSenderKey,
            );

            widget.contactStore.addOrUpdateConversation(groupConv);
            widget.onGroupCreated(groupConv);
            Navigator.pop(context);
          },
        ),
      ],
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
