import 'package:flutter_template/core/errors/exceptions.dart';
import 'package:flutter_template/core/errors/failure.dart';
import 'package:flutter_template/features/profile/data/datasources/profile_remote_datasource.dart';
import 'package:flutter_template/features/profile/domain/entities/profile_entity.dart';
import 'package:fpdart/fpdart.dart';

/// Repository contract (the abstraction the domain layer depends on).
abstract class ProfileRepository {
  Future<Either<Failure, ProfileEntity>> getProfile();
}

/// Coordinates the remote data source. Catches the data layer's typed
/// exceptions and maps them to typed [Failure] values.
class ProfileRepositoryImpl implements ProfileRepository {
  ProfileRepositoryImpl(this._remote);

  final ProfileRemoteDataSource _remote;

  @override
  Future<Either<Failure, ProfileEntity>> getProfile() async {
    try {
      final profile = await _remote.getProfile();
      return Right(profile);
    } on UnauthorizedException catch (e) {
      return Left(UnauthorizedFailure(e.message));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(e.message));
    } on AppException catch (e) {
      return Left(ServerFailure(e.message));
    } on Object catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }
}
