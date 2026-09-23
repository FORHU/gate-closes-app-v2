import 'dart:async';

import 'package:audioplayers/audioplayers.dart' as ap;
import 'package:flutter/material.dart';
import 'package:flutter_template/core/utils/context_extensions.dart';
import 'package:flutter_template/theme/tokens/spacing.dart';

/// Compact inline audio player rendering a stored `waveformData` sample
/// list — shared by Terminal Echo cards and Messaging bubbles, both of
/// which store/replay the same `{fileUrl, audioDuration, waveformData}`
/// shape.
class WaveformPlayer extends StatefulWidget {
  const WaveformPlayer({
    required this.audioUrl,
    required this.waveformData,
    required this.durationSeconds,
    this.onListenThresholdReached,
    super.key,
  });

  final String audioUrl;
  final List<double> waveformData;
  final double durationSeconds;

  /// Fired once when playback crosses 70% — matches the RN app's listen
  /// tracking threshold for `incrementListen`.
  final VoidCallback? onListenThresholdReached;

  @override
  State<WaveformPlayer> createState() => _WaveformPlayerState();
}

class _WaveformPlayerState extends State<WaveformPlayer> {
  final _player = ap.AudioPlayer();
  bool _isPlaying = false;
  Duration _position = Duration.zero;
  bool _thresholdFired = false;
  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<void>? _completeSub;

  @override
  void initState() {
    super.initState();
    _positionSub = _player.onPositionChanged.listen((position) {
      if (!mounted) return;
      setState(() => _position = position);

      final total = widget.durationSeconds;
      if (!_thresholdFired &&
          total > 0 &&
          position.inMilliseconds / 1000 / total >= 0.7) {
        _thresholdFired = true;
        widget.onListenThresholdReached?.call();
      }
    });
    _completeSub = _player.onPlayerComplete.listen((_) {
      if (!mounted) return;
      setState(() {
        _isPlaying = false;
        _position = Duration.zero;
      });
    });
  }

  @override
  void dispose() {
    unawaited(_positionSub?.cancel());
    unawaited(_completeSub?.cancel());
    unawaited(_player.dispose());
    super.dispose();
  }

  Future<void> _toggle() async {
    if (_isPlaying) {
      await _player.pause();
      setState(() => _isPlaying = false);
    } else {
      await _player.play(ap.UrlSource(widget.audioUrl));
      setState(() => _isPlaying = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final progress = widget.durationSeconds > 0
        ? (_position.inMilliseconds / 1000 / widget.durationSeconds).clamp(
            0.0,
            1.0,
          )
        : 0.0;

    return Row(
      children: [
        GestureDetector(
          onTap: _toggle,
          child: Container(
            width: 36,
            height: 36,
            decoration:
                BoxDecoration(color: colors.accent, shape: BoxShape.circle),
            child: Icon(
              _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
              color: colors.accentOn,
              size: 20,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: SizedBox(
            height: 28,
            child: CustomPaint(
              painter: _WaveformProgressPainter(
                samples: widget.waveformData,
                progress: progress,
                playedColor: colors.accent,
                unplayedColor: colors.border,
              ),
              size: Size.infinite,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        Text(
          _formatDuration(widget.durationSeconds),
          style: TextStyle(color: colors.textMuted, fontSize: 11),
        ),
      ],
    );
  }

  String _formatDuration(double seconds) {
    final s = seconds.round();
    return '0:${s.toString().padLeft(2, '0')}';
  }
}

class _WaveformProgressPainter extends CustomPainter {
  _WaveformProgressPainter({
    required this.samples,
    required this.progress,
    required this.playedColor,
    required this.unplayedColor,
  });

  final List<double> samples;
  final double progress;
  final Color playedColor;
  final Color unplayedColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (samples.isEmpty) return;

    final barWidth = size.width / samples.length;
    final playedBars = (samples.length * progress).round();

    for (var i = 0; i < samples.length; i++) {
      final paint = Paint()
        ..color = i < playedBars ? playedColor : unplayedColor
        ..strokeWidth = (barWidth * 0.6).clamp(1.5, 4.0)
        ..strokeCap = StrokeCap.round;

      final x = i * barWidth + barWidth / 2;
      final barHeight = (samples[i] * size.height).clamp(3.0, size.height);
      canvas.drawLine(
        Offset(x, size.height / 2 - barHeight / 2),
        Offset(x, size.height / 2 + barHeight / 2),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _WaveformProgressPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.samples != samples;
}
