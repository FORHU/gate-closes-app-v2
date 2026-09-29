import 'package:fpdart/fpdart.dart';
import 'package:gate_closes/core/errors/failure.dart';
import 'package:gate_closes/features/auth/data/repositories/auth_repository.dart';
import 'package:gate_closes/features/auth/domain/entities/user_entity.dart';

/// A single business action. Callable like a function: `loginUseCase(e, p)`.
class LoginUseCase {
  LoginUseCase(this._repository);

  final AuthRepository _repository;

  Future<Either<Failure, UserEntity>> call(String email, String password) =>
      _repository.login(email.trim(), password);
}
