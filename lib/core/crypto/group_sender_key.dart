import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:cryptography/cryptography.dart' as crypto;

/// Ratcheting Sender Key state for Signal-style group encryption with forward secrecy.
/// Allows a node to broadcast to a group (e.g., #emergency-mesh) encrypting once,
/// while all group members with the sender's chain key can decrypt.
class GroupSenderKeyState {
  final String groupId;
  final String senderPubkey;
  int iteration;
  List<int> chainKey;
  final List<int> signingKey;

  GroupSenderKeyState({
    required this.groupId,
    required this.senderPubkey,
    required this.iteration,
    required this.chainKey,
    required this.signingKey,
  });

  /// Advances ratchet chain key by one step: K_{i+1} = HMAC-SHA256(K_i, "GroupRatchetStep")
  void advanceRatchet() {
    final hmac = Hmac(sha256, chainKey);
    final nextChainKey = hmac.convert(utf8.encode('GroupRatchetStep_${iteration + 1}')).bytes;
    chainKey = nextChainKey;
    iteration += 1;
  }

  /// Derives symmetric message encryption key: K_msg = HMAC-SHA256(K_i, "GroupMessageKey")
  List<int> deriveMessageKey() {
    final hmac = Hmac(sha256, chainKey);
    return hmac.convert(utf8.encode('GroupMessageKey_$iteration')).bytes;
  }

  Map<String, dynamic> toJson() => {
        'group_id': groupId,
        'sender_pubkey': senderPubkey,
        'iteration': iteration,
        'chain_key_hex': chainKey.map((b) => b.toRadixString(16).padLeft(2, '0')).join(),
        'signing_key_hex': signingKey.map((b) => b.toRadixString(16).padLeft(2, '0')).join(),
      };

  factory GroupSenderKeyState.fromJson(Map<String, dynamic> json) {
    List<int> hexToBytes(String hex) {
      final res = <int>[];
      for (var i = 0; i < hex.length; i += 2) {
        res.add(int.parse(hex.substring(i, i + 2), radix: 16));
      }
      return res;
    }

    return GroupSenderKeyState(
      groupId: json['group_id'] as String,
      senderPubkey: json['sender_pubkey'] as String,
      iteration: json['iteration'] as int,
      chainKey: hexToBytes(json['chain_key_hex'] as String),
      signingKey: hexToBytes(json['signing_key_hex'] as String),
    );
  }
}

class GroupSenderKeyEngine {
  static final _chacha20 = crypto.Chacha20.poly1305Aead();

  /// Generates a new fresh GroupSenderKeyState for this node to broadcast to a group
  static GroupSenderKeyState createMySenderKey(String groupId, String myPubkey) {
    final rng = Random.secure();
    final chainKey = List<int>.generate(32, (_) => rng.nextInt(256));
    final signingKey = List<int>.generate(32, (_) => rng.nextInt(256));

    return GroupSenderKeyState(
      groupId: groupId,
      senderPubkey: myPubkey,
      iteration: 0,
      chainKey: chainKey,
      signingKey: signingKey,
    );
  }

  /// Encrypts plaintext using current ratchet state and immediately advances ratchet (Forward Secrecy)
  static Future<String> encryptGroupMessage(
    String plaintext,
    GroupSenderKeyState senderState,
  ) async {
    final messageKeyBytes = senderState.deriveMessageKey();
    final secretKey = crypto.SecretKey(messageKeyBytes);

    final rng = Random.secure();
    final nonce = List<int>.generate(12, (_) => rng.nextInt(256));

    final secretBox = await _chacha20.encrypt(
      utf8.encode(plaintext),
      secretKey: secretKey,
      nonce: nonce,
    );

    // Header prefix includes iteration count so receivers can advance their ratchet if needed
    final envelope = {
      'group_id': senderState.groupId,
      'iteration': senderState.iteration,
      'nonce': base64.encode(nonce),
      'ciphertext': base64.encode(secretBox.cipherText),
      'mac': base64.encode(secretBox.mac.bytes),
    };

    // Advance ratchet immediately so past messages cannot be decrypted if current key is stolen
    senderState.advanceRatchet();

    return jsonEncode(envelope);
  }

  /// Decrypts a group ciphertext message using the sender's stored GroupSenderKeyState
  static Future<String> decryptGroupMessage(
    String envelopeJson,
    GroupSenderKeyState peerSenderState,
  ) async {
    try {
      final envelope = jsonDecode(envelopeJson) as Map<String, dynamic>;
      final targetIteration = envelope['iteration'] as int;

      // Fast-forward ratchet if peer sent multiple messages
      while (peerSenderState.iteration < targetIteration) {
        peerSenderState.advanceRatchet();
      }

      final messageKeyBytes = peerSenderState.deriveMessageKey();
      final secretKey = crypto.SecretKey(messageKeyBytes);

      final nonce = base64.decode(envelope['nonce'] as String);
      final cipherText = base64.decode(envelope['ciphertext'] as String);
      final macBytes = base64.decode(envelope['mac'] as String);

      final secretBox = crypto.SecretBox(
        cipherText,
        nonce: nonce,
        mac: crypto.Mac(macBytes),
      );

      final decryptedBytes = await _chacha20.decrypt(secretBox, secretKey: secretKey);
      
      // Advance ratchet after successful decryption to preserve forward secrecy
      peerSenderState.advanceRatchet();

      return utf8.decode(decryptedBytes);
    } catch (_) {
      return '[Group Decryption Error: Ratchet Mismatch or Corrupted Payload]';
    }
  }
}
