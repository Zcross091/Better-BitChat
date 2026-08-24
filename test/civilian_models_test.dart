import 'package:flutter_test/flutter_test.dart';
import 'package:mesh_messenger/core/models/chat_message.dart';
import 'package:mesh_messenger/core/models/contact.dart';
import 'package:mesh_messenger/core/models/conversation.dart';
import 'package:mesh_messenger/core/models/media_payload.dart';
import 'package:mesh_messenger/core/models/user_profile.dart';

void main() {
  group('Civilian Data Models & WhatsApp Feature Tests', () {
    test('UserProfile serialization, handle prefix, and copyWith work as expected', () {
      final profile = UserProfile(
        pubKeyHex: 'pub_alice_ed25519_01',
        username: 'alice_walker',
        displayName: 'Alice Walker',
        bio: 'Off-grid mesh pioneer 📡',
        avatarSeed: 3,
        nip05Handle: 'alice@mesh.nostr',
        isVerified: true,
      );

      expect(profile.handle, equals('@alice_walker'));

      final json = profile.toJson();
      final fromJson = UserProfile.fromJson(json);

      expect(fromJson.pubKeyHex, equals(profile.pubKeyHex));
      expect(fromJson.username, equals('alice_walker'));
      expect(fromJson.displayName, equals('Alice Walker'));
      expect(fromJson.isVerified, isTrue);

      final updated = profile.copyWith(displayName: 'Alice W.');
      expect(updated.displayName, equals('Alice W.'));
      expect(updated.username, equals('alice_walker'));
    });

    test('Contact model handles custom nicknames and online detection correctly', () {
      final now = DateTime.now().millisecondsSinceEpoch;
      final contact = Contact(
        pubKeyHex: 'pub_eve_05',
        username: 'eve_volunteer',
        displayName: 'Eve Responder',
        customNickname: 'Eve (Lead)',
        bio: 'Field responder',
        lastSeenMs: now - 10000, // 10 seconds ago
        isSafetyNumberVerified: true,
      );

      expect(contact.effectiveName, equals('Eve (Lead)'));
      expect(contact.handle, equals('@eve_volunteer'));
      expect(contact.isOnline, isTrue);

      final json = contact.toJson();
      final fromJson = Contact.fromJson(json);
      expect(fromJson.customNickname, equals('Eve (Lead)'));
      expect(fromJson.isSafetyNumberVerified, isTrue);
    });

    test('ChatMessage supports emoji reactions toggling and delivery receipts', () {
      final msg = ChatMessage(
        id: 'msg_01',
        conversationId: 'dm_eve',
        senderPubKey: 'pub_alice',
        senderDisplayName: 'Alice',
        timestampMs: 1700000000,
        isOutgoing: true,
        status: MessageDeliveryStatus.sentToStore,
        media: MediaPayload.text('Hello Eve!'),
      );

      expect(msg.reactions.isEmpty, isTrue);

      // Add reaction
      msg.toggleReaction('👍', 'pub_eve');
      expect(msg.reactions['👍'], contains('pub_eve'));

      // Add second reaction
      msg.toggleReaction('❤️', 'pub_bob');
      expect(msg.reactions.length, equals(2));

      // Toggle off
      msg.toggleReaction('👍', 'pub_eve');
      expect(msg.reactions.containsKey('👍'), isFalse);
      expect(msg.reactions.length, equals(1));

      // Test JSON roundtrip
      final json = msg.toJson();
      final fromJson = ChatMessage.fromJson(json);
      expect(fromJson.id, equals('msg_01'));
      expect(fromJson.media.textContent, equals('Hello Eve!'));
      expect(fromJson.reactions['❤️'], contains('pub_bob'));
    });

    test('Conversation model manages DMs and groups with participant lists', () {
      final conv = Conversation(
        id: 'group_rescue_44',
        title: 'Rescue Squad Alpha',
        type: ConversationType.privateGroup,
        participantPubKeys: ['pub_alice', 'pub_bob', 'pub_eve'],
        lastMessageText: 'Grid clear',
        lastMessageTimeMs: 1700000000,
        unreadCount: 3,
        avatarSeed: 6,
        adminPubKey: 'pub_alice',
      );

      expect(conv.isGroup, isTrue);
      expect(conv.isDirectMessage, isFalse);
      expect(conv.participantPubKeys.length, equals(3));

      final json = conv.toJson();
      final fromJson = Conversation.fromJson(json);
      expect(fromJson.id, equals('group_rescue_44'));
      expect(fromJson.title, equals('Rescue Squad Alpha'));
      expect(fromJson.adminPubKey, equals('pub_alice'));
      expect(fromJson.unreadCount, equals(3));
    });
  });
}
