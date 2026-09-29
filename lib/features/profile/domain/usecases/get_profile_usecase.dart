import 'package:fpdart/fpdart.dart';
import 'package:gate_closes/core/errors/failure.dart';
import 'package:gate_closes/features/profile/data/repositories/profile_repository.dart';
import 'package:gate_closes/features/profile/domain/entities/profile_entity.dart';

/// A single business action. Callable like a function: `getProfileUseCase()`.
class GetProfileUseCase {
  GetProfileUseCase(this._repository);

  final ProfileRepository _repository;

  Future<Either<Failure, ProfileEntity>> call() => _repository.getProfile();
}
