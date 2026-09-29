import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gate_closes/core/utils/context_extensions.dart';
import 'package:gate_closes/features/connections/domain/entities/connection_entity.dart';
import 'package:gate_closes/features/connections/presentation/controllers/connections_controller.dart';
import 'package:gate_closes/features/connections/presentation/pages/message_thread_page.dart';
import 'package:gate_closes/shared/widgets/app_state_view.dart';
import 'package:gate_closes/shared/widgets/glass_card.dart';
import 'package:gate_closes/theme/tokens/spacing.dart';

/// Connections: Parallel Soul / Destination Thread / Baton Touch tabs, all
/// backed by the single unified `/api/conversations` domain — see
/// [ConnectionsController]. Tapping a connection will open the 1-on-1 thread
/// once Phase 8 (Messaging) adds that screen.
class ConnectionsPage extends StatelessWidget {
  const ConnectionsPage({super.key});

  static const List<ConnectionType> _tabs = ConnectionType.values;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return DefaultTabController(
      length: _tabs.length,
      child: Scaffold(
        backgroundColor: colors.background,
        appBar: AppBar(
          title: Text(
            context.l10n.connections,
            style: TextStyle(
              color: colors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          backgroundColor: colors.background,
          elevation: 0,
          bottom: TabBar(
            isScrollable: true,
            labelColor: colors.textPrimary,
            unselectedLabelColor: colors.textMuted,
            indicatorColor: colors.accent,
            tabs: [
              for (final type in _tabs)
                Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        margin: const EdgeInsets.only(right: 6),
                        decoration: BoxDecoration(
                          color: type.accent,
                          shape: BoxShape.circle,
                        ),
                      ),
                      Text(type.label),
                    ],
                  ),
                ),
            ],
          ),
        ),
        body: TabBarView(
          children: [for (final type in _tabs) _ConnectionsTab(type: type)],
        ),
      ),
    );
  }
}

class _ConnectionsTab extends ConsumerWidget {
  const _ConnectionsTab({required this.type});

  final ConnectionType type;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(connectionsControllerProvider);

    if (state.isLoading && state.connections.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.error != null && state.connections.isEmpty) {
      return AppStateView(
        kind: AppStateKind.error,
        title: 'Could not load connections',
        message: state.error,
        actionLabel: 'Retry',
        onAction: () =>
            ref.read(connectionsControllerProvider.notifier).fetchConnections(),
      );
    }

    final connections = state.byType(type);

    if (connections.isEmpty) {
      return AppStateView(
        kind: AppStateKind.empty,
        title: 'No ${type.label} matches yet',
        message: 'When a match happens, it will show up here.',
      );
    }

    return RefreshIndicator(
      onRefresh: () =>
          ref.read(connectionsControllerProvider.notifier).fetchConnections(),
      child: ListView.separated(
        padding: AppSpacing.edgeInsetsMd,
        itemCount: connections.length,
        separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
        itemBuilder: (context, index) =>
            _ConnectionTile(connection: connections[index]),
      ),
    );
  }
}

class _ConnectionTile extends StatelessWidget {
  const _ConnectionTile({required this.connection});

  final ConnectionEntity connection;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final name = connection.otherUserName ?? 'Unknown traveler';
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';

    return GlassCard(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => MessageThreadPage(connection: connection),
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: connection.type.accent.withValues(alpha: 0.18),
            child: Text(
              initial,
              style: TextStyle(
                color: connection.type.accent,
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (connection.lastEventText != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    connection.lastEventText!,
                    style: TextStyle(color: colors.textSecondary, fontSize: 13),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          if (connection.hasUnread)
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: colors.accent,
                shape: BoxShape.circle,
              ),
            ),
        ],
      ),
    );
  }
}
