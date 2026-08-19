import 'dart:collection';
import '../models/bundle.dart';

class SummaryVector {
  final List<String> bundleIds;
  final int timestamp;

  SummaryVector({required this.bundleIds, required this.timestamp});

  Map<String, dynamic> toJson() => {
        'bundle_ids': bundleIds,
        'timestamp': timestamp,
      };

  factory SummaryVector.fromJson(Map<String, dynamic> json) {
    return SummaryVector(
      bundleIds: List<String>.from(json['bundle_ids'] as List? ?? []),
      timestamp: json['timestamp'] as int? ?? 0,
    );
  }
}

class BundleStore {
  final int maxCapacity;
  final Map<String, Bundle> _bundles = {};
  final Set<String> _seenBundleIds = HashSet<String>();
  final Queue<String> _lruOrder = Queue<String>();

  BundleStore({this.maxCapacity = 500});

  /// Adds bundle to store if not seen before. Returns true if newly added.
  bool storeBundle(Bundle bundle) {
    if (_seenBundleIds.contains(bundle.bundleId)) {
      return false; // Deduplication: drop existing
    }

    if (bundle.isExpired) {
      return false; // Expired bundle dropped
    }

    _seenBundleIds.add(bundle.bundleId);
    _evictIfNeeded();

    _bundles[bundle.bundleId] = bundle;
    _lruOrder.addLast(bundle.bundleId);
    return true;
  }

  /// Retrieves a specific bundle by ID
  Bundle? getBundle(String bundleId) {
    return _bundles[bundleId];
  }

  /// Returns all valid, unexpired bundles stored
  List<Bundle> getAllBundles() {
    _cleanupExpired();
    return _bundles.values.toList();
  }

  /// Returns bundles addressed to a specific pubkey (or broadcast 'all')
  List<Bundle> getBundlesForRecipient(String destPubkey) {
    _cleanupExpired();
    return _bundles.values.where((b) => b.destPubkey == destPubkey || b.destPubkey == 'all').toList();
  }

  /// Generates light summary vector for peer handshake exchange
  SummaryVector getSummaryVector() {
    _cleanupExpired();
    return SummaryVector(
      bundleIds: _bundles.keys.toList(),
      timestamp: DateTime.now().millisecondsSinceEpoch,
    );
  }

  /// Calculates missing bundles that peer has but we don't have
  List<String> getMissingBundleIds(SummaryVector peerVector) {
    return peerVector.bundleIds.where((id) => !_seenBundleIds.contains(id)).toList();
  }

  /// Marks bundle as seen (for dropping without storing payload if needed)
  void markAsSeen(String bundleId) {
    _seenBundleIds.add(bundleId);
  }

  /// Checks if bundle ID has been seen before
  bool hasSeen(String bundleId) {
    return _seenBundleIds.contains(bundleId);
  }

  int get count => _bundles.length;
  int get seenCount => _seenBundleIds.length;

  void _cleanupExpired() {
    final expiredIds = _bundles.values.where((b) => b.isExpired).map((b) => b.bundleId).toList();
    for (final id in expiredIds) {
      _bundles.remove(id);
      _lruOrder.remove(id);
    }
  }

  void _evictIfNeeded() {
    _cleanupExpired();
    if (_bundles.length < maxCapacity) return;

    // Eviction policy: Remove oldest low priority bundles first, then normal priority
    for (var p in [BundlePriority.low, BundlePriority.normal, BundlePriority.high]) {
      for (final id in List<String>.from(_lruOrder)) {
        if (_bundles[id]?.priority == p) {
          _bundles.remove(id);
          _lruOrder.remove(id);
          if (_bundles.length < maxCapacity) return;
        }
      }
    }
  }

  void clear() {
    _bundles.clear();
    _seenBundleIds.clear();
    _lruOrder.clear();
  }
}
