import 'package:flutter_test/flutter_test.dart';
import 'package:gate_closes/features/worldMap/domain/entities/echo_map_features.dart';
import 'package:gate_closes/features/worldMap/domain/entities/echo_map_node_entity.dart';

TerminalEchoMapNodeEntity node({
  EchoNodeKind kind = EchoNodeKind.terminalEcho,
  int replies = 0,
  int reactions = 0,
  int listens = 0,
  DateTime? createdAt,
  DateTime? expiresAt,
  bool isNew = false,
}) =>
    TerminalEchoMapNodeEntity(
      id: 'e1',
      senderId: '',
      nodeKind: kind,
      latitude: 14.5,
      longitude: 121,
      replyCount: replies,
      reactionCount: reactions,
      listenCount: listens,
      createdAt: createdAt,
      expiresAt: expiresAt,
      isNew: isNew,
    );

void main() {
  final now = DateTime(2026, 9, 29, 12);

  group('freshnessScore (Expo getEchoFreshness)', () {
    test('new: flagged, or created within 20 minutes', () {
      expect(EchoMapFeatures.freshnessScore(node(isNew: true), now), 2);
      expect(
        EchoMapFeatures.freshnessScore(
          node(createdAt: now.subtract(const Duration(minutes: 19))),
          now,
        ),
        2,
      );
    });

    test('fading: expires within 45 minutes', () {
      expect(
        EchoMapFeatures.freshnessScore(
          node(
            createdAt: now.subtract(const Duration(hours: 5)),
            expiresAt: now.add(const Duration(minutes: 30)),
          ),
          now,
        ),
        0,
      );
    });

    test('active otherwise', () {
      expect(EchoMapFeatures.freshnessScore(node(), now), 1);
    });
  });

  test('activityScore thresholds (Expo getEchoActivityLevel)', () {
    expect(EchoMapFeatures.activityScore(node()), 0);
    expect(EchoMapFeatures.activityScore(node(replies: 1)), 1);
    expect(EchoMapFeatures.activityScore(node(reactions: 2)), 1);
    expect(EchoMapFeatures.activityScore(node(listens: 8)), 1);
    expect(EchoMapFeatures.activityScore(node(replies: 3)), 2);
    expect(EchoMapFeatures.activityScore(node(reactions: 5)), 2);
    expect(EchoMapFeatures.activityScore(node(listens: 20)), 2);
  });

  test('collection: point features with the type used for badges', () {
    final fc = EchoMapFeatures.collection(
      [node(kind: EchoNodeKind.batonTouch, reactions: 5)],
      now: now,
    );
    final feature = (fc['features'] as List).single as Map;

    expect(fc['type'], 'FeatureCollection');
    expect(feature['id'], 'e1');
    expect(feature['geometry'], {
      'type': 'Point',
      'coordinates': [121.0, 14.5],
    });
    expect(feature['properties'], {
      'id': 'e1',
      'type': 'baton_touch',
      'freshnessScore': 1,
      'activityScore': 2,
      'replyCount': 0,
      'listenCount': 0,
      'reactionCount': 5,
    });
  });

  test('cache round-trip keeps createdAt and counts', () {
    final created = DateTime.utc(2026, 9, 29, 11, 50);
    final fc = EchoMapFeatures.collection(
      [node(createdAt: created, listens: 20, reactions: 2, replies: 1)],
      now: now,
    );
    final restored = TerminalEchoMapNodeEntity.fromGeoJsonFeature(
      ((fc['features'] as List).single as Map).cast<String, dynamic>(),
    );

    expect(restored.createdAt, created);
    expect(restored.listenCount, 20);
    expect(restored.reactionCount, 2);
    expect(restored.replyCount, 1);
  });
}
