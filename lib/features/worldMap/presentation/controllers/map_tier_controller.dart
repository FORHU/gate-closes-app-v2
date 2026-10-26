import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gate_closes/core/services/storage_service.dart';
import 'package:gate_closes/features/worldMap/data/datasources/device_capabilities_source.dart';
import 'package:gate_closes/features/worldMap/domain/entities/map_tier.dart';

final deviceCapabilitiesSourceProvider = Provider<DeviceCapabilitiesSource>(
  (ref) => const DeviceCapabilitiesSource(),
);

/// Whether the user turned the 3D map on (Settings). Off by default: the
/// map is 2D on every phone.
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

/// The map this phone gets (the device ladder): the 2D lite map unless the
/// user turned 3D on, and then the 3D map only on capable phones where it
/// wasn't measured too slow before. Decided once per app run, before the
/// map is created, so turning 3D on or off applies from the next launch.
class MapTierController extends AsyncNotifier<MapTier> {
  static const _tooSlowKey = 'map_3d_too_slow';

  @override
  Future<MapTier> build() async {
    final device = await ref.read(deviceCapabilitiesSourceProvider).read();
    final tooSlow =
        ref.read(storageServiceProvider).getString(_tooSlowKey) != null;
    return MapTierPolicy.decide(
      device,
      wants3d: ref.read(map3dEnabledProvider),
      measuredTooSlow: tooSlow,
    );
  }

  /// The 3D map ran too slow here (FrameBudgetMonitor): the lite map from
  /// the next launch, so the map never swaps style under the user.
  Future<void> markTooSlow() =>
      ref.read(storageServiceProvider).setString(_tooSlowKey, 'true');
}

final mapTierControllerProvider =
    AsyncNotifierProvider<MapTierController, MapTier>(MapTierController.new);
