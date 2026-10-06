import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gate_closes/core/services/authenticated_socket.dart';
import 'package:gate_closes/core/services/storage_service.dart';
import 'package:gate_closes/features/auth/presentation/controllers/auth_controller.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

/// Live updates for the airports whose pins the map shows: one Socket.IO
/// connection joined to each `airport:<IATA>` room on `/terminal-echo`
/// (`gate-closes-api/src/events/terminal.echo.events.ts`).
abstract class MapEchoSocket {
  /// Joins the rooms of [airports] and leaves the rest. An empty set closes
  /// the connection.
  void watch(Set<String> airports);

  void dispose();
}

/// Builds a [MapEchoSocket] that calls `onChanged` with the airport code
/// when an echo is posted there (`null` when the event names no airport).
typedef MapEchoSocketFactory = MapEchoSocket Function(
  void Function(String? airportIata) onChanged,
);

final mapEchoSocketFactoryProvider = Provider<MapEchoSocketFactory>((ref) {
  return (onChanged) => SocketMapEchoSocket(
        readToken: ref.read(storageServiceProvider).readToken,
        revalidateSession: () =>
            ref.read(authControllerProvider.notifier).refreshAuth(),
        onChanged: onChanged,
      );
});

class SocketMapEchoSocket implements MapEchoSocket {
  SocketMapEchoSocket({
    required this.readToken,
    required this.onChanged,
    this.revalidateSession,
  });

  final Future<String?> Function() readToken;
  final Future<void> Function()? revalidateSession;
  final void Function(String? airportIata) onChanged;

  AuthenticatedSocket? _connection;
  Set<String> _rooms = const {};

  @override
  void watch(Set<String> airports) {
    final next = {for (final a in airports) a.toUpperCase()};
    if (next.isEmpty) {
      dispose();
      return;
    }
    final socket = _connection?.socket ?? _open();
    if (socket.connected) {
      for (final a in _rooms.difference(next)) {
        socket.emit('terminal_echo:leave_airport', {'airportIata': a});
      }
      for (final a in next.difference(_rooms)) {
        socket.emit('terminal_echo:join_airport', {'airportIata': a});
      }
    }
    // Not connected yet: onConnect joins every room in [_rooms].
    _rooms = next;
  }

  io.Socket _open() {
    final connection = _connection = AuthenticatedSocket(
      namespace: '/terminal-echo',
      authKey: 'accessToken',
      readToken: readToken,
      revalidateSession: revalidateSession,
    );
    final socket = connection.socket;
    socket
      // Runs on every (re)connect, so rooms are rejoined after recovery.
      ..onConnect((_) {
        for (final a in _rooms) {
          socket.emit('terminal_echo:join_airport', {'airportIata': a});
        }
      })
      ..on('terminal_echo:changed', (data) {
        if (data is! Map || data['type'] != 'create') return;
        final echo = data['data'];
        final iata = echo is Map ? echo['airportIata']?.toString() : null;
        onChanged(iata == null || iata.isEmpty ? null : iata.toUpperCase());
      });
    return socket;
  }

  @override
  void dispose() {
    _connection?.close();
    _connection = null;
    _rooms = const {};
  }
}
