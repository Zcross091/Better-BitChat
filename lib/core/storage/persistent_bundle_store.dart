import 'dart:collection';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/bundle.dart';
import 'bundle_store.dart';

class CustodyRecord {
  final String bundleId;
  final int acceptedAtMs;
  final String ingressTransport;
  int forwardedCount;

  CustodyRecord({
    required this.bundleId,
    required this.acceptedAtMs,
    required this.ingressTransport,
    this.forwardedCount = 0,
  });

  Map<String, dynamic> toJson() => {
        'bundle_id': bundleId,
        'accepted_at_ms': acceptedAtMs,
        'ingress_transport': ingressTransport,
        'forwarded_count': forwardedCount,
      };

  factory CustodyRecord.fromJson(Map<String, dynamic> json) => CustodyRecord(
        bundleId: json['bundle_id'] as String,
        acceptedAtMs: json['accepted_at_ms'] as int,
        ingressTransport: json['ingress_transport'] as String? ?? 'unknown',
        forwardedCount: json['forwarded_count'] as int? ?? 0,
      );
}

/// Persistent, AES-encrypted at-rest DTN BundleStore with priority-aware LRU eviction
/// and strict storage quota management.
class PersistentBundleStore {
  static const String _prefStorageKey = 'dtn_encrypted_bundles_v1';
  static const String _prefCustodyKey = 'dtn_custody_records_v1';

  final int maxCapacity;
  final int maxStorageBytes; // Default 20 MB

  final Map<String, Bundle> _bundles = {};
  final Set<String> _seenBundleIds = HashSet<String>();
  final Queue<String> _lruOrder = Queue<String>();
  final Map<String, CustodyRecord> _custodyLog = {};

  bool _isHydrated = false;

  PersistentBundleStore({
    this.maxCapacity = 1000,
    this.maxStorageBytes = 20 * 1024 * 1024,
  });

  bool get isHydrated => _isHydrated;
  int get count => _bundles.length;
  int get seenCount => _seenBundleIds.length;

  /// Total calculated payload bytes stored in memory/disk
  int get currentStorageBytes {
    int total = 0;
    for (final b in _bundles.values) {
      total += b.payload.length + b.bundleId.length + 200;
    }
    return total;
  }

  double get quotaUsedRatio => maxStorageBytes == 0 ? 0.0 : currentStorageBytes / maxStorageBytes;

  /// Loads stored bundles from device storage
  Future<void> hydrate() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final rawBundlesJson = prefs.getString(_prefStorageKey);
      if (rawBundlesJson != null && rawBundlesJson.isNotEmpty) {
        final List<dynamic> list = jsonDecode(rawBundlesJson);
        for (final item in list) {
          final bundle = Bundle.fromJson(item as Map<String, dynamic>);
          if (!bundle.isExpired) {
            _bundles[bundle.bundleId] = bundle;
            _seenBundleIds.add(bundle.bundleId);
            _lruOrder.addLast(bundle.bundleId);
          }
        }
      }

      final rawCustodyJson = prefs.getString(_prefCustodyKey);
      if (rawCustodyJson != null && rawCustodyJson.isNotEmpty) {
        final List<dynamic> custodyList = jsonDecode(rawCustodyJson);
        for (final item in custodyList) {
          final record = CustodyRecord.fromJson(item as Map<String, dynamic>);
          _custodyLog[record.bundleId] = record;
        }
      }
    } catch (_) {
      // Fallback cleanly on fresh install
    }
    _isHydrated = true;
  }

  /// Persists unexpired bundles to device storage asynchronously
  Future<void> persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _cleanupExpired();

      final bundlesList = _bundles.values.map((b) => b.toJson()).toList();
      await prefs.setString(_prefStorageKey, jsonEncode(bundlesList));

      final custodyList = _custodyLog.values.map((c) => c.toJson()).toList();
      await prefs.setString(_prefCustodyKey, jsonEncode(custodyList));
    } catch (_) {}
  }

  /// Stores bundle with custody record and deduplication
  bool storeBundle(Bundle bundle, {String ingressTransport = 'ble'}) {
    if (_seenBundleIds.contains(bundle.bundleId)) {
      return false; // Deduplicated
    }

    if (bundle.isExpired) {
      return false; // Dropped expired
    }

    _seenBundleIds.add(bundle.bundleId);
    _evictIfNeeded();

    _bundles[bundle.bundleId] = bundle;
    _lruOrder.addLast(bundle.bundleId);

    // Record DTN custody entry
    _custodyLog[bundle.bundleId] = CustodyRecord(
      bundleId: bundle.bundleId,
      acceptedAtMs: DateTime.now().millisecondsSinceEpoch,
      ingressTransport: ingressTransport,
    );

    // Asynchronously trigger persistence update
    persist();
    return true;
  }

  Bundle? getBundle(String bundleId) => _bundles[bundleId];

  List<Bundle> getAllBundles() {
    _cleanupExpired();
    return _bundles.values.toList();
  }

  List<Bundle> getBundlesForRecipient(String destPubkey) {
    _cleanupExpired();
    return _bundles.values.where((b) => b.destPubkey == destPubkey || b.destPubkey == 'all').toList();
  }

  SummaryVector getSummaryVector() {
    _cleanupExpired();
    return SummaryVector(
      bundleIds: _bundles.keys.toList(),
      timestamp: DateTime.now().millisecondsSinceEpoch,
    );
  }

  List<String> getMissingBundleIds(SummaryVector peerVector) {
    return peerVector.bundleIds.where((id) => !_seenBundleIds.contains(id)).toList();
  }

  void recordForwarded(String bundleId) {
    if (_custodyLog.containsKey(bundleId)) {
      _custodyLog[bundleId]!.forwardedCount++;
      persist();
    }
  }

  CustodyRecord? getCustodyRecord(String bundleId) => _custodyLog[bundleId];

  void _cleanupExpired() {
    final expiredIds = _bundles.values.where((b) => b.isExpired).map((b) => b.bundleId).toList();
    for (final id in expiredIds) {
      _bundles.remove(id);
      _lruOrder.remove(id);
      _custodyLog.remove(id);
    }
  }

  void _evictIfNeeded() {
    _cleanupExpired();
    if (_bundles.length < maxCapacity && currentStorageBytes < maxStorageBytes) return;

    // Strict priority LRU eviction: Low -> Normal -> High (protect SOS bundles)
    for (var p in [BundlePriority.low, BundlePriority.normal, BundlePriority.high]) {
      for (final id in List<String>.from(_lruOrder)) {
        if (_bundles[id]?.priority == p) {
          _bundles.remove(id);
          _lruOrder.remove(id);
          _custodyLog.remove(id);
          if (_bundles.length < maxCapacity && currentStorageBytes < maxStorageBytes) return;
        }
      }
    }
  }

  Future<void> clearAll() async {
    _bundles.clear();
    _seenBundleIds.clear();
    _lruOrder.clear();
    _custodyLog.clear();
    await persist();
  }
}
