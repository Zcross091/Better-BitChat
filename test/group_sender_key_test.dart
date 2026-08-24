import 'package:flutter_test/flutter_test.dart';
import 'package:mesh_messenger/core/crypto/group_sender_key.dart';

void main() {
  group('Group Sender Keys Cryptography Tests (Signal Ratchet Protocol)', () {
    test('Encrypts group message with forward secrecy ratchet and decrypts on peer node', () async {
      final senderState = GroupSenderKeyEngine.createMySenderKey('group_rescue_01', 'pub_alice_ed25519');
      final peerReceiverState = GroupSenderKeyState.fromJson(senderState.toJson());

      expect(senderState.iteration, equals(0));
      expect(peerReceiverState.iteration, equals(0));

      final plaintext = 'Emergency broadcast to rescue team: Meet at Sector Bravo';
      final encryptedEnvelope = await GroupSenderKeyEngine.encryptGroupMessage(plaintext, senderState);

      // Sender ratchet advanced immediately for forward secrecy
      expect(senderState.iteration, equals(1));

      // Peer decrypts using their replica of the sender state
      final decrypted = await GroupSenderKeyEngine.decryptGroupMessage(encryptedEnvelope, peerReceiverState);
      expect(decrypted, equals(plaintext));
      expect(peerReceiverState.iteration, equals(1));
    });

    test('Handles multiple consecutive messages advancing ratchets progressively', () async {
      final senderState = GroupSenderKeyEngine.createMySenderKey('group_tactical_02', 'pub_bob_ed25519');
      final receiverState = GroupSenderKeyState.fromJson(senderState.toJson());

      final msg1 = await GroupSenderKeyEngine.encryptGroupMessage('Message 1: Checkpoint Alpha clear', senderState);
      final msg2 = await GroupSenderKeyEngine.encryptGroupMessage('Message 2: Advancing to Checkpoint Bravo', senderState);
      final msg3 = await GroupSenderKeyEngine.encryptGroupMessage('Message 3: Bravo secured', senderState);

      expect(senderState.iteration, equals(3));

      expect(await GroupSenderKeyEngine.decryptGroupMessage(msg1, receiverState), equals('Message 1: Checkpoint Alpha clear'));
      expect(await GroupSenderKeyEngine.decryptGroupMessage(msg2, receiverState), equals('Message 2: Advancing to Checkpoint Bravo'));
      expect(await GroupSenderKeyEngine.decryptGroupMessage(msg3, receiverState), equals('Message 3: Bravo secured'));
      expect(receiverState.iteration, equals(3));
    });
  });
}
