import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_template/core/utils/context_extensions.dart';
import 'package:flutter_template/features/worldMap/presentation/controllers/world_map_controller.dart';
import 'package:flutter_template/shared/widgets/app_card.dart';
import 'package:flutter_template/shared/widgets/app_state_view.dart';
import 'package:flutter_template/theme/tokens/spacing.dart';

/// Nearby-airports list — device location + `GET /airport/nearby`, both
/// already-real endpoints (see [WorldMapController]). This is a list-view
/// placeholder for the map itself — swap in a real map SDK (`flutter_map`,
/// `mapbox_maps_flutter`) once you've picked one; nothing below this widget
/// needs to change.
class WorldMapPage extends ConsumerWidget {
  const WorldMapPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(worldMapControllerProvider);
    final colors = context.colors;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: Text(
          context.l10n.worldMap,
          style: TextStyle(color: colors.textPrimary),
        ),
        backgroundColor: colors.background,
        elevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: () =>
            ref.read(worldMapControllerProvider.notifier).fetchNearbyAirports(),
        child: _buildBody(context, ref, state),
      ),
    );
  }

  Widget _buildBody(BuildContext context, WidgetRef ref, WorldMapState state) {
    final colors = context.colors;
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
            ref.read(worldMapControllerProvider.notifier).fetchNearbyAirports(),
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
        return AppCard(
          child: Row(
            children: [
              Icon(Icons.flight_takeoff_rounded, color: colors.accent),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      airport.name,
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      [
                        airport.iata,
                        if (airport.countryCode != null) airport.countryCode,
                      ].join(' · '),
                      style: TextStyle(color: colors.textSecondary),
                    ),
                  ],
                ),
              ),
              if (airport.distanceKm != null)
                Text(
                  '${airport.distanceKm!.toStringAsFixed(0)} km',
                  style: TextStyle(
                    color: colors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
