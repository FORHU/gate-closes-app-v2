import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:gate_closes/core/utils/context_extensions.dart';
import 'package:gate_closes/theme/tokens/effects.dart';
import 'package:gate_closes/theme/tokens/radius.dart';
import 'package:gate_closes/theme/tokens/spacing.dart';

/// Solid primary-color CTA button.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    required this.label,
    required this.onPressed,
    this.icon,
    this.expand = true,
    this.isLoading = false,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool expand;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return _PressableButton(
      onPressed: onPressed,
      expand: expand,
      isLoading: isLoading,
      label: label,
      icon: icon,
      foreground: colors.accentOn,
      decoration: BoxDecoration(
        color: colors.accent,
        borderRadius: AppRadius.brPill,
        boxShadow: AppEffects.accentGlow(colors.accentGlow15),
      ),
    );
  }
}

/// Gradient / Primary CTA button with pill shape — for hero actions.
class GradientButton extends StatelessWidget {
  const GradientButton({
    required this.label,
    required this.onPressed,
    this.icon,
    this.expand = true,
    this.isLoading = false,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool expand;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return _PressableButton(
      onPressed: onPressed,
      expand: expand,
      isLoading: isLoading,
      label: label,
      icon: icon,
      foreground: colors.accentOn,
      decoration: BoxDecoration(
        color: colors.accent,
        borderRadius: AppRadius.brPill,
        boxShadow: AppEffects.accentGlow(colors.accentGlow15),
      ),
    );
  }
}

class _PressableButton extends StatefulWidget {
  const _PressableButton({
    required this.label,
    required this.onPressed,
    required this.decoration,
    required this.expand,
    required this.isLoading,
    required this.foreground,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final BoxDecoration decoration;
  final bool expand;
  final bool isLoading;
  final Color foreground;
  final IconData? icon;

  @override
  State<_PressableButton> createState() => _PressableButtonState();
}

class _PressableButtonState extends State<_PressableButton> {
  bool _down = false;

  bool get _enabled => widget.onPressed != null && !widget.isLoading;

  void _setDown({required bool value}) => setState(() => _down = value);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _enabled ? (_) => _setDown(value: true) : null,
      onTapUp: _enabled ? (_) => _setDown(value: false) : null,
      onTapCancel: _enabled ? () => _setDown(value: false) : null,
      onTap: _enabled ? widget.onPressed : null,
      child: AnimatedScale(
        scale: _down ? 0.97 : 1,
        duration: const Duration(milliseconds: 120),
        child: AnimatedOpacity(
          opacity: _enabled ? 1 : 0.5,
          duration: const Duration(milliseconds: 150),
          child: Container(
            width: widget.expand ? double.infinity : null,
            height: 54,
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            decoration: widget.decoration,
            child: widget.isLoading
                ? SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.4,
                      valueColor: AlwaysStoppedAnimation(widget.foreground),
                    ),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (widget.icon != null) ...[
                        Icon(widget.icon, color: widget.foreground, size: 20),
                        const Gap(AppSpacing.sm),
                      ],
                      Text(
                        widget.label,
                        style: TextStyle(
                          color: widget.foreground,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
