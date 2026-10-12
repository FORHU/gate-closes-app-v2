// The API answers a new echo with 201 { message, insertedId, airportIata },
// not the echo itself; createEcho reads it back by id. Expecting a `data`
// field here crashed posting with "type 'Null' is not a subtype of 'Map'".
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:gate_closes/core/constants/api_endpoints.dart';
import 'package:gate_closes/core/errors/failure.dart';
import 'package:gate_closes/core/location/location_coordinates.dart';
import 'package:gate_closes/core/services/api_service.dart';
import 'package:gate_closes/features/terminal_echo/data/repositories/terminal_echo_repository_impl.dart';
import 'package:gate_closes/features/terminal_echo/domain/entities/terminal_echo_entity.dart';
import 'package:mocktail/mocktail.dart';

class MockApiService extends Mock implements ApiService {}

void main() {
  late MockApiService api;
  late TerminalEchoRepositoryImpl repository;

  setUp(() {
    api = MockApiService();
    repository = TerminalEchoRepositoryImpl(api);
  });

  Future<Either<Failure, TerminalEchoEntity>> post() => repository.createEcho(
        textMessage: 'test 1',
        airportName: 'Test airport',
        coordinates: const LocationCoordinates(latitude: 14.5, longitude: 121),
        fileUrl: 'https://cdn.example.com/a.m4a',
        fileName: 'a.m4a',
      );

  void stubPost(Map<String, dynamic> reply) => when(
        () => api.postWith(
          any(),
          body: any(named: 'body'),
          idempotencyKey: any(named: 'idempotencyKey'),
        ),
      ).thenAnswer((_) async => reply);

  test('reads the created echo back by its insertedId', () async {
    stubPost({'message': 'Terminal echo created.', 'insertedId': 'e1'});
    when(() => api.get('${ApiEndpoints.terminalEcho}/e1')).thenAnswer(
      (_) async => {
        'data': {'_id': 'e1', 'textMessage': 'test 1'},
      },
    );

    final result = await post();

    expect(result.isRight(), isTrue);
    expect(result.getOrElse((_) => throw StateError('failed')).id, 'e1');
  });

  test('fails cleanly when the reply has no insertedId', () async {
    stubPost({'message': 'Terminal echo created.'});

    final result = await post();

    expect(result.isLeft(), isTrue);
  });
}
