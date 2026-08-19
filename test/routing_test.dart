import 'package:flutter_test/flutter_test.dart';
import 'package:mesh_messenger/core/routing/prophet_router.dart';
import 'package:mesh_messenger/core/models/bundle.dart';

void main() {
  group('PRoPHET Routing Unit Tests', () {
    test('Encounter increases delivery predictability score', () {
      final router = ProphetRouter();
      const peerId = 'peer_node_01';

      expect(router.getPredictability(peerId), equals(0.0));

      router.recordEncounter(peerId);
      final score1 = router.getPredictability(peerId);
      expect(score1, greaterThan(0.0));

      router.recordEncounter(peerId);
      final score2 = router.getPredictability(peerId);
      expect(score2, greaterThan(score1));
    });

    test('Prioritizes emergency high priority bundles first', () {
      final router = ProphetRouter();
      final lowBundle = Bundle(
        bundleId: 'b_low',
        senderPubkey: 'a',
        destPubkey: 'b',
        createdAt: 100,
        ttlHours: 24,
        hopCount: 0,
        priority: BundlePriority.low,
        payload: 'low',
        signature: 's',
      );

      final highBundle = Bundle(
        bundleId: 'b_high',
        senderPubkey: 'a',
        destPubkey: 'b',
        createdAt: 100,
        ttlHours: 24,
        hopCount: 0,
        priority: BundlePriority.high,
        payload: 'high',
        signature: 's',
      );

      final prioritized = router.prioritizeBundlesForForwarding([lowBundle, highBundle], 'peer_b', false);

      expect(prioritized.first.bundleId, equals('b_high'));
    });
  });
}
