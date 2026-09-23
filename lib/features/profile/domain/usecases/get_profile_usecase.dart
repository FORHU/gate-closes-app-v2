import 'package:flutter_template/core/errors/failure.dart';
import 'package:flutter_template/features/profile/data/repositories/profile_repository.dart';
import 'package:flutter_template/features/profile/domain/entities/profile_entity.dart';
import 'package:fpdart/fpdart.dart';

/// A single business action. Callable like a function: `getProfileUseCase()`.
class GetProfileUseCase {
  GetProfileUseCase(this._repository);

  final ProfileRepository _repository;

  Future<Either<Failure, ProfileEntity>> call() => _repository.getProfile();
}
