import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:gate_closes/core/services/connectivity_service.dart';
import 'package:gate_closes/core/services/storage_service.dart';
import 'package:gate_closes/features/worldMap/data/datasources/map_disk_cache.dart';
import 'package:gate_closes/features/worldMap/data/datasources/map_echo_socket.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// In-memory [MapDiskCache] for tests (no path_provider / file system).
class MemoryMapDiskCache implements MapDiskCache {
  final Map<String, Map<String, dynamic>> entries = {};

  @override
  Future<Map<String, dynamic>?> read(String name) async => entries[name];

  @override
  Future<void> write(String name, Map<String, dynamic> json) async =>
      entries[name] = json;
}

/// [MapEchoSocket] for tests: records the watched airports, and [emit]
/// plays a "new echo" event (no network).
class FakeMapEchoSocket implements MapEchoSocket {
  void Function(String? airportIata)? onChanged;
  Set<String> watched = const {};
  bool disposed = false;

  void emit(String? airportIata) => onChanged!(airportIata);

  @override
  void watch(Set<String> airports) => watched = airports;

  @override
  void dispose() => disposed = true;
}

/// Overrides the world map needs beyond its repositories: device storage
/// (last location, Map Lighting), the disk cache, connectivity and the
/// live-update socket.
Future<List<Override>> mapTestOverrides({
  MapDiskCache? cache,
  bool offline = false,
  Map<String, Object> prefs = const {},
  FakeMapEchoSocket? socket,
}) async {
  final fakeSocket = socket ?? FakeMapEchoSocket();
  SharedPreferences.setMockInitialValues(prefs);
  final sharedPrefs = await SharedPreferences.getInstance();
  return [
    sharedPreferencesProvider.overrideWithValue(sharedPrefs),
    mapDiskCacheProvider.overrideWithValue(cache ?? MemoryMapDiskCache()),
    isOfflineProvider.overrideWith((ref) => Stream.value(offline)),
    mapEchoSocketFactoryProvider.overrideWithValue((onChanged) {
      return fakeSocket..onChanged = onChanged;
    }),
  ];
}
