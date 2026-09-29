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
    final airport = ref.read(airportControllerProvider).airport;
    final coordinates = ref.read(airportControllerProvider).coordinates;
    if (airport == null || coordinates == null) {
      showTopToast(context, 'Could not confirm your airport. Try again.');
      return;
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
