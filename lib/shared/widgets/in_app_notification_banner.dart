import 'dart:async';

import 'package:flutter/material.dart';
import 'package:gate_closes/core/utils/context_extensions.dart';

/// The banner on screen now, so a new one replaces it instead of stacking.
OverlayEntry? _current;

/// Shows a notification as a banner at the top of the app (used while the
/// app is on screen instead of the phone's notification panel). Tapping it
/// runs [onTap]; swiping it up or waiting [duration] dismisses it. Built
/// like `showTopToast`: on the root overlay, so it survives route changes.
void showInAppNotificationBanner(
  OverlayState overlay, {
  required String title,
  required String body,
  required VoidCallback onTap,
  Duration duration = const Duration(seconds: 4),
}) {
  _dismissCurrent();
  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => _InAppNotificationBanner(
      title: title,
      body: body,
      duration: duration,
      onTap: onTap,
      onDismissed: () {
        if (identical(_current, entry)) _current = null;
        if (entry.mounted) entry.remove();
      },
    ),
  );
  _current = entry;
  overlay.insert(entry);
}

void _dismissCurrent() {
  final current = _current;
  _current = null;
  if (current != null && current.mounted) current.remove();
}

class _InAppNotificationBanner extends StatefulWidget {
  const _InAppNotificationBanner({
    required this.title,
    required this.body,
    required this.duration,
    required this.onTap,
    required this.onDismissed,
  });

  final String title;
  final String body;
  final Duration duration;
  final VoidCallback onTap;
  final VoidCallback onDismissed;

  @override
  State<_InAppNotificationBanner> createState() =>
      _InAppNotificationBannerState();
}

class _InAppNotificationBannerState extends State<_InAppNotificationBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 250),
  );
  late final Animation<double> _fade = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOut,
  );
  late final Animation<Offset> _slide = Tween<Offset>(
    begin: const Offset(0, -0.4),
    end: Offset.zero,
  ).animate(_fade);

  Timer? _timer;
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    unawaited(_controller.forward());
    _timer = Timer(widget.duration, _dismiss);
  }

  void _dismiss() {
    if (!mounted || _closing) return;
    _closing = true;
    _timer?.cancel();
    unawaited(_reverseAndRemove());
  }

  Future<void> _reverseAndRemove() async {
    await _controller.reverse();
    widget.onDismissed();
  }

  void _open() {
    if (_closing) return;
    _closing = true;
    _timer?.cancel();
    widget
      ..onDismissed()
      ..onTap();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // The app's own tokens (as the Settings tiles use): the Material
    // "inverse" pair `showTopToast` uses barely contrasts in the dark theme.
    final colors = context.colors;

    return Positioned(
      top: 0,
      left: 16,
      right: 16,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: FadeTransition(
            opacity: _fade,
            child: SlideTransition(
              position: _slide,
              child: Material(
                color: Colors.transparent,
                child: GestureDetector(
                  onTap: _open,
                  onVerticalDragEnd: (details) {
                    if ((details.primaryVelocity ?? 0) < 0) _dismiss();
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: colors.surface,
                      border: Border.all(color: colors.border),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black38,
                          blurRadius: 8,
                          offset: Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.notifications_rounded,
                          color: colors.accent,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                widget.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: colors.textPrimary,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                widget.body,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: colors.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
