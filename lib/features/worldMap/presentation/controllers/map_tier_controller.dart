import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gate_closes/core/services/storage_service.dart';
import 'package:gate_closes/features/worldMap/data/datasources/device_capabilities_source.dart';
import 'package:gate_closes/features/worldMap/domain/entities/map_tier.dart';

final deviceCapabilitiesSourceProvider = Provider<DeviceCapabilitiesSource>(
  (ref) => const DeviceCapabilitiesSource(),
);

/// The map this phone gets (the device ladder): the 3D map on capable
/// phones, the lite map on weak ones or where the 3D map was measured too
/// slow before. Decided once per app run, before the map is created.
class MapTierController extends AsyncNotifier<MapTier> {
  static const _tooSlowKey = 'map_3d_too_slow';

  @override
  Future<MapTier> build() async {
    final device = await ref.read(deviceCapabilitiesSourceProvider).read();
    final tooSlow =
        ref.read(storageServiceProvider).getString(_tooSlowKey) != null;
    return MapTierPolicy.decide(device, measuredTooSlow: tooSlow);
  }

  /// The 3D map ran too slow here (FrameBudgetMonitor): the lite map from
  /// the next launch, so the map never swaps style under the user.
  Future<void> markTooSlow() =>
      ref.read(storageServiceProvider).setString(_tooSlowKey, 'true');
}

final mapTierControllerProvider =
    AsyncNotifierProvider<MapTierController, MapTier>(MapTierController.new);
