import 'package:flutter_test/flutter_test.dart';
import 'package:gate_closes/core/constants/api_endpoints.dart';
import 'package:gate_closes/core/errors/exceptions.dart';
import 'package:gate_closes/core/errors/failure.dart';
import 'package:gate_closes/core/services/api_service.dart';
import 'package:gate_closes/features/worldMap/data/repositories/echo_map_repository_impl.dart';
import 'package:gate_closes/features/worldMap/domain/entities/echo_map_node_entity.dart';
import 'package:mocktail/mocktail.dart';

class MockApiService extends Mock implements ApiService {}

void main() {
  late MockApiService api;
  late EchoMapRepositoryImpl repository;

  setUp(() {
    api = MockApiService();
    repository = EchoMapRepositoryImpl(api);
  });

  test('asks for one airport and parses its pins', () async {
    when(() => api.get(any(), query: any(named: 'query'))).thenAnswer(
      (_) async => {
        'data': {
          'type': 'FeatureCollection',
          'features': [
            {
              'id': 'e1',
              'geometry': {
                'type': 'Point',
                'coordinates': [103.99, 1.35],
              },
              'properties': {'type': 'baton_touch', 'senderId': 'u9'},
            },
          ],
        },
      },
    );

    final result = await repository.getAirportNodes('SIN');

    verify(
      () => api.get(ApiEndpoints.terminalEchoMap, query: {'airport': 'SIN'}),
    ).called(1);
    final nodes = result.getOrElse((_) => fail('expected Right'));
    expect(nodes, hasLength(1));
    expect(nodes.single.id, 'e1');
    expect(nodes.single.nodeKind, EchoNodeKind.batonTouch);
    expect(nodes.single.longitude, 103.99);
    expect(nodes.single.latitude, 1.35);
  });

  test('parses the per-airport counts, skipping unusable features', () async {
    when(() => api.get(any(), query: any(named: 'query'))).thenAnswer(
      (_) async => {
        'data': {
          'type': 'FeatureCollection',
          'features': [
            {
              'id': 'MNL',
              'geometry': {
                'type': 'Point',
                'coordinates': [121.019208, 14.511205],
              },
              'properties': {
                'airportIata': 'MNL',
                'airportName': 'Ninoy Aquino International Airport',
                'count': 12,
                'latestAt': '2026-10-05T01:00:00.000Z',
              },
            },
            {
              'id': 'XXX',
              'geometry': null,
              'properties': {'airportIata': 'XXX', 'count': 1},
            },
          ],
        },
      },
    );

    final result = await repository.getAirportCounts();

    verify(
      () => api.get(ApiEndpoints.terminalEchoMapCounts),
    ).called(1);
    final counts = result.getOrElse((_) => fail('expected Right'));
    expect(counts, hasLength(1));
    expect(counts.single.airportIata, 'MNL');
    expect(counts.single.count, 12);
    expect(counts.single.longitude, 121.019208);
    expect(counts.single.latestAt, DateTime.utc(2026, 10, 5, 1));
  });

  test('maps a network error to NetworkFailure', () async {
    when(
      () => api.get(any(), query: any(named: 'query')),
    ).thenThrow(const NetworkException());

    final result = await repository.getAirportNodes('SIN');

    expect(result.getLeft().toNullable(), isA<NetworkFailure>());
  });
}
