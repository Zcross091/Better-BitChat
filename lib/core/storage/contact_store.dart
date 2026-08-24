import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/chat_message.dart';
import '../models/contact.dart';
import '../models/conversation.dart';
import '../models/media_payload.dart';
import '../models/user_profile.dart';
import '../../transports/transport_manager.dart';

/// Persistent storage for civilian user profiles, address book contacts, and conversation threads.
class ContactStore {
  static const String _prefProfileKey = 'dtn_user_profile_v1';
  static const String _prefContactsKey = 'dtn_contacts_v1';
  static const String _prefConversationsKey = 'dtn_conversations_v1';
  static const String _prefMessagesKey = 'dtn_chat_messages_v1';

  UserProfile? _myProfile;
  final Map<String, Contact> _contacts = {};
  final Map<String, Conversation> _conversations = {};
  final Map<String, List<ChatMessage>> _messages = {};

  UserProfile get myProfile =>
      _myProfile ??
      UserProfile(
        pubKeyHex: 'pub_alice_ed25519_01',
        username: 'alice',
        displayName: 'Alice Walker',
        bio: 'Civilian Mesh Pioneer 📡 | Always reachable offline',
        avatarSeed: 1,
        nip05Handle: 'alice@mesh.nostr',
        isVerified: true,
      );

  List<Contact> get allContacts => _contacts.values.toList();
  List<Conversation> get allConversations => _conversations.values.toList()
    ..sort((a, b) => b.lastMessageTimeMs.compareTo(a.lastMessageTimeMs));

  List<ChatMessage> getMessages(String conversationId) =>
      _messages[conversationId] ?? [];

  /// Loads profile, contacts, conversations, and messages from device storage
  Future<void> hydrate(String myPubKey) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // 1. Profile
      final rawProfile = prefs.getString(_prefProfileKey);
      if (rawProfile != null && rawProfile.isNotEmpty) {
        _myProfile = UserProfile.fromJson(jsonDecode(rawProfile));
      } else {
        _myProfile = UserProfile(
          pubKeyHex: myPubKey,
          username: 'alice',
          displayName: 'Alice Walker',
          bio: 'Civilian Mesh Pioneer 📡 | Off-grid & private',
          avatarSeed: 1,
          nip05Handle: 'alice@mesh.nostr',
          isVerified: true,
        );
      }

      // 2. Contacts
      final rawContacts = prefs.getString(_prefContactsKey);
      if (rawContacts != null && rawContacts.isNotEmpty) {
        final List<dynamic> list = jsonDecode(rawContacts);
        for (final item in list) {
          final contact = Contact.fromJson(item as Map<String, dynamic>);
          _contacts[contact.pubKeyHex] = contact;
        }
      }

      // 3. Conversations
      final rawConvs = prefs.getString(_prefConversationsKey);
      if (rawConvs != null && rawConvs.isNotEmpty) {
        final List<dynamic> list = jsonDecode(rawConvs);
        for (final item in list) {
          final conv = Conversation.fromJson(item as Map<String, dynamic>);
          _conversations[conv.id] = conv;
        }
      }

      // 4. Messages
      final rawMsgs = prefs.getString(_prefMessagesKey);
      if (rawMsgs != null && rawMsgs.isNotEmpty) {
        final Map<String, dynamic> map = jsonDecode(rawMsgs);
        map.forEach((convId, msgList) {
          if (msgList is List) {
            _messages[convId] = msgList
                .map((m) => ChatMessage.fromJson(m as Map<String, dynamic>))
                .toList();
          }
        });
      }
    } catch (_) {}

    // Seed defaults if empty
    if (_contacts.isEmpty) {
      _seedDefaultContacts();
    }
  }

  void _seedDefaultContacts() {
    final now = DateTime.now().millisecondsSinceEpoch;

    final eve = Contact(
      pubKeyHex: 'pub_eve_ed25519_05',
      username: 'eve_relay',
      displayName: 'Eve (Field Responder)',
      customNickname: 'Eve',
      bio: 'Disaster response volunteer in Sector 4 🚑',
      avatarSeed: 5,
      isSafetyNumberVerified: true,
      lastSeenMs: now - 30000,
      activeTransport: TransportType.lora,
      lastRssi: -82.0,
    );

    final bob = Contact(
      pubKeyHex: 'pub_bob_ed25519_02',
      username: 'bob_radio',
      displayName: 'Bob (Ham Radio Ops)',
      customNickname: 'Bob',
      bio: 'Operating LoRa 915MHz repeater station 📻',
      avatarSeed: 2,
      isSafetyNumberVerified: true,
      lastSeenMs: now - 60000,
      activeTransport: TransportType.ble,
      lastRssi: -65.0,
    );

    final dave = Contact(
      pubKeyHex: 'pub_dave_gtw_04',
      username: 'dave_gateway',
      displayName: 'Dave (Nostr Gateway Hub)',
      customNickname: 'Dave Gateway',
      bio: 'Bridging offline mesh to wss://relay.damus.io 🌐',
      avatarSeed: 4,
      isSafetyNumberVerified: false,
      lastSeenMs: now - 15000,
      activeTransport: TransportType.nostrGateway,
      lastRssi: -50.0,
    );

    _contacts[eve.pubKeyHex] = eve;
    _contacts[bob.pubKeyHex] = bob;
    _contacts[dave.pubKeyHex] = dave;

    // Seed Conversations
    final dmEve = Conversation(
      id: 'dm_pub_eve_ed25519_05',
      title: 'Eve (Field Responder)',
      type: ConversationType.directMessage,
      participantPubKeys: [myProfile.pubKeyHex, eve.pubKeyHex],
      lastMessageText: 'Grid reference #Alpha-04 coordinates logged.',
      lastMessageTimeMs: now - 120000,
      unreadCount: 0,
      avatarSeed: 5,
    );

    final groupRelief = Conversation(
      id: 'group_relief_team',
      title: '🚨 Emergency Relief Team #04',
      type: ConversationType.privateGroup,
      participantPubKeys: [myProfile.pubKeyHex, eve.pubKeyHex, bob.pubKeyHex],
      lastMessageText: 'Bob: Repeater battery at 94% on solar backup.',
      lastMessageTimeMs: now - 60000,
      unreadCount: 2,
      avatarSeed: 7,
      adminPubKey: myProfile.pubKeyHex,
    );

    final channelGlobal = Conversation(
      id: 'channel_broadcast_mesh',
      title: '🌐 #broadcast-mesh (Global Channel)',
      type: ConversationType.publicChannel,
      participantPubKeys: ['all'],
      lastMessageText: 'Welcome to Mesh Messenger DTN!',
      lastMessageTimeMs: now - 300000,
      unreadCount: 0,
      avatarSeed: 9,
    );

    _conversations[dmEve.id] = dmEve;
    _conversations[groupRelief.id] = groupRelief;
    _conversations[channelGlobal.id] = channelGlobal;

    // Seed initial messages for Eve
    _messages[dmEve.id] = [
      ChatMessage(
        id: 'msg_01',
        conversationId: dmEve.id,
        senderPubKey: eve.pubKeyHex,
        senderDisplayName: 'Eve',
        timestampMs: now - 180000,
        isOutgoing: false,
        status: MessageDeliveryStatus.read,
        media: MediaPayload.text('Hey Alice! How is radio coverage over in your sector?'),
      ),
      ChatMessage(
        id: 'msg_02',
        conversationId: dmEve.id,
        senderPubKey: myProfile.pubKeyHex,
        senderDisplayName: 'Alice',
        timestampMs: now - 150000,
        isOutgoing: true,
        status: MessageDeliveryStatus.read,
        media: MediaPayload.text('Strong! Connected to Bob via BLE and LoRa 915MHz.'),
      ),
      ChatMessage(
        id: 'msg_03',
        conversationId: dmEve.id,
        senderPubKey: eve.pubKeyHex,
        senderDisplayName: 'Eve',
        timestampMs: now - 120000,
        isOutgoing: false,
        status: MessageDeliveryStatus.read,
        media: MediaPayload.geoMarker(
          lat: 26.8467,
          lon: 80.9462,
          alt: 125.0,
          label: 'Grid reference #Alpha-04 coordinates logged.',
          emergencySeverity: 1,
        ),
      ),
    ];
  }

  Future<void> saveProfile(UserProfile profile) async {
    _myProfile = profile;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefProfileKey, jsonEncode(profile.toJson()));
  }

  Future<void> addOrUpdateContact(Contact contact) async {
    _contacts[contact.pubKeyHex] = contact;
    await _persistContacts();
  }

  Future<void> addOrUpdateConversation(Conversation conv) async {
    _conversations[conv.id] = conv;
    await _persistConversations();
  }

  Future<void> addMessage(ChatMessage msg) async {
    _messages.putIfAbsent(msg.conversationId, () => []);
    _messages[msg.conversationId]!.add(msg);

    // Update conversation metadata
    if (_conversations.containsKey(msg.conversationId)) {
      final conv = _conversations[msg.conversationId]!;
      conv.lastMessageText = msg.media.textContent.isNotEmpty
          ? msg.media.textContent
          : (msg.media.type == MediaPayloadType.voiceNote ? '🎤 Voice Note' : '📷 Photo');
      conv.lastMessageTimeMs = msg.timestampMs;
      if (!msg.isOutgoing) {
        conv.unreadCount += 1;
      }
    }

    await _persistMessages();
    await _persistConversations();
  }

  void markConversationRead(String conversationId) {
    if (_conversations.containsKey(conversationId)) {
      _conversations[conversationId]!.unreadCount = 0;
      _persistConversations();
    }
  }

  List<Contact> searchContacts(String query) {
    final q = query.toLowerCase().trim();
    if (q.isEmpty) return allContacts;

    return allContacts.where((c) {
      return c.displayName.toLowerCase().contains(q) ||
          c.username.toLowerCase().contains(q) ||
          c.customNickname.toLowerCase().contains(q) ||
          c.pubKeyHex.toLowerCase().contains(q);
    }).toList();
  }

  List<Conversation> searchConversations(String query) {
    final q = query.toLowerCase().trim();
    if (q.isEmpty) return allConversations;

    return allConversations.where((conv) {
      return conv.title.toLowerCase().contains(q) ||
          conv.lastMessageText.toLowerCase().contains(q);
    }).toList();
  }

  Future<void> _persistContacts() async {
    final prefs = await SharedPreferences.getInstance();
    final list = _contacts.values.map((c) => c.toJson()).toList();
    await prefs.setString(_prefContactsKey, jsonEncode(list));
  }

  Future<void> _persistConversations() async {
    final prefs = await SharedPreferences.getInstance();
    final list = _conversations.values.map((c) => c.toJson()).toList();
    await prefs.setString(_prefConversationsKey, jsonEncode(list));
  }

  Future<void> _persistMessages() async {
    final prefs = await SharedPreferences.getInstance();
    final map = <String, dynamic>{};
    _messages.forEach((convId, msgList) {
      map[convId] = msgList.map((m) => m.toJson()).toList();
    });
    await prefs.setString(_prefMessagesKey, jsonEncode(map));
  }

  Future<void> clearAll() async {
    _contacts.clear();
    _conversations.clear();
    _messages.clear();
    _myProfile = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefProfileKey);
    await prefs.remove(_prefContactsKey);
    await prefs.remove(_prefConversationsKey);
    await prefs.remove(_prefMessagesKey);
  }
}
