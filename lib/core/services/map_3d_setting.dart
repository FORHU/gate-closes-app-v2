import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gate_closes/core/services/storage_service.dart';

/// Whether the user turned the 3D map on (Settings). Off by default: the
/// map is 2D on every phone. In core because Settings (profile) sets it
/// and the map (worldMap) reads it.
class Map3dEnabled extends Notifier<bool> {
  static const _key = 'map_3d_on';

  @override
  bool build() => ref.read(storageServiceProvider).getString(_key) == 'true';

  Future<void> set({required bool on}) async {
    state = on;
    await ref.read(storageServiceProvider).setString(_key, '$on');
  }
}

final map3dEnabledProvider =
    NotifierProvider<Map3dEnabled, bool>(Map3dEnabled.new);
