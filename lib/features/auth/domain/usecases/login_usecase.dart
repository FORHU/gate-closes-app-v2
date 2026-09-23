import 'package:flutter_template/core/errors/failure.dart';
import 'package:flutter_template/features/auth/data/repositories/auth_repository.dart';
import 'package:flutter_template/features/auth/domain/entities/user_entity.dart';
import 'package:fpdart/fpdart.dart';

/// A single business action. Callable like a function: `loginUseCase(e, p)`.
class LoginUseCase {
  LoginUseCase(this._repository);

  final AuthRepository _repository;

  Future<Either<Failure, UserEntity>> call(String email, String password) =>
      _repository.login(email.trim(), password);
}
