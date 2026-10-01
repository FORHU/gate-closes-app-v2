import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gate_closes/core/services/file_upload_service.dart';
import 'package:gate_closes/core/utils/context_extensions.dart';
import 'package:gate_closes/features/airport/presentation/controllers/airport_controller.dart';
import 'package:gate_closes/features/terminal_echo/presentation/controllers/terminal_echo_controller.dart';
import 'package:gate_closes/shared/widgets/modern_text_field.dart';
import 'package:gate_closes/shared/widgets/top_toast.dart';
import 'package:gate_closes/shared/widgets/voice_recorder_composer.dart';
import 'package:gate_closes/theme/tokens/spacing.dart';

/// Expo's "Outside Terminal Zone" alert. Resolves to true on "Post Anyway".
Future<bool> confirmPostOutsideAirport(
  BuildContext context,
  String airportName,
) async {
  final proceed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Outside Terminal Zone'),
      content: Text(
        'You are currently outside the protected radius of $airportName. '
        'Your echo will still be posted but may not be as visible to '
        'travelers at the gate.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Post Anyway'),
        ),
      ],
    ),
  );
  return proceed ?? false;
}

/// Compose a Terminal Echo. A voice memo is mandatory on the real API
/// (`TerminalEchoCtrl.create`'s Joi schema requires `fileUrl`/`fileName`) —
/// the text field below is only ever an optional caption, matching RN's
/// create-echo screen.
class CreateEchoPage extends ConsumerStatefulWidget {
  const CreateEchoPage({super.key});

  @override
  ConsumerState<CreateEchoPage> createState() => _CreateEchoPageState();
}

class _CreateEchoPageState extends ConsumerState<CreateEchoPage> {
  final _captionController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _captionController.dispose();
    super.dispose();
  }

  Future<void> _onRecorded(
    File file,
    double durationSeconds,
    List<double> waveform,
  ) async {
    final airportState = ref.read(airportControllerProvider);
    final airport = airportState.airport;
    final coordinates = airportState.coordinates;
    if (airport == null || coordinates == null) {
      showTopToast(context, 'Could not confirm your airport. Try again.');
      return;
    }

    // Expo re-checks at send time: the user may have left the airport's
    // radius while recording (the map re-detects every 250 m).
    if (!airportState.isInsideAirport) {
      final proceed = await confirmPostOutsideAirport(context, airport.name);
      if (!proceed || !mounted) return;
    }

    setState(() => _isSubmitting = true);

    final uploadResult =
        await ref.read(fileUploadServiceProvider).uploadAudio(file);

    final uploaded = uploadResult.fold(
      (failure) {
        showTopToast(context, failure.message);
        return null;
      },
      (uploaded) => uploaded,
    );

    if (uploaded == null) {
      setState(() => _isSubmitting = false);
      return;
    }

    final ok = await ref.read(terminalEchoControllerProvider.notifier).postEcho(
          textMessage: _captionController.text.trim(),
          airportName: airport.name,
          coordinates: coordinates,
          fileUrl: uploaded.url,
          fileName: file.uri.pathSegments.last,
          audioDuration: durationSeconds,
          waveformData: waveform,
        );

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (ok) {
      Navigator.of(context).pop();
    } else {
      final error = ref.read(terminalEchoControllerProvider).error;
      if (error != null) showTopToast(context, error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.background,
        elevation: 0,
        title: Text(
          'New Echo',
          style:
              TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w700),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: AppSpacing.edgeInsetsLg,
          child: Column(
            children: [
              Text(
                'Record up to 10 seconds — visible to everyone at your '
                'airport right now.',
                textAlign: TextAlign.center,
                style: TextStyle(color: colors.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: AppSpacing.lg),
              ModernTextField(
                label: 'Caption (optional)',
                hint: "What's happening?",
                controller: _captionController,
                prefixIcon: Icons.text_fields_rounded,
              ),
              const Spacer(),
              if (_isSubmitting)
                const CircularProgressIndicator()
              else
                VoiceRecorderComposer(
                  onRecorded: (file, duration, waveform) =>
                      unawaited(_onRecorded(file, duration, waveform)),
                  onCancel: () => Navigator.of(context).pop(),
                ),
              const SizedBox(height: AppSpacing.xl),
            ],
          ),
        ),
      ),
    );
  }
}
