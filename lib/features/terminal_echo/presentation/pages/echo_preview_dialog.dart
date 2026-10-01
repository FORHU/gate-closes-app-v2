import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gate_closes/core/utils/context_extensions.dart';
import 'package:gate_closes/features/auth/presentation/controllers/auth_controller.dart';
import 'package:gate_closes/features/terminal_echo/domain/entities/terminal_echo_entity.dart';
import 'package:gate_closes/features/terminal_echo/presentation/controllers/terminal_echo_controller.dart';
import 'package:gate_closes/features/terminal_echo/presentation/widgets/echo_card.dart';
import 'package:gate_closes/routes/route_names.dart';
import 'package:gate_closes/theme/tokens/spacing.dart';
import 'package:go_router/go_router.dart';

/// The card shown when a map pin is tapped — Expo's echo modal in
/// `TerminalMapNodesLayer.tsx`: the echo (play, react, open the thread) and,
/// for a Parallel Soul / Destination Thread / Baton Touch pin, START
/// CONVERSATION with its sender.
///
/// [affinity] is the pin's type key (`terminal_echo`, `parallel_soul`, ...).
class EchoPreviewDialog extends ConsumerStatefulWidget {
  const EchoPreviewDialog({
    required this.echoId,
    this.affinity = 'terminal_echo',
    super.key,
  });

  final String echoId;
  final String affinity;

  @override
  ConsumerState<EchoPreviewDialog> createState() => _EchoPreviewDialogState();
}

class _EchoPreviewDialogState extends ConsumerState<EchoPreviewDialog> {
  TerminalEchoEntity? _echo;
  String? _error;

  // Label and accent per pin type, from Expo's NODE_VARIANTS.
  static const _variants = {
    'terminal_echo': ('TERMINAL ECHO', Color(0xFFBBE40A)),
    'parallel_soul': ('PARALLEL SOUL', Color(0xFF50D6FF)),
    'destination_thread': ('DESTINATION THREAD', Color(0xFFFFB457)),
    'baton_touch': ('BATON TOUCH', Color(0xFFCF3573)),
  };

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final result = await ref
        .read(terminalEchoRepositoryProvider)
        .getEchoById(widget.echoId);
    if (!mounted) return;
    setState(() {
      result.fold(
        (failure) => _error = failure.message,
        (echo) {
          _echo = echo;
          _error = null;
        },
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final (label, accent) =
        _variants[widget.affinity] ?? _variants['terminal_echo']!;
    final echo = _echo;
    final myId = ref.watch(authControllerProvider).user?.id;
    final canMessage = widget.affinity != 'terminal_echo' &&
        echo != null &&
        echo.senderId.isNotEmpty &&
        echo.senderId != myId;

    return Dialog(
      backgroundColor: colors.surface,
      insetPadding: const EdgeInsets.all(AppSpacing.md),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: AppSpacing.edgeInsetsMd,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: accent,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Close',
                  icon: Icon(Icons.close_rounded, color: colors.textSecondary),
                  onPressed: () => context.pop(),
                ),
              ],
            ),
            if (echo != null)
              EchoCard(echo: echo, onReacted: _load)
            else if (_error != null)
              Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Row(
                  children: [
                    Icon(
                      Icons.error_outline_rounded,
                      color: colors.textSecondary,
                      size: 18,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        _error!,
                        style: TextStyle(color: colors.textSecondary),
                      ),
                    ),
                  ],
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Center(
                  child: CircularProgressIndicator(color: accent),
                ),
              ),
            if (canMessage) ...[
              const SizedBox(height: AppSpacing.md),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: accent,
                  foregroundColor: const Color(0xFF060606),
                ),
                icon: const Icon(Icons.send_rounded, size: 16),
                label: const Text(
                  'START CONVERSATION',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                onPressed: () {
                  final router = GoRouter.of(context)..pop();
                  unawaited(
                    router.push(
                      RouteNames.connectionDraftFor(
                        echo.senderId,
                        widget.affinity,
                      ),
                    ),
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}
