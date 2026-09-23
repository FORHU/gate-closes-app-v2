import 'package:equatable/equatable.dart';

/// Base class for all failures in the application.
/// Ensures that domain layers return consistent error objects.
sealed class Failure extends Equatable {
  const Failure(this.message);

  final String message;

  @override
  List<Object> get props => [message];
}

/// Represents an error returned by an external server/API.
class ServerFailure extends Failure {
  const ServerFailure(super.message);
}

/// Represents an error caching data locally.
class CacheFailure extends Failure {
  const CacheFailure(super.message);
}

/// Represents an error indicating no network connection.
class NetworkFailure extends Failure {
  const NetworkFailure([super.message = 'No Internet connection']);
}

/// Represents an unauthorized or unauthenticated error.
class UnauthorizedFailure extends Failure {
  const UnauthorizedFailure([super.message = 'Unauthorized access']);
}

/// Represents a failure due to missing device permissions.
class PermissionFailure extends Failure {
  const PermissionFailure([super.message = 'Permission required']);
}
