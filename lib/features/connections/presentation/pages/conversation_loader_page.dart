import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gate_closes/core/utils/context_extensions.dart';
import 'package:gate_closes/features/connections/domain/entities/connection_entity.dart';
import 'package:gate_closes/features/connections/presentation/controllers/connections_controller.dart';
import 'package:gate_closes/features/connections/presentation/pages/message_thread_page.dart';
import 'package:gate_closes/shared/widgets/app_state_view.dart';

/// Entry point for `/connections/c/:conversationId`.
///
/// The inbox opens a thread with the conversation it already has; anything
/// that only knows the id (a tapped notification) gets it fetched here first.
class ConversationLoaderPage extends ConsumerStatefulWidget {
  const ConversationLoaderPage({required this.conversationId, super.key});

  final String conversationId;

  @override
  ConsumerState<ConversationLoaderPage> createState() =>
      _ConversationLoaderPageState();
}

class _ConversationLoaderPageState
    extends ConsumerState<ConversationLoaderPage> {
  ConnectionEntity? _connection;
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    setState(() => _error = null);
    final result = await ref
        .read(connectionsRepositoryProvider)
        .getConnection(widget.conversationId);
    if (!mounted) return;
    setState(() {
      result.fold(
        (failure) => _error = failure.message,
        (connection) => _connection = connection,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final connection = _connection;
    if (connection != null) return MessageThreadPage(connection: connection);

    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppBar(backgroundColor: context.colors.background),
      body: _error == null
          ? const Center(child: CircularProgressIndicator())
          : AppStateView(
              kind: AppStateKind.error,
              title: "Couldn't open this conversation",
              message: _error,
              actionLabel: 'Retry',
              onAction: () => unawaited(_load()),
            ),
    );
  }
}
