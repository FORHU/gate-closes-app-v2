import 'package:fpdart/fpdart.dart';
import 'package:gate_closes/core/constants/api_endpoints.dart';
import 'package:gate_closes/core/errors/exceptions.dart';
import 'package:gate_closes/core/errors/failure.dart';
import 'package:gate_closes/core/services/api_service.dart';
import 'package:gate_closes/features/worldMap/domain/entities/airport_echo_count.dart';
import 'package:gate_closes/features/worldMap/domain/entities/echo_map_node_entity.dart';
import 'package:gate_closes/features/worldMap/domain/repositories/echo_map_repository.dart';

class EchoMapRepositoryImpl implements EchoMapRepository {
  const EchoMapRepositoryImpl(this._api);

  final ApiService _api;

  @override
  Future<Either<Failure, List<TerminalEchoMapNodeEntity>>> getAirportNodes(
    String airportIata,
  ) =>
      _features(
        ApiEndpoints.terminalEchoMap,
        {'airport': airportIata},
        TerminalEchoMapNodeEntity.fromGeoJsonFeature,
      );

  @override
  Future<Either<Failure, List<AirportEchoCount>>> getAirportCounts() async {
    final result = await _features(
      ApiEndpoints.terminalEchoMapCounts,
      null,
      AirportEchoCount.fromGeoJsonFeature,
    );
    return result
        .map((counts) => counts.whereType<AirportEchoCount>().toList());
  }

  /// GETs a `{data: FeatureCollection}` endpoint and parses each feature.
  Future<Either<Failure, List<T>>> _features<T>(
    String endpoint,
    Map<String, dynamic>? query,
    T Function(Map<String, dynamic> feature) parse,
  ) async {
    try {
      final response = await _api.get(endpoint, query: query);
      final data = response is Map ? response['data'] : null;
      final features = data is Map ? data['features'] : null;
      if (features is! List) return Right(List<T>.empty());
      return Right(
        features
            .whereType<Map<dynamic, dynamic>>()
            .map((f) => parse(f.cast<String, dynamic>()))
            .toList(),
      );
    } on NetworkException catch (e) {
      return Left(NetworkFailure(e.message));
    } on AppException catch (e) {
      return Left(ServerFailure(e.message));
    } on Object catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }
}
