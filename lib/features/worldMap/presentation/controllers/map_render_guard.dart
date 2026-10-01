import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gate_closes/core/services/storage_service.dart';

/// Whether the map can be shown on this phone.
enum MapRenderStatus {
  /// Show the map (the guard marks the attempt first).
  tryMap,

  /// The last attempt crashed, was killed or never finished loading: show
  /// the "map not supported" notice instead of the map.
  unsupported,
}

/// Detects a phone that can't render the map.
///
/// A native graphics crash can't be caught in Dart, so the guard writes a
/// marker before the map starts and clears it once the map has rendered.
/// If the app dies in between, the marker is still there on the next
/// launch and the map is not started again until the user asks to retry.
class MapRenderGuard extends Notifier<MapRenderStatus> {
  static const _key = 'map_render_pending';

  @override
  MapRenderStatus build() =>
      ref.read(storageServiceProvider).getString(_key) == null
          ? MapRenderStatus.tryMap
          : MapRenderStatus.unsupported;

  /// Call before creating the map; resolves once the marker is saved.
  Future<void> starting() =>
      ref.read(storageServiceProvider).setString(_key, 'pending');

  /// The map rendered and stayed up: this phone can show it.
  Future<void> loaded() => ref.read(storageServiceProvider).remove(_key);

  /// The map didn't finish loading in time. The marker stays, so the next
  /// launch doesn't try again either.
  void failed() => state = MapRenderStatus.unsupported;

  /// The user asked to try the map again.
  Future<void> retry() async {
    await ref.read(storageServiceProvider).remove(_key);
    state = MapRenderStatus.tryMap;
  }
}

final mapRenderGuardProvider =
    NotifierProvider<MapRenderGuard, MapRenderStatus>(MapRenderGuard.new);
