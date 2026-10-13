import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gate_closes/core/services/google_sign_in_service.dart';
import 'package:gate_closes/core/utils/context_extensions.dart';
import 'package:gate_closes/core/utils/validators.dart';
import 'package:gate_closes/features/auth/presentation/controllers/auth_controller.dart';
import 'package:gate_closes/features/auth/presentation/controllers/register_controller.dart';
import 'package:gate_closes/routes/route_names.dart';
import 'package:gate_closes/shared/widgets/buttons.dart';
import 'package:gate_closes/shared/widgets/modern_text_field.dart';
import 'package:gate_closes/shared/widgets/top_toast.dart';
import 'package:gate_closes/theme/tokens/spacing.dart';
import 'package:go_router/go_router.dart';

class LoginForm extends ConsumerStatefulWidget {
  const LoginForm({super.key});

  @override
  ConsumerState<LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends ConsumerState<LoginForm> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final success = await ref
        .read(authControllerProvider.notifier)
        .login(_emailController.text, _passwordController.text);

    if (!mounted) return;

    if (success) {
      context.go(RouteNames.home);
    } else {
      final error = ref.read(authControllerProvider).error;
      if (error != null) showTopToast(context, error);
    }
  }

  Future<void> _continueWithGoogle() async {
    final result =
        await ref.read(authControllerProvider.notifier).loginWithGoogle();
    if (!mounted) return;

    switch (result) {
      case GoogleLoginResult.signedIn:
        context.go(RouteNames.home);
      case GoogleLoginResult.needsProfile:
        ref.read(registerControllerProvider.notifier).startProfileCompletion();
        context.go(RouteNames.register);
      case GoogleLoginResult.failed:
        final error = ref.read(authControllerProvider).error;
        if (error != null) showTopToast(context, error);
      case GoogleLoginResult.cancelled:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(authControllerProvider);
    final showGoogle = ref.watch(googleSignInServiceProvider).isConfigured;
    final colors = context.colors;

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ModernTextField(
            label: context.l10n.email,
            hint: 'you@example.com',
            controller: _emailController,
            prefixIcon: Icons.email_outlined,
            keyboardType: TextInputType.emailAddress,
            validator: Validators.email,
          )
              .animate()
              .fadeIn(delay: 100.ms, duration: 350.ms)
              .slideY(begin: 0.1, end: 0),
          AppSpacing.md.v,
          ModernTextField(
            label: context.l10n.password,
            hint: '••••••••',
            controller: _passwordController,
            prefixIcon: Icons.lock_outline_rounded,
            obscureText: _obscurePassword,
            validator: Validators.loginPassword,
            suffixIcon: IconButton(
              icon: Icon(
                _obscurePassword
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
                color: colors.textMuted,
                size: 20,
              ),
              onPressed: () =>
                  setState(() => _obscurePassword = !_obscurePassword),
            ),
          )
              .animate()
              .fadeIn(delay: 180.ms, duration: 350.ms)
              .slideY(begin: 0.1, end: 0),
          AppSpacing.xs.v,
          Align(
            alignment: Alignment.centerRight,
            child: GestureDetector(
              onTap: () => context.go(RouteNames.forgotPassword),
              child: Text(
                'Forgot password?',
                style: TextStyle(
                  color: colors.accent,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ).animate().fadeIn(delay: 220.ms, duration: 350.ms),
          AppSpacing.lg.v,
          PrimaryButton(
            label: context.l10n.login,
            isLoading: state.isLoading,
            onPressed: _submit,
          )
              .animate()
              .fadeIn(delay: 260.ms, duration: 350.ms)
              .slideY(begin: 0.1, end: 0),
          if (showGoogle) ...[
            AppSpacing.md.v,
            GlassButton(
              label: 'Continue with Google',
              leading: const _GoogleMark(),
              onPressed: state.isLoading ? null : _continueWithGoogle,
            )
                .animate()
                .fadeIn(delay: 290.ms, duration: 350.ms)
                .slideY(begin: 0.1, end: 0),
          ],
          AppSpacing.lg.v,
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                "Don't have an account? ",
                style: TextStyle(
                  color: colors.textSecondary,
                  fontSize: 14,
                ),
              ),
              GestureDetector(
                onTap: () => context.go(RouteNames.register),
                child: Text(
                  'Sign up',
                  style: TextStyle(
                    color: colors.accent,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ).animate().fadeIn(delay: 320.ms, duration: 350.ms),
        ],
      ),
    );
  }
}

/// Google's "G" on a white disc, as Google's sign-in guidelines ask for on
/// dark buttons.
class _GoogleMark extends StatelessWidget {
  const _GoogleMark();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
      ),
      child: const Text(
        'G',
        style: TextStyle(
          color: Color(0xFF4285F4),
          fontSize: 14,
          fontWeight: FontWeight.w800,
          height: 1,
        ),
      ),
    );
  }
}
