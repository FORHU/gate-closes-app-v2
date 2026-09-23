import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart' as ap;
import 'package:flutter/material.dart';
import 'package:flutter_template/core/utils/context_extensions.dart';
import 'package:flutter_template/theme/tokens/colors.dart';
import 'package:flutter_template/theme/tokens/spacing.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

/// Record → review/playback → confirm. Shared by Terminal Echo's composer
/// and Messaging's voice messages — both need the exact same record/review
/// mechanics, differing only in what happens after [onRecorded] fires.
///
/// This widget owns recording and local playback only; it does not upload
/// or call any API — the caller does that with the file/duration/waveform
/// it hands back, since the two callers need different next steps (Feed
/// shows a caption step first, Messaging can send immediately).
class VoiceRecorderComposer extends StatefulWidget {
  const VoiceRecorderComposer({
    required this.onRecorded,
    this.onCancel,
    this.maxDuration = const Duration(seconds: 10),
    super.key,
  });

  /// Fired once the user confirms a completed recording.
  final void Function(File file, double durationSeconds, List<double> waveform)
      onRecorded;

  final VoidCallback? onCancel;
  final Duration maxDuration;

  @override
  State<VoiceRecorderComposer> createState() => _VoiceRecorderComposerState();
}

enum _RecorderPhase { idle, recording, review }

class _VoiceRecorderComposerState extends State<VoiceRecorderComposer> {
  final _recorder = AudioRecorder();
  final _player = ap.AudioPlayer();

  _RecorderPhase _phase = _RecorderPhase.idle;
  Timer? _ticker;
  StreamSubscription<Amplitude>? _amplitudeSub;
  Duration _elapsed = Duration.zero;
  final List<double> _waveform = [];
  String? _recordedPath;
  bool _isPlayingReview = false;

  @override
  void dispose() {
    _ticker?.cancel();
    unawaited(_amplitudeSub?.cancel());
    unawaited(_recorder.dispose());
    unawaited(_player.dispose());
    super.dispose();
  }

  Future<void> _startRecording() async {
    if (!await _recorder.hasPermission()) return;

    final dir = await getTemporaryDirectory();
    final path =
        '${dir.path}/echo_${DateTime.now().millisecondsSinceEpoch}.m4a';

    _waveform.clear();
    _elapsed = Duration.zero;

    await _recorder.start(const RecordConfig(), path: path);

    setState(() => _phase = _RecorderPhase.recording);

    _ticker = Timer.periodic(const Duration(milliseconds: 100), (_) {
      setState(() => _elapsed += const Duration(milliseconds: 100));
      if (_elapsed >= widget.maxDuration) unawaited(_stopRecording());
    });

    _amplitudeSub = _recorder
        .onAmplitudeChanged(const Duration(milliseconds: 100))
        .listen((amp) {
      // Normalize dB (~-60 silence .. 0 loud) to a 0..1 waveform
      // sample — the backend just stores/replays these, no
      // required range, but 0..1 makes rendering trivial.
      final normalized = ((amp.current + 60) / 60).clamp(0.0, 1.0);
      _waveform.add(normalized);
    });
  }

  Future<void> _stopRecording() async {
    _ticker?.cancel();
    await _amplitudeSub?.cancel();
    final path = await _recorder.stop();
    if (!mounted) return;
    setState(() {
      _recordedPath = path;
      _phase = _RecorderPhase.review;
    });
  }

  Future<void> _togglePreview() async {
    final path = _recordedPath;
    if (path == null) return;

    if (_isPlayingReview) {
      await _player.stop();
      setState(() => _isPlayingReview = false);
      return;
    }

    setState(() => _isPlayingReview = true);
    await _player.play(ap.DeviceFileSource(path));
    unawaited(
      _player.onPlayerComplete.first.then((_) {
        if (mounted) setState(() => _isPlayingReview = false);
      }),
    );
  }

  void _discard() {
    final path = _recordedPath;
    if (path != null) {
      unawaited(File(path).delete().catchError((_) => File(path)));
    }
    setState(() {
      _phase = _RecorderPhase.idle;
      _recordedPath = null;
      _waveform.clear();
      _elapsed = Duration.zero;
    });
  }

  void _confirm() {
    final path = _recordedPath;
    if (path == null) return;
    widget.onRecorded(
      File(path),
      _elapsed.inMilliseconds / 1000,
      List<double>.of(_waveform),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return switch (_phase) {
      _RecorderPhase.idle =>
        _IdleState(onStart: _startRecording, onCancel: widget.onCancel),
      _RecorderPhase.recording => _RecordingState(
          elapsed: _elapsed,
          maxDuration: widget.maxDuration,
          waveform: _waveform,
          onStop: _stopRecording,
        ),
      _RecorderPhase.review => _ReviewState(
          durationSeconds: _elapsed.inMilliseconds / 1000,
          waveform: _waveform,
          isPlaying: _isPlayingReview,
          onTogglePlay: _togglePreview,
          onDiscard: _discard,
          onConfirm: _confirm,
          colors: colors,
        ),
    };
  }
}

class _IdleState extends StatelessWidget {
  const _IdleState({required this.onStart, this.onCancel});

  final VoidCallback onStart;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (onCancel != null)
          TextButton(
            onPressed: onCancel,
            child: Text('Cancel', style: TextStyle(color: colors.textMuted)),
          ),
        const SizedBox(width: AppSpacing.md),
        GestureDetector(
          onTap: onStart,
          child: Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: colors.accent,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(color: colors.accentGlow20, blurRadius: 20),
              ],
            ),
            child: Icon(Icons.mic_rounded, color: colors.accentOn, size: 30),
          ),
        ),
      ],
    );
  }
}

class _RecordingState extends StatelessWidget {
  const _RecordingState({
    required this.elapsed,
    required this.maxDuration,
    required this.waveform,
    required this.onStop,
  });

  final Duration elapsed;
  final Duration maxDuration;
  final List<double> waveform;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final remaining = maxDuration - elapsed;
    final seconds = (remaining.inMilliseconds / 1000).clamp(0, 999);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 40,
          child: _StaticWaveform(samples: waveform, color: colors.error),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          '${seconds.toStringAsFixed(0)}s left',
          style: TextStyle(color: colors.textSecondary, fontSize: 12),
        ),
        const SizedBox(height: AppSpacing.sm),
        GestureDetector(
          onTap: onStop,
          child: Container(
            width: 64,
            height: 64,
            decoration:
                BoxDecoration(color: colors.error, shape: BoxShape.circle),
            child:
                const Icon(Icons.stop_rounded, color: Colors.white, size: 28),
          ),
        ),
      ],
    );
  }
}

class _ReviewState extends StatelessWidget {
  const _ReviewState({
    required this.durationSeconds,
    required this.waveform,
    required this.isPlaying,
    required this.onTogglePlay,
    required this.onDiscard,
    required this.onConfirm,
    required this.colors,
  });

  final double durationSeconds;
  final List<double> waveform;
  final bool isPlaying;
  final VoidCallback onTogglePlay;
  final VoidCallback onDiscard;
  final VoidCallback onConfirm;
  final GateColors colors;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          onPressed: onDiscard,
          icon: Icon(Icons.delete_outline_rounded, color: colors.error),
        ),
        GestureDetector(
          onTap: onTogglePlay,
          child: Container(
            width: 40,
            height: 40,
            decoration:
                BoxDecoration(color: colors.accent, shape: BoxShape.circle),
            child: Icon(
              isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
              color: colors.accentOn,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: SizedBox(
            height: 32,
            child: _StaticWaveform(samples: waveform, color: colors.accent),
          ),
        ),
        Text(
          '${durationSeconds.toStringAsFixed(0)}s',
          style: TextStyle(color: colors.textSecondary, fontSize: 12),
        ),
        const SizedBox(width: AppSpacing.sm),
        IconButton(
          onPressed: onConfirm,
          icon: Icon(Icons.send_rounded, color: colors.accent),
        ),
      ],
    );
  }
}

/// Simple bar-chart waveform — enough for record/review; playback uses the
/// shared `WaveformPlayer` widget instead.
class _StaticWaveform extends StatelessWidget {
  const _StaticWaveform({required this.samples, required this.color});

  final List<double> samples;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.infinite,
      painter: _WaveformPainter(samples: samples, color: color),
    );
  }
}

class _WaveformPainter extends CustomPainter {
  _WaveformPainter({required this.samples, required this.color});

  final List<double> samples;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (samples.isEmpty) return;
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    // Show only the most recent N samples so the bar width stays legible
    // regardless of how long the recording runs.
    const maxBars = 60;
    final visible = samples.length > maxBars
        ? samples.sublist(samples.length - maxBars)
        : samples;

    final barWidth = size.width / maxBars;
    final startX = size.width - visible.length * barWidth;

    for (var i = 0; i < visible.length; i++) {
      final x = startX + i * barWidth + barWidth / 2;
      final barHeight = (visible[i] * size.height).clamp(3.0, size.height);
      canvas.drawLine(
        Offset(x, size.height / 2 - barHeight / 2),
        Offset(x, size.height / 2 + barHeight / 2),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _WaveformPainter oldDelegate) =>
      oldDelegate.samples.length != samples.length;
}
