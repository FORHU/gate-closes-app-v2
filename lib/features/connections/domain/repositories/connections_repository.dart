import 'package:flutter_template/core/errors/failure.dart';
import 'package:flutter_template/features/connections/domain/entities/connection_entity.dart';
import 'package:fpdart/fpdart.dart';

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
