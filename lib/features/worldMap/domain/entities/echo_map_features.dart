import 'package:gate_closes/features/worldMap/domain/entities/echo_map_node_entity.dart';

/// Builds the GeoJSON the map's pin source renders, with the same per-pin
/// scores the Expo map uses (`TerminalMapNodesLayer.tsx`) to weight its
/// activity heatmap.
abstract final class EchoMapFeatures {
  /// An echo younger than this is "new".
  static const newMaxAge = Duration(minutes: 20);

  /// An echo expiring within this is "fading".
  static const fadingTimeLeft = Duration(minutes: 45);

  /// API type key per kind — also the badge lookup key in the symbol layer.
  static String typeKey(EchoNodeKind kind) => switch (kind) {
        EchoNodeKind.terminalEcho => 'terminal_echo',
        EchoNodeKind.parallelSoul => 'parallel_soul',
        EchoNodeKind.destinationThread => 'destination_thread',
        EchoNodeKind.batonTouch => 'baton_touch',
      };

  /// 2 new · 1 active · 0 fading.
  static int freshnessScore(TerminalEchoMapNodeEntity node, DateTime now) {
    final created = node.createdAt;
    if (node.isNew ||
        (created != null && now.difference(created) <= newMaxAge)) {
      return 2;
    }
    final expires = node.expiresAt;
    if (expires != null && expires.difference(now) <= fadingTimeLeft) return 0;
    return 1;
  }

  /// 2 high · 1 medium · 0 low, from replies, reactions and listens.
  static int activityScore(TerminalEchoMapNodeEntity node) {
    if (node.replyCount >= 3 ||
        node.reactionCount >= 5 ||
        node.listenCount >= 20) {
      return 2;
    }
    if (node.replyCount >= 1 ||
        node.reactionCount >= 2 ||
        node.listenCount >= 8) {
      return 1;
    }
    return 0;
  }

  static Map<String, dynamic> collection(
    List<TerminalEchoMapNodeEntity> nodes, {
    DateTime? now,
  }) {
    final at = now ?? DateTime.now();
    return {
      'type': 'FeatureCollection',
      'features': [for (final node in nodes) feature(node, at)],
    };
  }

  /// One pin's feature, at the echo's own position unless [lng]/[lat] move
  /// it (EchoBeacons spreads echoes that share one spot).
  static Map<String, dynamic> feature(
    TerminalEchoMapNodeEntity node,
    DateTime at, {
    double? lng,
    double? lat,
  }) =>
      {
        'type': 'Feature',
        'id': node.id,
        'geometry': {
          'type': 'Point',
          'coordinates': [lng ?? node.longitude, lat ?? node.latitude],
        },
        'properties': {
          'id': node.id,
          'type': typeKey(node.nodeKind),
          'freshnessScore': freshnessScore(node, at),
          'activityScore': activityScore(node),
          // Raw fields, so the offline cache restores them intact.
          if (node.createdAt != null)
            'createdAt': node.createdAt!.toIso8601String(),
          'replyCount': node.replyCount,
          'listenCount': node.listenCount,
          'reactionCount': node.reactionCount,
        },
      };
}
