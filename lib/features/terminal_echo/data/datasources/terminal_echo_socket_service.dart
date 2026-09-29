import 'package:gate_closes/core/config/app_config.dart';
import 'package:gate_closes/core/utils/logger.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

/// Manages realtime Socket.IO connections for the `/terminal-echo` namespace.
/// Strictly enforces room scoping to `airport:<IATA>` to prevent cross-airport
/// leakages.
class TerminalEchoSocketService {
  TerminalEchoSocketService({required this.token});

  final String? token;
  io.Socket? _socket;
  String? _currentAirportIata;

  bool get isConnected => _socket?.connected ?? false;

  /// Connects to the `/terminal-echo` namespace and joins the airport room.
  void connect({
    required String airportIata,
    void Function(Map<String, dynamic> echo)? onNewEcho,
    void Function(Map<String, dynamic> reaction)? onReactionUpdated,
  }) {
    disconnect();
    _currentAirportIata = airportIata;

    final baseUrl = AppConfig.instance.baseUrl;
    final uri = Uri.parse(baseUrl);
    final socketUrl = '${uri.scheme}://${uri.host}:${uri.port}/terminal-echo';

    _socket = io.io(
      socketUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .enableAutoConnect()
          .setExtraHeaders(
            token != null ? {'Authorization': 'Bearer $token'} : {},
          )
          .build(),
    );

    _socket!.onConnect((_) {
      appLogger.i(
        'Socket connected to /terminal-echo. Joining airport:$airportIata',
      );
      _socket!.emit('terminal_echo:join_airport', {'airportIata': airportIata});
    });

    if (onNewEcho != null) {
      _socket!.on('terminal_echo:changed', (data) {
        if (data is Map && data['type'] == 'create' && data['data'] is Map) {
          onNewEcho((data['data'] as Map).cast<String, dynamic>());
        }
      });
    }

    if (onReactionUpdated != null) {
      _socket!.on('terminal_echo:reaction_updated', (data) {
        if (data is Map) {
          onReactionUpdated(data.cast<String, dynamic>());
        }
      });
    }

    _socket!.onDisconnect((_) {
      appLogger.w('Socket disconnected from /terminal-echo');
    });
  }

  void disconnect() {
    if (_socket != null) {
      if (_currentAirportIata != null) {
        _socket!.emit('leave-airport', {'airportIata': _currentAirportIata});
      }
      _socket!.disconnect();
      _socket!.dispose();
      _socket = null;
      _currentAirportIata = null;
    }
  }
}
