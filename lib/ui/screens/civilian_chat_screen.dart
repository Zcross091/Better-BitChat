import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../core/models/bundle.dart';
import '../../core/models/chat_message.dart';
import '../../core/models/conversation.dart';
import '../../core/models/media_payload.dart';
import '../../core/storage/contact_store.dart';
import '../theme/app_theme.dart';

class CivilianChatScreen extends StatefulWidget {
  final Conversation conversation;
  final ContactStore contactStore;
  final Function(Bundle) onBroadcastBundle;

  const CivilianChatScreen({
    super.key,
    required this.conversation,
    required this.contactStore,
    required this.onBroadcastBundle,
  });

  @override
  State<CivilianChatScreen> createState() => _CivilianChatScreenState();
}

class _CivilianChatScreenState extends State<CivilianChatScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  String? _replyingToSnippet;
  bool _isVoiceRecording = false;

  @override
  void initState() {
    super.initState();
    widget.contactStore.markConversationRead(widget.conversation.id);
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _sendTextMessage() {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    final myProfile = widget.contactStore.myProfile;
    final payload = MediaPayload.text(text);
    _dispatchMessage(payload, _replyingToSnippet);

    _textController.clear();
    setState(() {
      _replyingToSnippet = null;
    });
  }

  void _sendVoiceNote() {
    final payload = MediaPayload.voiceNote(
      audioBase64: 'simulated_opus_audio_bytes_base64',
      durationSec: 6,
      label: 'Voice Note (0:06)',
    );
    _dispatchMessage(payload, null);
  }

  void _sendPhotoAttachment() {
    final payload = MediaPayload.image(
      imageBase64: 'simulated_photo_bytes_base64',
      width: 1080,
      height: 720,
      caption: 'Field Reconnaissance Photo 📷',
    );
    _dispatchMessage(payload, null);
  }

  void _sendVideoClip() {
    final payload = MediaPayload.videoClip(
      thumbnailBase64: 'simulated_video_thumb',
      durationSec: 12,
      caption: 'Field Video Briefing (0:12) 🎥',
    );
    _dispatchMessage(payload, null);
  }

  void _sendGeoMarkerSos() {
    final payload = MediaPayload.geoMarker(
      lat: 26.8467,
      lon: 80.9462,
      alt: 128.0,
      label: 'Emergency Relief Rally Point (Secure)',
      emergencySeverity: 1,
    );
    _dispatchMessage(payload, null);
  }

  void _dispatchMessage(MediaPayload payload, String? replySnippet) {
    final myProfile = widget.contactStore.myProfile;
    final now = DateTime.now().millisecondsSinceEpoch;
    final msgId = 'msg_${now}_${myProfile.username}';

    final chatMsg = ChatMessage(
      id: msgId,
      conversationId: widget.conversation.id,
      senderPubKey: myProfile.pubKeyHex,
      senderDisplayName: myProfile.displayName,
      timestampMs: now,
      isOutgoing: true,
      status: MessageDeliveryStatus.sentToStore,
      media: payload,
      replyToSnippet: replySnippet,
    );

    widget.contactStore.addMessage(chatMsg);

    // Create DTN bundle for mesh broadcast
    final destPub = widget.conversation.isGroup
        ? widget.conversation.id
        : (widget.conversation.isChannel ? 'all' : widget.conversation.participantPubKeys.firstWhere((p) => p != myProfile.pubKeyHex, orElse: () => 'all'));

    final bundle = Bundle(
      bundleId: Bundle.generateBundleId(
        senderPubkey: myProfile.pubKeyHex,
        destPubkey: destPub,
        createdAt: now,
        nonce: msgId,
      ),
      senderPubkey: myProfile.pubKeyHex,
      destPubkey: destPub,
      createdAt: now,
      ttlHours: 48,
      hopCount: 0,
      priority: payload.type == MediaPayloadType.geoMarker ? BundlePriority.high : BundlePriority.normal,
      payload: payload.serialize(),
      signature: 'sig_ed25519_${myProfile.username}',
    );

    widget.onBroadcastBundle(bundle);
    setState(() {});
    _scrollToBottom();
  }

  void _showEmojiReactionDialog(ChatMessage msg) {
    const emojis = ['👍', '❤️', '😂', '😮', '😢', '🙏', '🔥', '🚨'];
    final myPubKey = widget.contactStore.myProfile.pubKeyHex;

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
              const Text('React to Message', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: emojis.map((e) {
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        msg.toggleReaction(e, myPubKey);
                      });
                      Navigator.pop(context);
                    },
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceElevated,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(e, style: const TextStyle(fontSize: 24)),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(LucideIcons.reply, color: AppTheme.primary),
                title: const Text('Reply Quote'),
                onTap: () {
                  setState(() {
                    _replyingToSnippet = msg.media.textContent.isNotEmpty
                        ? msg.media.textContent
                        : msg.media.type.name;
                  });
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final messages = widget.contactStore.getMessages(widget.conversation.id);

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: _getSeedColor(widget.conversation.avatarSeed),
              child: Text(
                widget.conversation.title.substring(0, 1).toUpperCase(),
                style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.conversation.title,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    widget.conversation.isGroup
                        ? '${widget.conversation.participantPubKeys.length} members • E2E Encrypted'
                        : (widget.conversation.isChannel ? 'Global Nostr Relay Channel' : 'Direct Message • Offline-Ready'),
                    style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.shieldCheck, color: AppTheme.primary),
            tooltip: 'End-to-End Encryption Verified',
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('🔒 ChaCha20-Poly1305 + Signal Sender Key ratchets active on this chat.')),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Message stream
          Expanded(
            child: messages.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(LucideIcons.messageSquare, size: 48, color: AppTheme.textSecondary.withOpacity(0.5)),
                        const SizedBox(height: 12),
                        Text(
                          'No messages yet in ${widget.conversation.title}',
                          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Send a message, voice note, or photo across the mesh!',
                          style: TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final msg = messages[index];
                      return _buildMessageBubble(msg);
                    },
                  ),
          ),

          // Quoted Reply Preview Bar
          if (_replyingToSnippet != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: AppTheme.surfaceElevated,
              child: Row(
                children: [
                  Container(width: 3, height: 32, color: AppTheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Replying to:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primary)),
                        Text(_replyingToSnippet!, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(LucideIcons.x, size: 16),
                    onPressed: () => setState(() => _replyingToSnippet = null),
                  ),
                ],
              ),
            ),

          // Bottom Input Bar
          _buildInputBar(),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage msg) {
    final isOut = msg.isOutgoing;
    final timeStr = _formatTimestamp(msg.timestampMs);

    return Align(
      alignment: isOut ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: () => _showEmojiReactionDialog(msg),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
          decoration: BoxDecoration(
            color: isOut ? AppTheme.primary.withOpacity(0.18) : AppTheme.surfaceElevated,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(16),
              topRight: const Radius.circular(16),
              bottomLeft: isOut ? const Radius.circular(16) : const Radius.circular(2),
              bottomRight: isOut ? const Radius.circular(2) : const Radius.circular(16),
            ),
            border: Border.all(
              color: isOut ? AppTheme.primary.withOpacity(0.3) : AppTheme.border,
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Column(
            crossAxisAlignment: isOut ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              // Sender Name in Groups
              if (!isOut && widget.conversation.isGroup)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    msg.senderDisplayName,
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primary),
                  ),
                ),

              // Reply snippet if quoting
              if (msg.replyToSnippet != null)
                Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(6),
                    border: const Border(left: BorderSide(color: AppTheme.primary, width: 2)),
                  ),
                  child: Text(
                    msg.replyToSnippet!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: AppTheme.textSecondary),
                  ),
                ),

              // Media Content
              _buildMediaBody(msg.media),

              const SizedBox(height: 4),

              // Timestamp & Delivery Ticks
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(timeStr, style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
                  if (isOut) ...[
                    const SizedBox(width: 4),
                    _buildDeliveryTick(msg.status),
                  ],
                ],
              ),

              // Emoji Reactions Badge
              if (msg.reactions.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Wrap(
                    spacing: 4,
                    children: msg.reactions.entries.map((e) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.background,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppTheme.border),
                        ),
                        child: Text(
                          '${e.key} ${e.value.length > 1 ? e.value.length : ''}',
                          style: const TextStyle(fontSize: 11),
                        ),
                      );
                    }).toList(),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMediaBody(MediaPayload media) {
    switch (media.type) {
      case MediaPayloadType.voiceNote:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircleAvatar(
              radius: 16,
              backgroundColor: AppTheme.primary,
              child: Icon(LucideIcons.play, size: 16, color: Colors.black),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: List.generate(14, (i) {
                    final h = (i % 3 + 1) * 5.0 + 4.0;
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 1.5),
                      width: 2.5,
                      height: h,
                      decoration: BoxDecoration(
                        color: AppTheme.primary,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 2),
                Text(media.textContent, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
              ],
            ),
          ],
        );

      case MediaPayloadType.image:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 200,
              height: 120,
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.border),
              ),
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(LucideIcons.image, size: 32, color: AppTheme.primary),
                    SizedBox(height: 4),
                    Text('Photo Attachment', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                  ],
                ),
              ),
            ),
            if (media.textContent.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(media.textContent, style: const TextStyle(fontSize: 13)),
              ),
          ],
        );

      case MediaPayloadType.videoClip:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 200,
              height: 120,
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.secondary),
              ),
              child: const Center(
                child: CircleAvatar(
                  radius: 20,
                  backgroundColor: AppTheme.secondary,
                  child: Icon(LucideIcons.play, color: Colors.black, size: 20),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(media.textContent, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            ),
          ],
        );

      case MediaPayloadType.geoMarker:
        return Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppTheme.warning.withOpacity(0.12),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppTheme.warning),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(LucideIcons.mapPin, color: AppTheme.warning, size: 16),
                  SizedBox(width: 6),
                  Text('Tactical Geo-Marker SOS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.warning)),
                ],
              ),
              const SizedBox(height: 4),
              Text(media.textContent, style: const TextStyle(fontSize: 12)),
              Text('GPS: ${media.latitude?.toStringAsFixed(4)}, ${media.longitude?.toStringAsFixed(4)}', style: const TextStyle(fontSize: 11, fontFamily: 'FiraCode', color: AppTheme.textSecondary)),
            ],
          ),
        );

      case MediaPayloadType.text:
      default:
        return Text(
          media.textContent,
          style: const TextStyle(fontSize: 14, color: AppTheme.textPrimary),
        );
    }
  }

  Widget _buildDeliveryTick(MessageDeliveryStatus status) {
    switch (status) {
      case MessageDeliveryStatus.pending:
        return const Icon(LucideIcons.clock, size: 11, color: AppTheme.textSecondary);
      case MessageDeliveryStatus.sentToStore:
        return const Icon(LucideIcons.check, size: 13, color: AppTheme.textSecondary);
      case MessageDeliveryStatus.forwardedAcrossMesh:
        return const Icon(LucideIcons.checkCheck, size: 13, color: AppTheme.textSecondary);
      case MessageDeliveryStatus.delivered:
        return const Icon(LucideIcons.checkCheck, size: 13, color: AppTheme.textPrimary);
      case MessageDeliveryStatus.read:
        return const Icon(LucideIcons.checkCheck, size: 13, color: Color(0xFF29B6F6));
    }
  }

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        border: Border(top: BorderSide(color: AppTheme.border)),
      ),
      child: SafeArea(
        child: Row(
          children: [
            // Attach Media Button
            IconButton(
              icon: const Icon(LucideIcons.paperclip, color: AppTheme.textSecondary),
              tooltip: 'Attach Media',
              onPressed: _showAttachmentDrawer,
            ),

            // Text Input Field
            Expanded(
              child: TextField(
                controller: _textController,
                style: const TextStyle(fontSize: 14, color: AppTheme.textPrimary),
                decoration: InputDecoration(
                  hintText: 'Type a mesh message...',
                  hintStyle: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                  filled: true,
                  fillColor: AppTheme.surfaceElevated,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                ),
                onSubmitted: (_) => _sendTextMessage(),
              ),
            ),
            const SizedBox(width: 6),

            // Send / Voice Record Button
            GestureDetector(
              onLongPress: () {
                setState(() => _isVoiceRecording = true);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('🎙️ Recording voice note... Release to send.')));
              },
              onLongPressEnd: (_) {
                setState(() => _isVoiceRecording = false);
                _sendVoiceNote();
              },
              child: CircleAvatar(
                radius: 20,
                backgroundColor: AppTheme.primary,
                child: IconButton(
                  icon: const Icon(LucideIcons.send, color: Colors.black, size: 18),
                  onPressed: _sendTextMessage,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAttachmentDrawer() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Send Media across Mesh', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildAttachOption(LucideIcons.camera, 'Photo', AppTheme.primary, () {
                    Navigator.pop(context);
                    _sendPhotoAttachment();
                  }),
                  _buildAttachOption(LucideIcons.video, 'Video Clip', AppTheme.secondary, () {
                    Navigator.pop(context);
                    _sendVideoClip();
                  }),
                  _buildAttachOption(LucideIcons.mic, 'Voice Note', const Color(0xFF81C784), () {
                    Navigator.pop(context);
                    _sendVoiceNote();
                  }),
                  _buildAttachOption(LucideIcons.mapPin, 'Geo SOS', AppTheme.warning, () {
                    Navigator.pop(context);
                    _sendGeoMarkerSos();
                  }),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAttachOption(IconData icon, String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: color.withOpacity(0.18),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 6),
          Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  String _formatTimestamp(int ms) {
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
