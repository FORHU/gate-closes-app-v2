import 'package:flutter_test/flutter_test.dart';
import 'package:gate_closes/core/errors/exceptions.dart';
import 'package:gate_closes/core/errors/failure.dart';
import 'package:gate_closes/features/profile/data/datasources/profile_remote_datasource.dart';
import 'package:gate_closes/features/profile/data/models/profile_model.dart';
import 'package:gate_closes/features/profile/data/repositories/profile_repository.dart';
import 'package:mocktail/mocktail.dart';

class MockProfileRemoteDataSource extends Mock
    implements ProfileRemoteDataSource {}

void main() {
  late MockProfileRemoteDataSource mockRemote;
  late ProfileRepositoryImpl repository;

  setUp(() {
    mockRemote = MockProfileRemoteDataSource();
    repository = ProfileRepositoryImpl(mockRemote);
  });

  group('ProfileRepositoryImpl.getProfile', () {
    const tProfile = ProfileModel(
      id: '1',
      name: 'Ada Lovelace',
      email: 'ada@example.com',
      bio: 'Building great things with Flutter.',
    );

    test('returns Right(profile) on success', () async {
      // Arrange
      when(() => mockRemote.getProfile()).thenAnswer((_) async => tProfile);

      // Act
      final result = await repository.getProfile();

      // Assert
      expect(result.isRight(), isTrue);
      expect(result.getRight().toNullable(), tProfile);
    });

    test('maps UnauthorizedException to UnauthorizedFailure', () async {
      // Arrange
      when(
        () => mockRemote.getProfile(),
      ).thenThrow(const UnauthorizedException('Session expired'));

      // Act
      final result = await repository.getProfile();

      // Assert
      expect(result.isLeft(), isTrue);
      final failure = result.getLeft().toNullable();
      expect(failure, isA<UnauthorizedFailure>());
      expect(failure!.message, 'Session expired');
    });

    test('maps NetworkException to NetworkFailure', () async {
      // Arrange
      when(() => mockRemote.getProfile()).thenThrow(const NetworkException());

      // Act
      final result = await repository.getProfile();

      // Assert
      expect(result.isLeft(), isTrue);
      expect(result.getLeft().toNullable(), isA<NetworkFailure>());
    });

    test('maps ServerException to ServerFailure', () async {
      // Arrange
      when(
        () => mockRemote.getProfile(),
      ).thenThrow(const ServerException('Boom', statusCode: 500));

      // Act
      final result = await repository.getProfile();

      // Assert
      expect(result.isLeft(), isTrue);
      expect(result.getLeft().toNullable(), isA<ServerFailure>());
    });

    test('maps an unexpected error to ServerFailure', () async {
      // Arrange
      when(() => mockRemote.getProfile()).thenThrow(Exception('boom'));

      // Act
      final result = await repository.getProfile();

      // Assert
      expect(result.isLeft(), isTrue);
      expect(result.getLeft().toNullable(), isA<ServerFailure>());
    });
  });
}
