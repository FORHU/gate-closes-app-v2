import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gate_closes/core/utils/context_extensions.dart';
import 'package:gate_closes/features/airport/domain/entities/airport_entity.dart';
import 'package:gate_closes/features/airport/presentation/controllers/airport_controller.dart';
import 'package:gate_closes/features/terminal_echo/presentation/controllers/terminal_echo_controller.dart';
import 'package:gate_closes/features/terminal_echo/presentation/widgets/echo_card.dart';
import 'package:gate_closes/routes/route_names.dart';
import 'package:gate_closes/shared/widgets/app_state_view.dart';
import 'package:gate_closes/theme/tokens/colors.dart';
import 'package:gate_closes/theme/tokens/spacing.dart';
import 'package:go_router/go_router.dart';

/// Terminal Echo feed — ephemeral spatial posts anchored to the user's
/// current airport. Airport is resolved via `AirportController.
/// detectAirport()` (Phase 6); the feed itself via `TerminalEchoController.
/// loadFeed(iata)`.
///
/// Search browses another airport's feed (`feedAirportOverrideProvider`,
/// Expo's `searchFeed`) until the user clears it.
class FeedPage extends ConsumerStatefulWidget {
  const FeedPage({super.key});

  @override
  ConsumerState<FeedPage> createState() => _FeedPageState();
}

class _FeedPageState extends ConsumerState<FeedPage> {
  @override
  void initState() {
    super.initState();
    // Deferred: loading writes provider state, which isn't allowed while the
    // page is still being built (same pattern as ProfilePage).
    unawaited(Future.microtask(_init));
  }

  Future<void> _init() async {
    await ref.read(airportControllerProvider.notifier).detectAirport();
    if (!mounted) return;
    final airport = ref.read(feedAirportOverrideProvider) ??
        ref.read(airportControllerProvider).airport;
    if (airport != null) {
      await ref
          .read(terminalEchoControllerProvider.notifier)
          .loadFeed(airport.iata);
    }
  }

  Future<void> _searchAirport() async {
    final picked = await context.push<AirportEntity>(RouteNames.airportSearch);
    if (picked == null || !mounted) return;
    ref.read(feedAirportOverrideProvider.notifier).browse(
          picked,
          detected: ref.read(airportControllerProvider).airport,
        );
    await ref
        .read(terminalEchoControllerProvider.notifier)
        .loadFeed(picked.iata);
  }

  Future<void> _clearSearch() async {
    ref.read(feedAirportOverrideProvider.notifier).clear();
    final detected = ref.read(airportControllerProvider).airport;
    if (detected != null) {
      await ref
          .read(terminalEchoControllerProvider.notifier)
          .loadFeed(detected.iata);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final airportState = ref.watch(airportControllerProvider);
    final browsed = ref.watch(feedAirportOverrideProvider);
    final airport = browsed ?? airportState.airport;
    final echoState = ref.watch(terminalEchoControllerProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          airport != null ? 'Terminal Echo — ${airport.iata}' : 'Terminal Echo',
          style:
              TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.search_rounded, color: colors.textPrimary),
            onPressed: () => unawaited(_searchAirport()),
          ),
        ],
      ),
      body: Column(
        children: [
          if (browsed != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.sm,
                AppSpacing.md,
                0,
              ),
              child: Align(
                alignment: Alignment.centerLeft,
                child: InputChip(
                  avatar: const Icon(Icons.flight_rounded, size: 16),
                  label: Text(
                    browsed.name,
                    overflow: TextOverflow.ellipsis,
                  ),
                  deleteButtonTooltipMessage: 'Back to my airport',
                  onDeleted: () => unawaited(_clearSearch()),
                ),
              ),
            ),
          Expanded(
            child: _buildBody(colors, airportState, airport, echoState),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(
    GateColors colors,
    AirportState airportState,
    AirportEntity? airport,
    TerminalEchoState echoState,
  ) {
    if (airport == null && airportState.isDetecting) {
      return const Center(child: CircularProgressIndicator());
    }

    if (airport == null) {
      return AppStateView(
        kind: AppStateKind.empty,
        title: 'No airport detected',
        message: airportState.error ??
            "We couldn't find an airport near you. Terminal Echo is scoped "
                'to a specific airport.',
        actionLabel: 'Retry',
        onAction: () => unawaited(_init()),
      );
    }

    if (echoState.isLoading && echoState.echoes.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (echoState.error != null && echoState.echoes.isEmpty) {
      return AppStateView(
        kind: AppStateKind.error,
        title: 'Could not load the feed',
        message: echoState.error,
        actionLabel: 'Retry',
        onAction: () => unawaited(_init()),
      );
    }

    if (echoState.echoes.isEmpty) {
      return const AppStateView(
        kind: AppStateKind.empty,
        title: 'No echoes yet',
        message: 'Be the first to post here.',
      );
    }

    return RefreshIndicator(
      onRefresh: () => ref
          .read(terminalEchoControllerProvider.notifier)
          .loadFeed(airport.iata),
      child: ListView.separated(
        padding: AppSpacing.edgeInsetsMd,
        itemCount: echoState.echoes.length,
        separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
        itemBuilder: (context, index) =>
            EchoCard(echo: echoState.echoes[index]),
      ),
    );
  }
}
