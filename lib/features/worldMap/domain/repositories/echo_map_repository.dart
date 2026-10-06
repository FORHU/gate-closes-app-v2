import 'package:fpdart/fpdart.dart';
import 'package:gate_closes/core/errors/failure.dart';
import 'package:gate_closes/features/worldMap/domain/entities/airport_echo_count.dart';
import 'package:gate_closes/features/worldMap/domain/entities/echo_map_node_entity.dart';

/// Echo pins for the world map. Owned by `worldMap` (not `terminal_echo`) so
/// the map reads the `/terminal-echo/map` endpoints without importing another
/// feature.
abstract class EchoMapRepository {
  /// The newest pins at one airport (`?airport=MNL`).
  Future<Either<Failure, List<TerminalEchoMapNodeEntity>>> getAirportNodes(
    String airportIata,
  );

  /// Echo count per airport, for the zoomed-out map.
  Future<Either<Failure, List<AirportEchoCount>>> getAirportCounts();
}
