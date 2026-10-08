import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:fpdart/fpdart.dart';
import 'package:gate_closes/core/errors/failure.dart';
import 'package:gate_closes/core/services/connectivity_service.dart';
import 'package:gate_closes/core/services/storage_service.dart';
import 'package:gate_closes/features/worldMap/data/datasources/device_capabilities_source.dart';
import 'package:gate_closes/features/worldMap/data/datasources/map_disk_cache.dart';
import 'package:gate_closes/features/worldMap/data/datasources/map_echo_socket.dart';
import 'package:gate_closes/features/worldMap/domain/entities/map_offer.dart';
import 'package:gate_closes/features/worldMap/domain/entities/map_tier.dart';
import 'package:gate_closes/features/worldMap/domain/repositories/offer_map_repository.dart';
import 'package:gate_closes/features/worldMap/presentation/controllers/map_tier_controller.dart';
import 'package:gate_closes/features/worldMap/presentation/controllers/world_map_controller.dart';
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

/// [OfferMapRepository] for tests: [offers] per airport (none by default),
/// [fail] makes every load fail; records requests, events and claims.
class FakeOfferMapRepository implements OfferMapRepository {
  FakeOfferMapRepository({this.offers = const {}, this.fail = false});

  final Map<String, AirportOffers> offers;
  bool fail;
  final List<String> requested = [];
  final List<(String, OfferEvent)> events = [];
  final List<String> claims = [];
  Either<Failure, OfferReward> claimResult =
      const Right(OfferReward({'code': 'GATE20'}));

  @override
  Future<Either<Failure, AirportOffers>> getAirportOffers(
    String airportIata,
  ) async {
    requested.add(airportIata);
    if (fail) return const Left(NetworkFailure());
    return Right(offers[airportIata] ?? AirportOffers.empty);
  }

  @override
  Future<void> track(
    String offerId,
    OfferEvent event, {
    String? airportIata,
  }) async =>
      events.add((offerId, event));

  @override
  Future<Either<Failure, OfferReward>> claim(
    String offerId, {
    String? airportIata,
  }) async {
    claims.add(offerId);
    return claimResult;
  }
}

/// [DeviceCapabilitiesSource] for tests: a capable phone, no platform
/// channel (the 3D map's tier).
class FakeDeviceCapabilitiesSource implements DeviceCapabilitiesSource {
  const FakeDeviceCapabilitiesSource();

  @override
  Future<DeviceCapabilities> read() async => const DeviceCapabilities(
        is64Bit: true,
        totalRamMb: 8000,
        lowRam: false,
        sdk: 34,
      );
}

/// Overrides the world map needs beyond its repositories: device storage
/// (last location, Map Lighting), the disk cache, connectivity, the
/// live-update socket, offers (none unless [offers] has some) and a
/// capable device (the 3D map).
Future<List<Override>> mapTestOverrides({
  MapDiskCache? cache,
  bool offline = false,
  Map<String, Object> prefs = const {},
  FakeMapEchoSocket? socket,
  FakeOfferMapRepository? offers,
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
    offerMapRepositoryProvider.overrideWithValue(
      offers ?? FakeOfferMapRepository(),
    ),
    deviceCapabilitiesSourceProvider.overrideWithValue(
      const FakeDeviceCapabilitiesSource(),
    ),
  ];
}
