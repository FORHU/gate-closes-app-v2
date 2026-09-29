import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:gate_closes/core/utils/context_extensions.dart';
import 'package:gate_closes/features/auth/presentation/pages/login_page.dart'
    show LoginPage;
import 'package:gate_closes/features/auth/presentation/widgets/register_form.dart';
import 'package:gate_closes/shared/widgets/ambient_background.dart';
import 'package:gate_closes/theme/tokens/effects.dart';
import 'package:gate_closes/theme/tokens/radius.dart';
import 'package:gate_closes/theme/tokens/spacing.dart';

/// Register page — Gate Closes glass aesthetic matching [LoginPage].
class RegisterPage extends StatelessWidget {
  const RegisterPage({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Scaffold(
      backgroundColor: colors.background,
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
                          Icons.person_add_rounded,
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
                      'Create account',
                      textAlign: TextAlign.center,
                      style:
                          Theme.of(context).textTheme.headlineMedium?.copyWith(
                                color: colors.textPrimary,
                                fontWeight: FontWeight.w700,
                              ),
                    )
                        .animate()
                        .fadeIn(delay: 80.ms, duration: 350.ms)
                        .slideY(begin: 0.15, end: 0),

                    AppSpacing.xs.v,

                    Text(
                      'Fill in the details below to get started',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: colors.textSecondary,
                          ),
                    ).animate().fadeIn(delay: 140.ms, duration: 350.ms),

                    const SizedBox(height: AppSpacing.xl),

                    // Glass card container
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      decoration: BoxDecoration(
                        color: colors.surface,
                        borderRadius: AppRadius.brCard,
                        border: Border.all(color: colors.border),
                        boxShadow: AppEffects.surfaceShadow,
                      ),
                      child: const RegisterForm(),
                    )
                        .animate()
                        .fadeIn(delay: 200.ms, duration: 400.ms)
                        .slideY(begin: 0.08, end: 0),
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
