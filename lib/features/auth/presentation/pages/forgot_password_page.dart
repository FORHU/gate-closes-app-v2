import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_template/core/utils/context_extensions.dart';
import 'package:flutter_template/features/auth/presentation/widgets/forgot_password_form.dart';
import 'package:flutter_template/shared/widgets/ambient_background.dart';
import 'package:flutter_template/theme/tokens/effects.dart';
import 'package:flutter_template/theme/tokens/radius.dart';
import 'package:flutter_template/theme/tokens/spacing.dart';

/// Forgot-password wizard — same glass shell as `LoginPage`/`RegisterPage`.
class ForgotPasswordPage extends StatelessWidget {
  const ForgotPasswordPage({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(backgroundColor: colors.background, elevation: 0),
      body: AmbientBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.xl,
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 68,
                        height: 68,
                        decoration: BoxDecoration(
                          color: colors.accent,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: AppEffects.accentGlow(colors.accentGlow15),
                        ),
                        child: Icon(
                          Icons.lock_reset_rounded,
                          color: colors.accentOn,
                          size: 34,
                        ),
                      ),
                    )
                        .animate()
                        .fadeIn(duration: 400.ms)
                        .scale(begin: const Offset(0.85, 0.85)),
                    AppSpacing.lg.v,
                    Text(
                      'Reset your password',
                      textAlign: TextAlign.center,
                      style:
                          Theme.of(context).textTheme.headlineMedium?.copyWith(
                                color: colors.textPrimary,
                                fontWeight: FontWeight.w700,
                              ),
                    ).animate().fadeIn(delay: 80.ms, duration: 350.ms),
                    AppSpacing.xl.v,
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      decoration: BoxDecoration(
                        color: colors.surface,
                        borderRadius: AppRadius.brCard,
                        border: Border.all(color: colors.border),
                        boxShadow: AppEffects.surfaceShadow,
                      ),
                      child: const ForgotPasswordForm(),
                    ).animate().fadeIn(delay: 160.ms, duration: 400.ms).slideY(
                          begin: 0.08,
                          end: 0,
                        ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
