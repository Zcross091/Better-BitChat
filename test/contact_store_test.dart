import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mesh_messenger/core/models/chat_message.dart';
import 'package:mesh_messenger/core/models/contact.dart';
import 'package:mesh_messenger/core/models/conversation.dart';
import 'package:mesh_messenger/core/models/media_payload.dart';
import 'package:mesh_messenger/core/models/user_profile.dart';
import 'package:mesh_messenger/core/storage/contact_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ContactStore & Civilian Address Book Tests', () {
    late ContactStore store;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      store = ContactStore();
      await store.hydrate('pub_alice_ed25519_01');
    });

    test('Hydrates default seeded contacts and conversations when storage is empty', () {
      expect(store.allContacts.isNotEmpty, isTrue);
      expect(store.allConversations.isNotEmpty, isTrue);

      final eve = store.searchContacts('eve');
      expect(eve.isNotEmpty, isTrue);
      expect(eve.first.username, equals('eve_relay'));
    });

    test('Saves custom user profile and updates handle', () async {
      final updatedProfile = UserProfile(
        pubKeyHex: 'pub_alice_ed25519_01',
        username: 'alice_super_mesh',
        displayName: 'Alice Supreme',
        bio: 'Securing offline communication',
        avatarSeed: 4,
        isVerified: true,
      );

      await store.saveProfile(updatedProfile);
      expect(store.myProfile.username, equals('alice_super_mesh'));
      expect(store.myProfile.handle, equals('@alice_super_mesh'));
      expect(store.myProfile.displayName, equals('Alice Supreme'));
    });

    test('Adds contact and searches address book by username, nickname, or key', () async {
      final newContact = Contact(
        pubKeyHex: 'pub_charlie_03',
        username: 'charlie_mesh',
        displayName: 'Charlie Brown',
        customNickname: 'Chuck',
        bio: 'Offline radio builder',
        lastSeenMs: DateTime.now().millisecondsSinceEpoch,
      );

      await store.addOrUpdateContact(newContact);

      // Search by nickname
      final byNick = store.searchContacts('chuck');
      expect(byNick.length, equals(1));
      expect(byNick.first.username, equals('charlie_mesh'));

      // Search by username
      final byUser = store.searchContacts('charlie_mesh');
      expect(byUser.length, equals(1));

      // Search by public key
      final byKey = store.searchContacts('pub_charlie_03');
      expect(byKey.length, equals(1));
    });

    test('Creates conversation, adds messages, updates snippet and marks read', () async {
      final conv = Conversation(
        id: 'dm_pub_charlie_03',
        title: 'Charlie Brown',
        type: ConversationType.directMessage,
        participantPubKeys: ['pub_alice', 'pub_charlie_03'],
        lastMessageTimeMs: DateTime.now().millisecondsSinceEpoch,
      );

      await store.addOrUpdateConversation(conv);

      final msg = ChatMessage(
        id: 'msg_01',
        conversationId: conv.id,
        senderPubKey: 'pub_charlie_03',
        senderDisplayName: 'Charlie',
        timestampMs: DateTime.now().millisecondsSinceEpoch,
        isOutgoing: false,
        status: MessageDeliveryStatus.sentToStore,
        media: MediaPayload.text('Hello Alice, testing mesh DMs!'),
      );

      await store.addMessage(msg);

      final storedMsgs = store.getMessages(conv.id);
      expect(storedMsgs.length, equals(1));
      expect(storedMsgs.first.media.textContent, equals('Hello Alice, testing mesh DMs!'));

      // Conversation unread count and snippet updated
      final updatedConv = store.allConversations.firstWhere((c) => c.id == conv.id);
      expect(updatedConv.lastMessageText, equals('Hello Alice, testing mesh DMs!'));
      expect(updatedConv.unreadCount, equals(1));

      // Mark read
      store.markConversationRead(conv.id);
      expect(store.allConversations.firstWhere((c) => c.id == conv.id).unreadCount, equals(0));
    });

    test('Emergency panic wipe completely clears all contacts, messages, and profile', () async {
      expect(store.allContacts.isNotEmpty, isTrue);
      expect(store.allConversations.isNotEmpty, isTrue);

      await store.clearAll();

      expect(store.allContacts.isEmpty, isTrue);
      expect(store.allConversations.isEmpty, isTrue);
    });
  });
}
