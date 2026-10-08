import 'package:flutter/material.dart';
import 'package:gate_closes/features/worldMap/domain/entities/airport_point.dart';
import 'package:gate_closes/theme/tokens/colors.dart';
import 'package:gate_closes/theme/tokens/spacing.dart';

/// The map is always dark, so its sheets use the dark palette whatever
/// the app theme.
const GateColors _kUi = GateColors.dark;

/// A country's airports, from tapping the country on the zoomed-out map:
/// busiest first, each with its echo count. Returns the airport picked, or
/// null.
class CountryAirportsSheet extends StatelessWidget {
  const CountryAirportsSheet({
    required this.country,
    required this.airports,
    required this.counts,
    super.key,
  });

  final String country;
  final List<AirportPoint> airports;

  /// Echoes per airport code.
  final Map<String, int> counts;

  static Future<AirportPoint?> show(
    BuildContext context, {
    required String country,
    required List<AirportPoint> airports,
    required Map<String, int> counts,
  }) {
    return showModalBottomSheet<AirportPoint>(
      context: context,
      // Above the map's navigation bar, which would cover its bottom.
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CountryAirportsSheet(
        country: country,
        airports: airports,
        counts: counts,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final echoes = airports.fold<int>(0, (n, a) => n + (counts[a.iata] ?? 0));
    return Material(
      color: _kUi.surfaceElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      clipBehavior: Clip.antiAlias,
      child: SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.7,
          ),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.sm,
              AppSpacing.md,
              AppSpacing.lg,
            ),
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: _kUi.borderStrong,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              AppSpacing.v(AppSpacing.md),
              Text(
                country.toUpperCase(),
                style: TextStyle(
                  color: _kUi.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.1,
                ),
              ),
              AppSpacing.v(AppSpacing.xs),
              Text(
                '${airports.length} '
                '${airports.length == 1 ? 'AIRPORT' : 'AIRPORTS'} · '
                '$echoes ${echoes == 1 ? 'ECHO' : 'ECHOES'}',
                style: TextStyle(
                  color: _kUi.accent,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.8,
                ),
              ),
              AppSpacing.v(AppSpacing.sm),
              if (airports.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                  child: Text(
                    'No airports here yet.',
                    style: TextStyle(color: _kUi.textSecondary),
                  ),
                ),
              for (final airport in airports)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    width: 52,
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: _kUi.surface,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      airport.iata,
                      style: TextStyle(
                        color: _kUi.accent,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  title: Text(
                    airport.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: _kUi.textPrimary),
                  ),
                  trailing: Text(
                    '${counts[airport.iata] ?? 0}',
                    style: TextStyle(color: _kUi.textSecondary),
                  ),
                  onTap: () => Navigator.of(context).pop(airport),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
