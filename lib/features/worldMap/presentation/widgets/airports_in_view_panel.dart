import 'package:flutter/material.dart';
import 'package:gate_closes/features/worldMap/domain/entities/airport_echo_count.dart';
import 'package:gate_closes/theme/tokens/colors.dart';
import 'package:gate_closes/theme/tokens/effects.dart';

/// The map is always dark, so its overlays use the dark palette whatever
/// the app theme.
const GateColors _kUi = GateColors.dark;

/// "Airports in view" over the zoomed-out map (Chumme's "Circles in view"):
/// how many airports with echoes are on screen, the busiest first.
/// Collapsed it shows the count and the top airport; tapped open, a short
/// list. Tapping an airport flies into it.
class AirportsInViewPanel extends StatefulWidget {
  const AirportsInViewPanel({
    required this.airports,
    required this.onTap,
    super.key,
  });

  /// In view, busiest first.
  final List<AirportEchoCount> airports;
  final ValueChanged<AirportEchoCount> onTap;

  /// Most rows listed; beyond it zooming in narrows the list.
  static const int maxRows = 20;

  @override
  State<AirportsInViewPanel> createState() => _AirportsInViewPanelState();
}

class _AirportsInViewPanelState extends State<AirportsInViewPanel> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final airports = widget.airports;
    if (airports.isEmpty) return const SizedBox.shrink();
    final rows = _open
        ? airports.take(AirportsInViewPanel.maxRows).toList()
        : [airports.first];
    final more = airports.length - AirportsInViewPanel.maxRows;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppEffects.premiumShadow,
      ),
      child: Material(
        color: _kUi.glassStrong,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: _kUi.hairline),
        ),
        clipBehavior: Clip.antiAlias,
        child: AnimatedSize(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          alignment: Alignment.bottomCenter,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              InkWell(
                onTap: () => setState(() => _open = !_open),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 10, 8, 6),
                  child: Row(
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: _kUi.accent,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'AIRPORTS IN VIEW · ${airports.length}',
                          style: TextStyle(
                            color: _kUi.textSecondary,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                      Icon(
                        _open
                            ? Icons.keyboard_arrow_down_rounded
                            : Icons.keyboard_arrow_up_rounded,
                        color: _kUi.textMuted,
                        size: 20,
                      ),
                    ],
                  ),
                ),
              ),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 260),
                child: ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.fromLTRB(6, 0, 6, 6),
                  children: [
                    for (final airport in rows)
                      _Row(
                        airport: airport,
                        onTap: () => widget.onTap(airport),
                      ),
                    if (_open && more > 0)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(10, 4, 10, 6),
                        child: Text(
                          '+$more more · zoom in to narrow',
                          style: TextStyle(color: _kUi.textMuted, fontSize: 11),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.airport, required this.onTap});

  final AirportEchoCount airport;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final name = airport.airportName?.trim();
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
        child: Row(
          children: [
            Container(
              width: 44,
              padding: const EdgeInsets.symmetric(vertical: 5),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: _kUi.surfacePressed,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                airport.airportIata,
                style: TextStyle(
                  color: _kUi.accent,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                name == null || name.isEmpty ? airport.airportIata : name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: _kUi.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${airport.count}',
              style: TextStyle(
                color: _kUi.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: _kUi.textMuted, size: 18),
          ],
        ),
      ),
    );
  }
}
