import 'dart:convert';
import 'media_payload.dart';

enum MessageDeliveryStatus {
  pending, // Clock icon (local transmit queue)
  sentToStore, // Single grey checkmark (stored in local DTN store)
  forwardedAcrossMesh, // Double grey checkmark (forwarded across intermediate hop)
  delivered, // Double dark checkmark (delivered to destination node)
  read, // Double blue checkmark (opened & read by recipient)
}

/// Represents a rich civilian chat message with delivery receipts, media, and reactions.
class ChatMessage {
  final String id;
  final String conversationId;
  final String senderPubKey;
  final String senderDisplayName;
  final int timestampMs;
  final bool isOutgoing;
  MessageDeliveryStatus status;
  final MediaPayload media;
  final Map<String, List<String>> reactions; // emoji -> list of sender public keys (e.g. "👍": ["pub1", "pub2"])
  final String? replyToSnippet;

  ChatMessage({
    required this.id,
    required this.conversationId,
    required this.senderPubKey,
    required this.senderDisplayName,
    required this.timestampMs,
    required this.isOutgoing,
    this.status = MessageDeliveryStatus.pending,
    required this.media,
    Map<String, List<String>>? reactions,
    this.replyToSnippet,
  }) : reactions = reactions ?? {};

  /// Adds or toggles an emoji reaction from a user
  void toggleReaction(String emoji, String userPubKey) {
    reactions.putIfAbsent(emoji, () => []);
    if (reactions[emoji]!.contains(userPubKey)) {
      reactions[emoji]!.remove(userPubKey);
      if (reactions[emoji]!.isEmpty) {
        reactions.remove(emoji);
      }
    } else {
      reactions[emoji]!.add(userPubKey);
    }
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'conversation_id': conversationId,
        'sender_pub_key': senderPubKey,
        'sender_display_name': senderDisplayName,
        'timestamp_ms': timestampMs,
        'is_outgoing': isOutgoing,
        'status': status.index,
        'media': media.toJson(),
        'reactions': reactions,
        'reply_to_snippet': replyToSnippet,
      };

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    final rawReactions = json['reactions'] as Map<String, dynamic>? ?? {};
    final parsedReactions = <String, List<String>>{};
    rawReactions.forEach((key, val) {
      if (val is List) {
        parsedReactions[key] = List<String>.from(val);
      }
    });

    return ChatMessage(
      id: json['id'] as String,
      conversationId: json['conversation_id'] as String,
      senderPubKey: json['sender_pub_key'] as String,
      senderDisplayName: json['sender_display_name'] as String? ?? 'Peer',
      timestampMs: json['timestamp_ms'] as int? ?? DateTime.now().millisecondsSinceEpoch,
      isOutgoing: json['is_outgoing'] as bool? ?? false,
      status: MessageDeliveryStatus.values[(json['status'] as int? ?? 1).clamp(0, MessageDeliveryStatus.values.length - 1)],
      media: MediaPayload.fromJson(json['media'] as Map<String, dynamic>? ?? {}),
      reactions: parsedReactions,
      replyToSnippet: json['reply_to_snippet'] as String?,
    );
  }
}
