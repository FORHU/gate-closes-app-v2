import 'dart:ui';

import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gate_closes/core/services/storage_service.dart';

/// How the map's time-of-day lighting is chosen (Expo `MapLightingMode`).
enum MapLightingMode { realtime, fixed }

/// Expo's `MapTimeOfDayPreset`.
enum MapTimeOfDay {
  dawn,
  day,
  dusk,
  night;

  /// Realtime lighting (device local time): dusk through the day, 5–19,
  /// for the map's formal look, and night after dark. Dawn and day stay
  /// available as fixed presets.
  static MapTimeOfDay at(DateTime time) {
    final h = time.hour;
    return h >= 5 && h < 19 ? MapTimeOfDay.dusk : MapTimeOfDay.night;
  }

  /// The atmosphere tint Expo's `CentralMapCanvas` lays over the map for
  /// this preset (its lighting is this overlay; the dark-v11 base map has no
  /// light presets of its own).
  Color get tint => switch (this) {
        MapTimeOfDay.dusk => const Color.fromRGBO(120, 62, 25, 0.16),
        MapTimeOfDay.night => const Color.fromRGBO(4, 9, 26, 0.38),
        MapTimeOfDay.dawn => const Color.fromRGBO(236, 159, 88, 0.12),
        MapTimeOfDay.day => const Color.fromRGBO(255, 218, 145, 0.06),
      };
}

class MapLightingState extends Equatable {
  const MapLightingState({
    this.mode = MapLightingMode.realtime,
    this.fixedPreset = MapTimeOfDay.dusk,
  });

  final MapLightingMode mode;

  /// Used when [mode] is [MapLightingMode.fixed] (Expo default: dusk).
  final MapTimeOfDay fixedPreset;

  MapTimeOfDay presetAt(DateTime time) =>
      mode == MapLightingMode.fixed ? fixedPreset : MapTimeOfDay.at(time);

  @override
  List<Object?> get props => [mode, fixedPreset];
}

/// The Map Lighting setting, persisted on the device (Expo
/// `preferencesStore`).
class MapLightingController extends Notifier<MapLightingState> {
  static const _modeKey = 'map_lighting_mode';
  static const _presetKey = 'map_lighting_preset';

  @override
  MapLightingState build() {
    final storage = ref.read(storageServiceProvider);
    return MapLightingState(
      mode: MapLightingMode.values.asNameMap()[storage.getString(_modeKey)] ??
          MapLightingMode.realtime,
      fixedPreset:
          MapTimeOfDay.values.asNameMap()[storage.getString(_presetKey)] ??
              MapTimeOfDay.dusk,
    );
  }

  Future<void> setMode(MapLightingMode mode) async {
    state = MapLightingState(mode: mode, fixedPreset: state.fixedPreset);
    await ref.read(storageServiceProvider).setString(_modeKey, mode.name);
  }

  Future<void> setFixedPreset(MapTimeOfDay preset) async {
    state = MapLightingState(mode: state.mode, fixedPreset: preset);
    await ref.read(storageServiceProvider).setString(_presetKey, preset.name);
  }
}

final mapLightingControllerProvider =
    NotifierProvider<MapLightingController, MapLightingState>(
  MapLightingController.new,
);
