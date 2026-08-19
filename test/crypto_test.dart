import 'package:flutter_test/flutter_test.dart';
import 'package:mesh_messenger/core/crypto/crypto_engine.dart';

void main() {
  group('Cryptography Engine Unit Tests', () {
    test('Ed25519 KeyPair generation creates 64-char hex pubKey', () async {
      final keyPair = await CryptoEngine.generateKeyPair();
      expect(keyPair.publicKeyHex.length, equals(64));
      expect(keyPair.privateKeyHex.length, equals(64));
    });

    test('Data signing and signature verification succeeds', () async {
      final keyPair = await CryptoEngine.generateKeyPair();
      final data = [1, 2, 3, 4, 5, 6, 7, 8];

      final signature = await CryptoEngine.signData(data, keyPair.privateKeyHex);
      final isValid = await CryptoEngine.verifySignature(data, signature, keyPair.publicKeyHex);

      expect(isValid, isTrue);
    });

    test('Safety Number derivation is deterministic for two public keys', () {
      const pubA = '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';
      const pubB = 'fedcba9876543210fedcba9876543210fedcba9876543210fedcba9876543210';

      final num1 = CryptoEngine.computeSafetyNumber(pubA, pubB);
      final num2 = CryptoEngine.computeSafetyNumber(pubB, pubA);

      expect(num1, equals(num2)); // Commutative property
      expect(num1.split(' ').length, equals(4)); // 4 groups of 5 digits
    });
  });
}
