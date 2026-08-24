import 'dart:math';
import '../models/bundle.dart';

class ProphetRouter {
  static const double pInit = 0.75;
  static const double beta = 0.25;
  static const double gamma = 0.98;

  // Delivery predictability scores P(myNode, destinationNode)
  final Map<String, double> _predictabilityScores = {};
  final Map<String, int> _lastEncounterTimes = {};

  /// Records an encounter with peer node `peerId`
  void recordEncounter(String peerId) {
    _decayScores(peerId);

    final currentScore = _predictabilityScores[peerId] ?? 0.0;
    final newScore = currentScore + (1 - currentScore) * pInit;
    _predictabilityScores[peerId] = min(1.0, newScore);
    _lastEncounterTimes[peerId] = DateTime.now().millisecondsSinceEpoch;
  }

  /// Updates transitive predictability scores given peer's predictability vector
  void updateTransitivePredictability(String peerId, Map<String, double> peerVector) {
    final pMyPeer = getPredictability(peerId);

    peerVector.forEach((destId, pPeerDest) {
      if (destId == peerId) return;

      final current = getPredictability(destId);
      final transitiveInc = (1 - current) * pMyPeer * pPeerDest * beta;
      _predictabilityScores[destId] = min(1.0, current + transitiveInc);
    });
  }

  /// Returns delivery predictability score for reaching `destId`
  double getPredictability(String destId) {
    _decayScores(destId);
    return _predictabilityScores[destId] ?? 0.0;
  }

  /// Sorts bundles to prioritize forwarding higher priority & higher PRoPHET likelihood
  List<Bundle> prioritizeBundlesForForwarding(List<Bundle> candidateBundles, String peerId, bool isPeerGateway) {
    final list = List<Bundle>.from(candidateBundles);

    list.sort((a, b) {
      // 1. High priority first
      if (a.priority.index != b.priority.index) {
        return b.priority.index.compareTo(a.priority.index);
      }

      // 2. If peer is gateway, forward any non-local bundle with high urgency
      if (isPeerGateway) {
        return a.createdAt.compareTo(b.createdAt);
      }

      // 3. PRoPHET predictability score comparison
      final pA = getPredictability(a.destPubkey);
      final pB = getPredictability(b.destPubkey);
      if ((pA - pB).abs() > 0.05) {
        return pB.compareTo(pA); // Higher predictability first
      }

      // 4. Lower hop count first to favor direct routes
      return a.hopCount.compareTo(b.hopCount);
    });

    return list;
  }

  Map<String, double> getPredictabilityMap() {
    return Map.unmodifiable(_predictabilityScores);
  }

  /// Alias returning full map of peer delivery predictabilities
  Map<String, double> getAllPredictabilities() {
    return getPredictabilityMap();
  }

  /// Resets encounter and predictability history (for panic wipe)
  void reset() {
    _predictabilityScores.clear();
    _lastEncounterTimes.clear();
  }

  void _decayScores(String nodeKey) {
    final lastTime = _lastEncounterTimes[nodeKey];
    if (lastTime == null) return;

    final now = DateTime.now().millisecondsSinceEpoch;
    final timePassedMinutes = (now - lastTime) / (1000 * 60);

    if (timePassedMinutes >= 1.0) {
      final k = timePassedMinutes.floor();
      final current = _predictabilityScores[nodeKey] ?? 0.0;
      _predictabilityScores[nodeKey] = current * pow(gamma, k);
      _lastEncounterTimes[nodeKey] = now;
    }
  }
}
