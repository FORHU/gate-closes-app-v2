import 'package:gate_closes/core/config/app_config.dart';
import 'package:gate_closes/core/utils/logger.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

/// Manages realtime Socket.IO connections for the `/conversations` namespace.
///
/// Event names are verified against `gate-closes-api/src/events/conversation.
/// events.ts` and `conversation.controller.ts` — note `join_conversation`/
/// `leave_conversation` use underscores, unlike Terminal Echo's
/// `join-airport`/`leave-airport` (hyphenated). The two namespaces are not
/// symmetric; do not copy one pattern onto the other without checking.
class ConversationSocketService {
  ConversationSocketService({required this.token});

  final String? token;
  io.Socket? _socket;
  String? _currentConversationId;

  bool get isConnected => _socket?.connected ?? false;

  /// Connects to the `/conversations` namespace. If [conversationId] is
  /// provided, joins that conversation's room. Otherwise connects to the
  /// namespace to receive user-level events (e.g. `conversation:updated`).
  void connect({
    String? conversationId,
    void Function(Map<String, dynamic> message)? onMessageReceived,
    void Function(Map<String, dynamic> reaction)? onReactionUpdated,
    void Function(Map<String, dynamic> update)? onConversationUpdated,
  }) {
    disconnect();
    _currentConversationId = conversationId;

    final baseUrl = AppConfig.instance.baseUrl;
    final uri = Uri.parse(baseUrl);
    final socketUrl = '${uri.scheme}://${uri.host}:${uri.port}/conversations';

    _socket = io.io(
      socketUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .enableAutoConnect()
          .setAuth({'token': token})
          .setExtraHeaders(
            token != null ? {'Authorization': 'Bearer $token'} : {},
          )
          .build(),
    );

    _socket!.onConnect((_) {
      if (conversationId != null) {
        appLogger.i(
          'Socket connected to /conversations. Joining $conversationId',
        );
        _socket!.emit('join_conversation', {'conversationId': conversationId});
      } else {
        appLogger.i(
          'Socket connected to /conversations (listening for user updates)',
        );
      }
    });

    if (onConversationUpdated != null) {
      _socket!.on('conversation:updated', (data) {
        if (data is Map) {
          onConversationUpdated(data.cast<String, dynamic>());
        }
      });
    }

    if (onMessageReceived != null) {
      _socket!.on('message:received', (data) {
        if (data is Map) {
          onMessageReceived(data.cast<String, dynamic>());
        }
      });
    }

    if (onReactionUpdated != null) {
      _socket!.on('reaction:updated', (data) {
        if (data is Map) {
          onReactionUpdated(data.cast<String, dynamic>());
        }
      });
    }

    _socket!.onConnectError((err) {
      appLogger.w('Socket /conversations connect error: $err');
    });

    _socket!.onDisconnect((_) {
      appLogger.w('Socket disconnected from /conversations');
    });
  }

  void disconnect() {
    if (_socket != null) {
      if (_currentConversationId != null) {
        _socket!.emit('leave_conversation', {
          'conversationId': _currentConversationId,
        });
      }
      _socket!.disconnect();
      _socket!.dispose();
      _socket = null;
      _currentConversationId = null;
    }
  }
}
