import 'package:flutter_test/flutter_test.dart';
import 'package:gate_closes/core/constants/api_endpoints.dart';
import 'package:gate_closes/core/errors/exceptions.dart';
import 'package:gate_closes/core/errors/failure.dart';
import 'package:gate_closes/core/services/api_service.dart';
import 'package:gate_closes/features/worldMap/data/repositories/offer_map_repository_impl.dart';
import 'package:gate_closes/features/worldMap/domain/repositories/offer_map_repository.dart';
import 'package:mocktail/mocktail.dart';

class MockApiService extends Mock implements ApiService {}

void main() {
  late MockApiService api;
  late OfferMapRepositoryImpl repository;

  setUp(() {
    api = MockApiService();
    repository = OfferMapRepositoryImpl(api);
  });

  test("asks for one airport's offers and parses them", () async {
    when(() => api.get(any(), query: any(named: 'query'))).thenAnswer(
      (_) async => {
        'data': {
          'card': {'id': 'c1', 'title': 'Coffee', 'claimable': true},
          'pins': {'type': 'FeatureCollection', 'features': <Object>[]},
        },
      },
    );

    final result = await repository.getAirportOffers('MNL');

    verify(() => api.get(ApiEndpoints.offers, query: {'airport': 'MNL'}))
        .called(1);
    final offers = result.getOrElse((_) => fail('expected Right'));
    expect(offers.card?.id, 'c1');
    expect(offers.card?.airportIata, 'MNL');
    expect(offers.pins, isEmpty);
  });

  test('offline is a NetworkFailure', () async {
    when(() => api.get(any(), query: any(named: 'query')))
        .thenThrow(const NetworkException());

    final result = await repository.getAirportOffers('MNL');

    expect(result.getLeft().toNullable(), isA<NetworkFailure>());
  });

  test('tracking posts the event and never throws', () async {
    when(() => api.post(any(), any())).thenAnswer((_) async => null);

    await repository.track('o1', OfferEvent.click, airportIata: 'MNL');

    verify(
      () => api.post(
        ApiEndpoints.offerEvents('o1'),
        {'type': 'click', 'airport': 'MNL'},
      ),
    ).called(1);

    when(() => api.post(any(), any())).thenThrow(const NetworkException());
    await repository.track('o1', OfferEvent.view);
  });

  test('a claim returns the reward', () async {
    when(() => api.post(any(), any())).thenAnswer(
      (_) async => {
        'data': {
          'offer': {'id': 'o1'},
          'reward': {'code': 'GATE20'},
        },
      },
    );

    final result = await repository.claim('o1', airportIata: 'MNL');

    verify(() => api.post(ApiEndpoints.offerClaim('o1'), {'airport': 'MNL'}))
        .called(1);
    expect(result.getOrElse((_) => fail('expected Right')).code, 'GATE20');
  });

  test("a refused claim keeps the API's reason", () async {
    when(() => api.post(any(), any())).thenThrow(
      const ServerException('This offer has run out.', statusCode: 409),
    );

    final result = await repository.claim('o1');

    expect(result.getLeft().toNullable()?.message, 'This offer has run out.');
  });
}
