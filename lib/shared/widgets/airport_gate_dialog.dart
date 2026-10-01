import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gate_closes/core/utils/context_extensions.dart';
import 'package:gate_closes/features/airport/presentation/controllers/airport_controller.dart';
import 'package:gate_closes/theme/tokens/spacing.dart';

/// The Expo app's `AirportGateModal`: before creating an echo, check live that
/// the user is inside an airport boundary ("Locating You" → "Airport Detected"
/// or "Outside Airport"). Resolves to true when the user chose to continue.
class AirportGateDialog extends ConsumerStatefulWidget {
  const AirportGateDialog._();

  static Future<bool> show(BuildContext context) async {
    final proceed = await showDialog<bool>(
      context: context,
      builder: (_) => const AirportGateDialog._(),
    );
    return proceed ?? false;
  }

  @override
  ConsumerState<AirportGateDialog> createState() => _AirportGateDialogState();
}

enum _GateStatus { checking, inside, outside }

class _AirportGateDialogState extends ConsumerState<AirportGateDialog> {
  _GateStatus _status = _GateStatus.checking;

  @override
  void initState() {
    super.initState();
    unawaited(_check());
  }

  Future<void> _check() async {
    // detectAirport updates provider state right away, which isn't allowed
    // while the dialog is still being built — start after the first frame.
    await Future<void>.delayed(Duration.zero);
    if (!mounted) return;
    await ref.read(airportControllerProvider.notifier).detectAirport();
    if (!mounted) return;
    setState(
      () => _status = ref.read(airportControllerProvider).isInsideAirport
          ? _GateStatus.inside
          : _GateStatus.outside,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final airportName = ref.watch(airportControllerProvider).airport?.name;
    final (title, message) = switch (_status) {
      _GateStatus.checking => (
          'Locating You',
          "Checking whether you're inside an airport...",
        ),
      _GateStatus.inside => (
          'Airport Detected',
          'You are currently inside ${airportName ?? 'an airport'}. '
              'Ready to create your echo?',
        ),
      _GateStatus.outside => (
          'Outside Airport',
          'You must be inside an airport to create an echo. Move within an '
              'airport and try again.',
        ),
    };
    final isOutside = _status == _GateStatus.outside;

    return Dialog(
      backgroundColor: colors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: AppSpacing.edgeInsetsLg,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 36,
              backgroundColor: isOutside ? colors.error : colors.accent,
              child: _status == _GateStatus.checking
                  ? CircularProgressIndicator(color: colors.accentOn)
                  : Icon(
                      isOutside
                          ? Icons.error_outline_rounded
                          : Icons.location_on_rounded,
                      size: 36,
                      color: Colors.white,
                    ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              title,
              style: TextStyle(
                color: colors.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: colors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.lg),
            if (_status == _GateStatus.inside)
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('Create an Echo'),
                ),
              )
            else if (isOutside)
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Understood'),
                ),
              ),
            if (!isOutside)
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
          ],
        ),
      ),
    );
  }
}
