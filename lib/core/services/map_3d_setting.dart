import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gate_closes/core/services/device_capabilities_source.dart';
import 'package:gate_closes/core/services/map_tier.dart';
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

/// Set once the 3D map ran too slow on this phone (FrameBudgetMonitor).
const map3dTooSlowKey = 'map_3d_too_slow';

/// Why this phone can't run the 3D map, or null when it can: the same
/// device ladder the map uses, so Settings can say so instead of offering
/// a switch that does nothing.
final no3dReasonProvider = FutureProvider<No3dReason?>((ref) async {
  final device = await ref.read(deviceCapabilitiesSourceProvider).read();
  return MapTierPolicy.why3dUnavailable(
    device,
    measuredTooSlow:
        ref.read(storageServiceProvider).getString(map3dTooSlowKey) != null,
  );
});
