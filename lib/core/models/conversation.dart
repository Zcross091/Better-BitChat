import 'dart:convert';
import '../crypto/group_sender_key.dart';
import 'chat_message.dart';

enum ConversationType {
  directMessage,
  privateGroup,
  publicChannel,
}

/// Represents a chat thread in the WhatsApp-style conversation list.
class Conversation {
  final String id;
  String title;
  final ConversationType type;
  final List<String> participantPubKeys;
  String lastMessageText;
  int lastMessageTimeMs;
  int unreadCount;
  int avatarSeed;
  String? adminPubKey;
  GroupSenderKeyState? groupSenderKey;

  Conversation({
    required this.id,
    required this.title,
    required this.type,
    required this.participantPubKeys,
    this.lastMessageText = '',
    required this.lastMessageTimeMs,
    this.unreadCount = 0,
    this.avatarSeed = 1,
    this.adminPubKey,
    this.groupSenderKey,
  });

  bool get isGroup => type == ConversationType.privateGroup;
  bool get isChannel => type == ConversationType.publicChannel;
  bool get isDirectMessage => type == ConversationType.directMessage;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'type': type.index,
        'participant_pub_keys': participantPubKeys,
        'last_message_text': lastMessageText,
        'last_message_time_ms': lastMessageTimeMs,
        'unread_count': unreadCount,
        'avatar_seed': avatarSeed,
        if (adminPubKey != null) 'admin_pub_key': adminPubKey,
        if (groupSenderKey != null) 'group_sender_key': groupSenderKey!.toJson(),
      };

  factory Conversation.fromJson(Map<String, dynamic> json) {
    return Conversation(
      id: json['id'] as String,
      title: json['title'] as String? ?? 'Chat',
      type: ConversationType.values[(json['type'] as int? ?? 0).clamp(0, ConversationType.values.length - 1)],
      participantPubKeys: List<String>.from(json['participant_pub_keys'] as List? ?? []),
      lastMessageText: json['last_message_text'] as String? ?? '',
      lastMessageTimeMs: json['last_message_time_ms'] as int? ?? 0,
      unreadCount: json['unread_count'] as int? ?? 0,
      avatarSeed: json['avatar_seed'] as int? ?? 1,
      adminPubKey: json['admin_pub_key'] as String?,
      groupSenderKey: json['group_sender_key'] != null
          ? GroupSenderKeyState.fromJson(json['group_sender_key'] as Map<String, dynamic>)
          : null,
    );
  }
}
