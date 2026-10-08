import 'package:flutter/material.dart';
import 'package:gate_closes/core/utils/context_extensions.dart';

/// One tab of [MapBottomNav].
class MapNavTab {
  const MapNavTab({required this.icon, required this.label});

  final IconData icon;
  final String label;
}

/// The Expo app's `MapBottomNav`: four tabs with a raised circular action
/// button in a dome at the center. Only the active tab shows its label.
class MapBottomNav extends StatelessWidget {
  const MapBottomNav({
    required this.tabs,
    required this.currentIndex,
    required this.onTabSelected,
    required this.onActionPressed,
    this.actionIcon = Icons.radio_button_checked_rounded,
    this.actionTooltip = 'Create an echo',
    super.key,
  }) : assert(tabs.length == 4, 'Two tabs on each side of the action');

  /// Height of the bar body, without the dome or the bottom safe area.
  /// Overlays positioned above the nav (e.g. map buttons) use this.
  static const double barHeight = 64;

  static const double _buttonSize = 55;

  // Dome proportions from Expo (Figma BNB-45): width 96.6 / 55, rise 32 / 55.
  static const double _domeWidth = _buttonSize * 1.757;
  static const double _domeRise = _buttonSize * 0.582;

  final List<MapNavTab> tabs;

  /// Index into [tabs], or -1 when none is active.
  final int currentIndex;
  final ValueChanged<int> onTabSelected;
  final VoidCallback onActionPressed;
  final IconData actionIcon;
  final String actionTooltip;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    Widget tab(int i) => Expanded(
          child: _NavTab(
            tab: tabs[i],
            active: i == currentIndex,
            onTap: () => onTabSelected(i),
          ),
        );

    return SizedBox(
      height: barHeight + bottomInset + _domeRise,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: _DomeBarPainter(
                color: colors.surface,
                borderColor: colors.hairline,
                domeWidth: _domeWidth,
                domeRise: _domeRise,
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            top: _domeRise,
            height: barHeight,
            child: Row(
              children: [
                tab(0),
                tab(1),
                const SizedBox(width: _domeWidth),
                tab(2),
                tab(3),
              ],
            ),
          ),
          Positioned(
            top: _domeRise - _buttonSize / 2 + 4,
            left: 0,
            right: 0,
            child: Center(
              child: Tooltip(
                message: actionTooltip,
                child: Material(
                  color: colors.accent,
                  shape: const CircleBorder(),
                  elevation: 6,
                  shadowColor: colors.accent.withValues(alpha: 0.5),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: onActionPressed,
                    child: SizedBox.square(
                      dimension: _buttonSize,
                      child: Icon(actionIcon, size: 26, color: colors.accentOn),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NavTab extends StatelessWidget {
  const _NavTab({required this.tab, required this.active, required this.onTap});

  final MapNavTab tab;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final color = active ? colors.accent : colors.textMuted;
    return Semantics(
      button: true,
      selected: active,
      label: tab.label,
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(tab.icon, color: color, size: 24),
            AnimatedSize(
              duration: const Duration(milliseconds: 180),
              child: active
                  ? Padding(
                      padding: const EdgeInsets.only(top: 2),
                      // One line always: a long label ("Connections")
                      // shrinks to fit instead of wrapping under the icon.
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          tab.label,
                          maxLines: 1,
                          style: TextStyle(
                            color: color,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bar body flush with the screen bottom, with a smooth dome rising in the
/// middle to cradle the action button.
class _DomeBarPainter extends CustomPainter {
  const _DomeBarPainter({
    required this.color,
    required this.borderColor,
    required this.domeWidth,
    required this.domeRise,
  });

  final Color color;
  final Color borderColor;
  final double domeWidth;
  final double domeRise;

  @override
  void paint(Canvas canvas, Size size) {
    final top = domeRise;
    final mid = size.width / 2;
    final half = domeWidth / 2;
    final path = Path()
      ..moveTo(0, top)
      ..lineTo(mid - half - 12, top)
      ..cubicTo(mid - half, top, mid - half * 0.7, 0, mid, 0)
      ..cubicTo(mid + half * 0.7, 0, mid + half, top, mid + half + 12, top)
      ..lineTo(size.width, top)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas
      ..drawShadow(path, Colors.black, 6, false)
      ..drawPath(path, Paint()..color = color)
      ..drawPath(
        path,
        Paint()
          ..color = borderColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.6,
      );
  }

  @override
  bool shouldRepaint(_DomeBarPainter old) =>
      old.color != color ||
      old.borderColor != borderColor ||
      old.domeWidth != domeWidth ||
      old.domeRise != domeRise;
}
