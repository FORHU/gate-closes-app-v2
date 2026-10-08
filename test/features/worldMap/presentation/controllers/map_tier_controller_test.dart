import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gate_closes/core/services/storage_service.dart';
import 'package:gate_closes/features/worldMap/data/datasources/device_capabilities_source.dart';
import 'package:gate_closes/features/worldMap/domain/entities/map_tier.dart';
import 'package:gate_closes/features/worldMap/presentation/controllers/map_tier_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Device implements DeviceCapabilitiesSource {
  const _Device(this.capabilities);

  final DeviceCapabilities capabilities;

  @override
  Future<DeviceCapabilities> read() async => capabilities;
}

void main() {
  const strong = DeviceCapabilities(
    is64Bit: true,
    totalRamMb: 7300,
    lowRam: false,
    sdk: 33,
  );
  const weak = DeviceCapabilities(
    is64Bit: true,
    totalRamMb: 3000,
    lowRam: false,
    sdk: 33,
  );

  Future<ProviderContainer> container(DeviceCapabilities device) async {
    final prefs = await SharedPreferences.getInstance();
    return ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        deviceCapabilitiesSourceProvider.overrideWithValue(_Device(device)),
      ],
    );
  }

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('a strong phone gets the 3D map, a weak one the lite map', () async {
    final a = await container(strong);
    final b = await container(weak);
    expect(await a.read(mapTierControllerProvider.future), MapTier.standard);
    expect(await b.read(mapTierControllerProvider.future), MapTier.lite);
    a.dispose();
    b.dispose();
  });

  test('measured too slow: the lite map from the next launch on', () async {
    final first = await container(strong);
    expect(
      await first.read(mapTierControllerProvider.future),
      MapTier.standard,
    );
    await first.read(mapTierControllerProvider.notifier).markTooSlow();
    // This run keeps its map; the next one is lite.
    expect(
      await first.read(mapTierControllerProvider.future),
      MapTier.standard,
    );
    first.dispose();

    final next = await container(strong);
    expect(await next.read(mapTierControllerProvider.future), MapTier.lite);
    next.dispose();
  });
}
