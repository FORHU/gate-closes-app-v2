import 'package:flutter_template/core/errors/failure.dart';
import 'package:flutter_template/features/auth/data/repositories/auth_repository.dart';
import 'package:flutter_template/features/auth/domain/entities/user_entity.dart';
import 'package:fpdart/fpdart.dart';

/// Checks that the stored token is still valid and refreshes the cached user.
class RefreshAuthUseCase {
  RefreshAuthUseCase(this._repository);

  final AuthRepository _repository;

  Future<Either<Failure, UserEntity>> execute() => _repository.refreshAuth();
}
