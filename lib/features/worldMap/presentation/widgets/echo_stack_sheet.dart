import 'package:flutter/material.dart';
import 'package:gate_closes/features/worldMap/domain/entities/echo_map_features.dart';
import 'package:gate_closes/features/worldMap/domain/entities/echo_map_node_entity.dart';
import 'package:gate_closes/theme/tokens/colors.dart';
import 'package:gate_closes/theme/tokens/spacing.dart';

/// The map is always dark, so its sheets use the dark palette whatever
/// the app theme.
const GateColors _kUi = GateColors.dark;

/// Echoes that share one spot on the map. Coordinates are rounded to about
/// 110 m, so echoes from the same gate land on the same point and their
/// pins can't be split by zooming: tapping that bubble lists them here.
/// Returns the echo the user picked.
class EchoStackSheet extends StatelessWidget {
  const EchoStackSheet({required this.echoes, super.key});

  final List<TerminalEchoMapNodeEntity> echoes;

  static Future<TerminalEchoMapNodeEntity?> show(
    BuildContext context,
    List<TerminalEchoMapNodeEntity> echoes,
  ) {
    return showModalBottomSheet<TerminalEchoMapNodeEntity>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => EchoStackSheet(echoes: echoes),
    );
  }

  // Label and accent per pin type, as the pin preview (Expo NODE_VARIANTS).
  static const Map<EchoNodeKind, (String, Color)> _variants = {
    EchoNodeKind.terminalEcho: ('Terminal Echo', Color(0xFFBBE40A)),
    EchoNodeKind.parallelSoul: ('Parallel Soul', Color(0xFF50D6FF)),
    EchoNodeKind.destinationThread: ('Destination Thread', Color(0xFFFFB457)),
    EchoNodeKind.batonTouch: ('Baton Touch', Color(0xFFCF3573)),
  };

  /// Newest first; echoes without a date last.
  static List<TerminalEchoMapNodeEntity> sorted(
    List<TerminalEchoMapNodeEntity> echoes,
  ) =>
      [...echoes]..sort((a, b) {
          final at = a.createdAt;
          final bt = b.createdAt;
          if (at == null || bt == null) return at == null ? 1 : -1;
          return bt.compareTo(at);
        });

  /// "Just now", "5 min ago", "3 h ago", "2 d ago".
  static String age(DateTime? createdAt, DateTime now) {
    if (createdAt == null) return '';
    final d = now.difference(createdAt);
    if (d.inMinutes < 1) return 'Just now';
    if (d.inHours < 1) return '${d.inMinutes} min ago';
    if (d.inDays < 1) return '${d.inHours} h ago';
    return '${d.inDays} d ago';
  }

  static String _detail(TerminalEchoMapNodeEntity echo, DateTime now) => [
        age(echo.createdAt, now),
        if (echo.listenCount > 0)
          '${echo.listenCount} listen${echo.listenCount == 1 ? '' : 's'}',
        if (echo.reactionCount > 0)
          echo.reactionCount == 1
              ? '1 reaction'
              : '${echo.reactionCount} reactions',
      ].where((s) => s.isNotEmpty).join(' · ');

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final items = sorted(echoes);
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: items.length > 4 ? 0.6 : 0.4,
      minChildSize: 0.3,
      maxChildSize: 0.9,
      // Material, not a colored box: the rows' ink ripples paint on it.
      builder: (context, scroll) => Material(
        color: _kUi.surfaceElevated,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            AppSpacing.v(AppSpacing.sm),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: _kUi.borderStrong,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.sm,
              ),
              child: Text(
                '${items.length} echoes here',
                style: TextStyle(
                  color: _kUi.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Expanded(
              child: ListView.builder(
                controller: scroll,
                itemCount: items.length,
                itemBuilder: (context, i) {
                  final echo = items[i];
                  final (label, color) = _variants[echo.nodeKind]!;
                  final badge = EchoMapFeatures.typeKey(echo.nodeKind)
                      .replaceAll('_', '-');
                  return ListTile(
                    key: ValueKey(echo.id),
                    leading: Image.asset(
                      'assets/map_badges/badge-$badge.png',
                      width: 36,
                      height: 36,
                    ),
                    title: Text(
                      label,
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Text(
                      _detail(echo, now),
                      style: TextStyle(color: _kUi.textSecondary),
                    ),
                    trailing: Icon(
                      Icons.chevron_right,
                      color: _kUi.textMuted,
                    ),
                    onTap: () => Navigator.of(context).pop(echo),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
