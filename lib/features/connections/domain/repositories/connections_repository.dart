import 'package:fpdart/fpdart.dart';
import 'package:gate_closes/core/errors/failure.dart';
import 'package:gate_closes/features/connections/domain/entities/connection_entity.dart';

abstract class ConnectionsRepository {
  /// Lists user's conversations, optionally filtered by ConnectionType.
  Future<Either<Failure, List<ConnectionEntity>>> getConnections({
    ConnectionType? type,
  });

  /// Creates a new DM connection with another traveler.
  Future<Either<Failure, ConnectionEntity>> createConnection({
    required ConnectionType type,
    required String otherUserId,
  });

  /// Searches connections by username query and optional type filter.
  Future<Either<Failure, List<ConnectionEntity>>> searchConnections({
    required String query,
    ConnectionType? type,
  });
}
