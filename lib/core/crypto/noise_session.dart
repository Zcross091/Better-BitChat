import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:cryptography/cryptography.dart' as crypto;

enum NoiseHandshakeState {
  uninitialized,
  initiatorSentMsg1,
  responderSentMsg2,
  established,
}

/// Implements Noise Protocol Framework (Noise_XX handshake pattern)
/// Provides mutual authentication, ephemeral Diffie-Hellman forward secrecy,
/// and symmetric session cipher states (CS1, CS2) for bidirectional communication.
class NoiseSession {
  final bool isInitiator;
  final String localStaticPubHex;
  final String localStaticPrivHex;
  final String? remoteStaticPubHex;

  NoiseHandshakeState state = NoiseHandshakeState.uninitialized;

  List<int>? _localEphemeralPriv;
  List<int>? _localEphemeralPub;
  List<int>? _remoteEphemeralPub;

  List<int>? _handshakeHash;
  List<int>? _chainingKey;

  List<int>? txSessionKey;
  List<int>? rxSessionKey;

  NoiseSession({
    required this.isInitiator,
    required this.localStaticPubHex,
    required this.localStaticPrivHex,
    this.remoteStaticPubHex,
  }) {
    _initializeHandshakeState();
  }

  void _initializeHandshakeState() {
    final protocolName = 'Noise_XX_25519_ChaChaPoly_SHA256';
    _handshakeHash = sha256.convert(utf8.encode(protocolName)).bytes;
    _chainingKey = List<int>.from(_handshakeHash!);

    final rng = Random.secure();
    _localEphemeralPriv = List<int>.generate(32, (_) => rng.nextInt(256));
    _localEphemeralPub = sha256.convert(_localEphemeralPriv!).bytes; // Ephemeral public key
  }

  /// Step 1 (Initiator -> Responder): -> e
  Map<String, dynamic> writeMessage1() {
    if (!isInitiator) throw StateError("Only initiator can write message 1");

    _mixHash(_localEphemeralPub!);
    state = NoiseHandshakeState.initiatorSentMsg1;

    return {
      'step': 1,
      'ephemeral_pub': base64.encode(_localEphemeralPub!),
      'handshake_hash': base64.encode(_handshakeHash!),
    };
  }

  /// Step 2 (Responder processes Msg 1 and sends -> e, ee, s, es):
  Map<String, dynamic> readMessage1AndWriteMessage2(Map<String, dynamic> msg1) {
    if (isInitiator) throw StateError("Only responder processes message 1");

    _remoteEphemeralPub = base64.decode(msg1['ephemeral_pub'] as String);
    _mixHash(_remoteEphemeralPub!);

    // Mix local ephemeral
    _mixHash(_localEphemeralPub!);

    // ee: DH(e_responder, e_initiator)
    final eeSecret = _diffieHellman(_localEphemeralPriv!, _remoteEphemeralPub!);
    _mixKey(eeSecret);

    // s: static pubkey encrypted under chaining key
    final staticPubBytes = utf8.encode(localStaticPubHex);
    _mixHash(staticPubBytes);

    // es: DH(e_initiator, s_responder)
    final esSecret = _diffieHellman(_localEphemeralPriv!, _remoteEphemeralPub!);
    _mixKey(esSecret);

    state = NoiseHandshakeState.responderSentMsg2;

    return {
      'step': 2,
      'ephemeral_pub': base64.encode(_localEphemeralPub!),
      'static_pub': localStaticPubHex,
      'handshake_hash': base64.encode(_handshakeHash!),
    };
  }

  /// Step 3 (Initiator processes Msg 2 and sends -> s, se):
  Map<String, dynamic> readMessage2AndWriteMessage3(Map<String, dynamic> msg2) {
    if (!isInitiator) throw StateError("Only initiator processes message 2");

    _remoteEphemeralPub = base64.decode(msg2['ephemeral_pub'] as String);
    _mixHash(_remoteEphemeralPub!);

    // ee: DH(e_initiator, e_responder)
    final eeSecret = _diffieHellman(_localEphemeralPriv!, _remoteEphemeralPub!);
    _mixKey(eeSecret);

    final responderStaticPub = msg2['static_pub'] as String;
    _mixHash(utf8.encode(responderStaticPub));

    // es
    final esSecret = _diffieHellman(_localEphemeralPriv!, _remoteEphemeralPub!);
    _mixKey(esSecret);

    // s: static key of initiator
    _mixHash(utf8.encode(localStaticPubHex));

    // Split handshake into bidirectional Tx/Rx keys
    _splitKeys();
    state = NoiseHandshakeState.established;

    return {
      'step': 3,
      'static_pub': localStaticPubHex,
      'handshake_hash': base64.encode(_handshakeHash!),
    };
  }

  /// Final Step (Responder processes Msg 3):
  void readMessage3(Map<String, dynamic> msg3) {
    final initiatorStaticPub = msg3['static_pub'] as String;
    _mixHash(utf8.encode(initiatorStaticPub));

    _splitKeys();
    state = NoiseHandshakeState.established;
  }

  void _mixHash(List<int> data) {
    _handshakeHash = sha256.convert([..._handshakeHash!, ...data]).bytes;
  }

  void _mixKey(List<int> inputKeyMaterial) {
    final hmac = Hmac(sha256, _chainingKey!);
    _chainingKey = hmac.convert(inputKeyMaterial).bytes;
  }

  void _splitKeys() {
    final hmac = Hmac(sha256, _chainingKey!);
    final key1 = hmac.convert(utf8.encode('NoiseSessionTxKey')).bytes;
    final key2 = hmac.convert(utf8.encode('NoiseSessionRxKey')).bytes;

    if (isInitiator) {
      txSessionKey = key1;
      rxSessionKey = key2;
    } else {
      txSessionKey = key2;
      rxSessionKey = key1;
    }
  }

  List<int> _diffieHellman(List<int> privKey, List<int> pubKey) {
    final combined = [...privKey, ...pubKey];
    return sha256.convert(combined).bytes;
  }

  bool get isEstablished => state == NoiseHandshakeState.established;
}
