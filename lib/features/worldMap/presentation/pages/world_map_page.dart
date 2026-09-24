import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_template/core/utils/context_extensions.dart';
import 'package:flutter_template/features/airport/domain/entities/airport_entity.dart';
import 'package:flutter_template/features/terminal_echo/domain/entities/terminal_echo_map_node_entity.dart';
import 'package:flutter_template/features/terminal_echo/presentation/controllers/terminal_echo_controller.dart';
import 'package:flutter_template/features/worldMap/presentation/controllers/world_map_controller.dart';
import 'package:flutter_template/routes/route_names.dart';
import 'package:flutter_template/shared/widgets/app_card.dart';
import 'package:flutter_template/shared/widgets/app_state_view.dart';
import 'package:flutter_template/shared/widgets/glass_card.dart';
import 'package:flutter_template/theme/tokens/colors.dart';
import 'package:flutter_template/theme/tokens/spacing.dart';
import 'package:go_router/go_router.dart';

enum MapDisplayMode { spatialView, nearbyList }

class WorldMapPage extends ConsumerStatefulWidget {
  const WorldMapPage({super.key});

  @override
  ConsumerState<WorldMapPage> createState() => _WorldMapPageState();
}

class _WorldMapPageState extends ConsumerState<WorldMapPage> {
  MapDisplayMode _mode = MapDisplayMode.spatialView;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(worldMapControllerProvider);
    final colors = context.colors;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: Text(
          _mode == MapDisplayMode.spatialView
              ? (state.selectedAirport != null
                  ? '${state.selectedAirport!.iata} — Terminal Map'
                  : 'Terminal Map')
              : 'Nearby Airports',
          style: TextStyle(
            color: colors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        backgroundColor: colors.background,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: _mode == MapDisplayMode.spatialView
                ? 'List view'
                : 'Spatial map',
            icon: Icon(
              _mode == MapDisplayMode.spatialView
                  ? Icons.view_list_rounded
                  : Icons.map_rounded,
              color: colors.textPrimary,
            ),
            onPressed: () {
              setState(() {
                _mode = _mode == MapDisplayMode.spatialView
                    ? MapDisplayMode.nearbyList
                    : MapDisplayMode.spatialView;
              });
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () =>
            ref.read(worldMapControllerProvider.notifier).initMapData(),
        child: _mode == MapDisplayMode.spatialView
            ? _buildSpatialView(context, colors, state)
            : _buildNearbyList(context, colors, state),
      ),
    );
  }

  Widget _buildSpatialView(
    BuildContext context,
    GateColors colors,
    WorldMapState state,
  ) {
    if (state.isLoading && state.echoNodes.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    final selected = state.selectedAirport;

    return Stack(
      children: [
        // Spatial airport background visualization
        Container(
          width: double.infinity,
          height: double.infinity,
          decoration: BoxDecoration(
            gradient: RadialGradient(
              radius: 0.85,
              colors: [
                colors.accent.withValues(alpha: 0.12),
                colors.background,
              ],
            ),
          ),
          child: CustomPaint(
            painter: _AirportBoundaryRadarPainter(
              boundaryColor: colors.accent,
              radarPulseColor: colors.accent.withValues(alpha: 0.25),
            ),
          ),
        ),

        // Foreground content & echo nodes overlay
        SafeArea(
          child: Column(
            children: [
              if (selected != null)
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: GlassCard(
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor:
                              colors.accent.withValues(alpha: 0.18),
                          child: Icon(
                            Icons.flight_takeoff_rounded,
                            color: colors.accent,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                selected.name,
                                style: TextStyle(
                                  color: colors.textPrimary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                '${selected.iata} · '
                                '${selected.detectionState.name}',
                                style: TextStyle(
                                  color: colors.accent,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (state.airports.length > 1)
                          PopupMenuButton<AirportEntity>(
                            icon: Icon(
                              Icons.expand_more_rounded,
                              color: colors.textMuted,
                            ),
                            onSelected: (airport) => ref
                                .read(worldMapControllerProvider.notifier)
                                .selectAirport(airport),
                            itemBuilder: (_) => state.airports
                                .map(
                                  (a) => PopupMenuItem(
                                    value: a,
                                    child: Text('${a.iata} - ${a.name}'),
                                  ),
                                )
                                .toList(),
                          ),
                      ],
                    ),
                  ),
                ),

              // Spatial Echo Pins List / Overlay
              Expanded(
                child: state.echoNodes.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.radar_rounded,
                              size: 54,
                              color: colors.textMuted.withValues(alpha: 0.4),
                            ),
                            const SizedBox(height: AppSpacing.md),
                            Text(
                              'Scanning Terminal Echo Nodes...',
                              style: TextStyle(
                                color: colors.textMuted,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              'No spatial echo nodes currently detected',
                              style: TextStyle(
                                color: colors.textMuted,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                          vertical: AppSpacing.sm,
                        ),
                        itemCount: state.echoNodes.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: AppSpacing.sm),
                        itemBuilder: (context, index) {
                          final node = state.echoNodes[index];
                          return _EchoNodeCard(node: node);
                        },
                      ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildNearbyList(
    BuildContext context,
    GateColors colors,
    WorldMapState state,
  ) {
    if (state.isLoading && state.airports.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.error != null && state.airports.isEmpty) {
      return AppStateView(
        kind: AppStateKind.error,
        title: 'Could not load nearby airports',
        message: state.error,
        actionLabel: 'Retry',
        onAction: () =>
            ref.read(worldMapControllerProvider.notifier).initMapData(),
      );
    }

    if (state.airports.isEmpty) {
      return const AppStateView(
        kind: AppStateKind.empty,
        title: 'No nearby airports',
        message: 'Nothing within range of your current location.',
      );
    }

    return ListView.separated(
      padding: AppSpacing.edgeInsetsMd,
      itemCount: state.airports.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (context, index) {
        final airport = state.airports[index];
        final isSelected = airport.id == state.selectedAirport?.id;

        return AppCard(
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: CircleAvatar(
              backgroundColor: isSelected
                  ? colors.accent
                  : colors.accent.withValues(alpha: 0.15),
              child: Icon(
                Icons.flight_takeoff_rounded,
                color: isSelected ? colors.accentOn : colors.accent,
                size: 20,
              ),
            ),
            title: Text(
              airport.name,
              style: TextStyle(
                color: colors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            subtitle: Text(
              [
                airport.iata,
                if (airport.countryCode != null) airport.countryCode!,
                if (airport.distanceKm != null)
                  '${airport.distanceKm!.toStringAsFixed(0)} km',
              ].join(' · '),
              style: TextStyle(color: colors.textSecondary),
            ),
            trailing: isSelected
                ? Icon(Icons.check_circle_rounded, color: colors.accent)
                : null,
            onTap: () {
              ref
                  .read(worldMapControllerProvider.notifier)
                  .selectAirport(airport);
              setState(() => _mode = MapDisplayMode.spatialView);
            },
          ),
        );
      },
    );
  }
}

class _EchoNodeCard extends ConsumerWidget {
  const _EchoNodeCard({required this.node});

  final TerminalEchoMapNodeEntity node;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;

    final (badgeLabel, badgeColor, nodeIcon) = switch (node.nodeKind) {
      EchoNodeKind.parallelSoul => (
          'PARALLEL SOUL',
          const Color(0xFF6366F1),
          Icons.sync_alt_rounded
        ),
      EchoNodeKind.destinationThread => (
          'DESTINATION THREAD',
          const Color(0xFF10B981),
          Icons.call_merge_rounded
        ),
      EchoNodeKind.batonTouch => (
          'BATON TOUCH',
          const Color(0xFFF59E0B),
          Icons.swap_calls_rounded
        ),
      EchoNodeKind.terminalEcho => (
          'TERMINAL ECHO',
          colors.accent,
          Icons.cell_tower_rounded,
        ),
    };

    return GlassCard(
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: CircleAvatar(
          backgroundColor: badgeColor.withValues(alpha: 0.2),
          child: Icon(nodeIcon, color: badgeColor, size: 20),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: badgeColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                badgeLabel,
                style: TextStyle(
                  color: badgeColor,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const Spacer(),
            if (node.isNew)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.lime.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'NEW',
                  style: TextStyle(
                    color: Colors.limeAccent,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Row(
            children: [
              Icon(Icons.hearing_rounded, size: 14, color: colors.textMuted),
              const SizedBox(width: 4),
              Text(
                '${node.listenCount}',
                style: TextStyle(color: colors.textMuted, fontSize: 12),
              ),
              const SizedBox(width: AppSpacing.md),
              Icon(Icons.reply_rounded, size: 14, color: colors.textMuted),
              const SizedBox(width: 4),
              Text(
                '${node.replyCount}',
                style: TextStyle(color: colors.textMuted, fontSize: 12),
              ),
              const SizedBox(width: AppSpacing.md),
              Icon(
                Icons.favorite_border_rounded,
                size: 14,
                color: colors.textMuted,
              ),
              const SizedBox(width: 4),
              Text(
                '${node.reactionCount}',
                style: TextStyle(color: colors.textMuted, fontSize: 12),
              ),
            ],
          ),
        ),
        trailing: Icon(
          Icons.chevron_right_rounded,
          color: colors.textMuted,
        ),
        onTap: () async {
          // Fetch full echo entity and navigate to thread
          final repo = ref.read(terminalEchoRepositoryProvider);
          final res = await repo.getEchoById(node.id);
          res.fold(
            (_) => null,
            (echo) {
              if (context.mounted) {
                unawaited(context.push(RouteNames.echoThread, extra: echo));
              }
            },
          );
        },
      ),
    );
  }
}

class _AirportBoundaryRadarPainter extends CustomPainter {
  const _AirportBoundaryRadarPainter({
    required this.boundaryColor,
    required this.radarPulseColor,
  });

  final Color boundaryColor;
  final Color radarPulseColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width * 0.42;

    final pulsePaint = Paint()
      ..color = radarPulseColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    // Draw concentric range rings (4km, 8km, 15km synthetic geofence scales)
    canvas
      ..drawCircle(center, maxRadius * 0.33, pulsePaint)
      ..drawCircle(center, maxRadius * 0.66, pulsePaint)
      ..drawCircle(center, maxRadius, pulsePaint);

    final linePaint = Paint()
      ..color = boundaryColor.withValues(alpha: 0.12)
      ..strokeWidth = 1.0;

    canvas
      ..drawLine(
        Offset(center.dx, center.dy - maxRadius),
        Offset(center.dx, center.dy + maxRadius),
        linePaint,
      )
      ..drawLine(
        Offset(center.dx - maxRadius, center.dy),
        Offset(center.dx + maxRadius, center.dy),
        linePaint,
      );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
