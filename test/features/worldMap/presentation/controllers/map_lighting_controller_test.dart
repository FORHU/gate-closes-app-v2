import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gate_closes/core/services/storage_service.dart';
import 'package:gate_closes/features/worldMap/presentation/controllers/map_lighting_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('realtime: dusk through the day (5 to 19), night after dark', () {
    MapTimeOfDay at(int hour) => MapTimeOfDay.at(DateTime(2026, 9, 29, hour));

    expect(at(4), MapTimeOfDay.night);
    expect(at(5), MapTimeOfDay.dusk);
    expect(at(12), MapTimeOfDay.dusk);
    expect(at(18), MapTimeOfDay.dusk);
    expect(at(19), MapTimeOfDay.night);
    expect(at(23), MapTimeOfDay.night);
  });

  test('static mode ignores the clock', () {
    const lighting = MapLightingState(
      mode: MapLightingMode.fixed,
      fixedPreset: MapTimeOfDay.dawn,
    );
    expect(lighting.presetAt(DateTime(2026, 9, 29, 23)), MapTimeOfDay.dawn);
  });

  test('defaults to realtime + dusk, and remembers changes', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    ProviderContainer container() => ProviderContainer(
          overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        );

    final first = container();
    expect(first.read(mapLightingControllerProvider), const MapLightingState());
    await first
        .read(mapLightingControllerProvider.notifier)
        .setMode(MapLightingMode.fixed);
    await first
        .read(mapLightingControllerProvider.notifier)
        .setFixedPreset(MapTimeOfDay.night);
    first.dispose();

    final second = container();
    expect(
      second.read(mapLightingControllerProvider),
      const MapLightingState(
        mode: MapLightingMode.fixed,
        fixedPreset: MapTimeOfDay.night,
      ),
    );
    second.dispose();
  });
}
