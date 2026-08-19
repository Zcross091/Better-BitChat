import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../models/bundle.dart';
import 'transport_manager.dart';

class NostrGatewayTransport implements TransportDriver {
  final String relayUrl;
  WebSocketChannel? _channel;
  final StreamController<Bundle> _incomingController = StreamController<Bundle>.broadcast();
  bool _connected = false;
  Timer? _reconnectTimer;

  NostrGatewayTransport({this.relayUrl = 'wss://relay.damus.io'});

  @override
  String get name => 'Nostr Internet Gateway ($relayUrl)';

  @override
  TransportType get type => TransportType.nostrGateway;

  @override
  bool get isConnected => _connected;

  @override
  Stream<Bundle> get incomingBundles => _incomingController.stream;

  @override
  Future<void> initialize() async {
    await _connect();
  }

  Future<void> _connect() async {
    try {
      final uri = Uri.parse(relayUrl);
      _channel = WebSocketChannel.connect(uri);
      _connected = true;

      _channel!.stream.listen(
        (data) {
          _handleRelayMessage(data);
        },
        onError: (err) {
          _connected = false;
          _scheduleReconnect();
        },
        onDone: () {
          _connected = false;
          _scheduleReconnect();
        },
      );

      // Subscribe to Mesh Messenger DTN events (Kind 20000 custom bundle event)
      final reqFilter = [
        "REQ",
        "mesh_subscription",
        {
          "kinds": [20000],
          "limit": 50,
        }
      ];
      _channel!.sink.add(jsonEncode(reqFilter));
    } catch (e) {
      _connected = false;
      _scheduleReconnect();
    }
  }

  void _handleRelayMessage(dynamic rawData) {
    try {
      final message = jsonDecode(rawData as String) as List;
      if (message.isEmpty) return;

      final type = message[0] as String;
      if (type == 'EVENT' && message.length >= 3) {
        final event = message[2] as Map<String, dynamic>;
        final content = event['content'] as String;

        // Content contains serialized Bundle JSON payload
        final bundleJson = jsonDecode(content) as Map<String, dynamic>;
        final bundle = Bundle.fromJson(bundleJson);
        _incomingController.add(bundle);
      }
    } catch (_) {
      // Ignore malformed relay events
    }
  }

  @override
  Future<bool> sendBundle(Bundle bundle, {String? targetPeerId}) async {
    if (!_connected || _channel == null) return false;

    try {
      final nostrEvent = [
        "EVENT",
        {
          "kind": 20000,
          "created_at": (DateTime.now().millisecondsSinceEpoch / 1000).round(),
          "tags": [
            ["p", bundle.destPubkey],
            ["b", bundle.bundleId],
          ],
          "content": jsonEncode(bundle.toJson()),
          "pubkey": bundle.senderPubkey,
          "id": bundle.bundleId,
          "sig": bundle.signature.isNotEmpty ? bundle.signature : "00" * 64,
        }
      ];

      _channel!.sink.add(jsonEncode(nostrEvent));
      return true;
    } catch (e) {
      return false;
    }
  }

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 10), () {
      if (!_connected) _connect();
    });
  }

  @override
  Future<void> startDiscovery() async {}

  @override
  Future<void> stopDiscovery() async {}

  @override
  Future<void> dispose() async {
    _reconnectTimer?.cancel();
    await _channel?.sink.close();
    await _incomingController.close();
    _connected = false;
  }
}
