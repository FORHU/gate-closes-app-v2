import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_template/core/utils/context_extensions.dart';
import 'package:flutter_template/core/utils/validators.dart';
import 'package:flutter_template/features/auth/presentation/controllers/forgot_password_controller.dart';
import 'package:flutter_template/shared/widgets/buttons.dart';
import 'package:flutter_template/shared/widgets/modern_text_field.dart';
import 'package:flutter_template/shared/widgets/top_toast.dart';
import 'package:flutter_template/theme/tokens/spacing.dart';

/// The 3-step forgot-password wizard, dispatched by
/// `ForgotPasswordController`'s current step — same one-directional-step
/// pattern as `RegisterForm`.
class ForgotPasswordForm extends ConsumerWidget {
  const ForgotPasswordForm({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final step = ref.watch(
      forgotPasswordControllerProvider.select((s) => s.step),
    );

    return switch (step) {
      ForgotPasswordStep.email => const _EmailStep(),
      ForgotPasswordStep.otp => const _OtpStep(),
      ForgotPasswordStep.newPassword => const _NewPasswordStep(),
    };
  }
}

class _EmailStep extends ConsumerStatefulWidget {
  const _EmailStep();

  @override
  ConsumerState<_EmailStep> createState() => _EmailStepState();
}

class _EmailStepState extends ConsumerState<_EmailStep> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final ok = await ref
        .read(forgotPasswordControllerProvider.notifier)
        .requestCode(_emailController.text.trim());
    if (!mounted) return;
    if (!ok) {
      final error = ref.read(forgotPasswordControllerProvider).error;
      if (error != null) showTopToast(context, error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(
      forgotPasswordControllerProvider.select((s) => s.isLoading),
    );
    final colors = context.colors;

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            "Enter the email on your account and we'll send a reset code.",
            style: TextStyle(color: colors.textSecondary, fontSize: 13),
          ).animate().fadeIn(duration: 350.ms),
          AppSpacing.md.v,
          ModernTextField(
            label: 'Email',
            hint: 'you@example.com',
            controller: _emailController,
            prefixIcon: Icons.email_outlined,
            keyboardType: TextInputType.emailAddress,
            validator: Validators.email,
          ).animate().fadeIn(delay: 60.ms, duration: 350.ms),
          AppSpacing.xl.v,
          PrimaryButton(
            label: 'Send code',
            isLoading: isLoading,
            onPressed: _submit,
          ).animate().fadeIn(delay: 120.ms, duration: 350.ms),
        ],
      ),
    );
  }
}

class _OtpStep extends ConsumerStatefulWidget {
  const _OtpStep();

  @override
  ConsumerState<_OtpStep> createState() => _OtpStepState();
}

class _OtpStepState extends ConsumerState<_OtpStep> {
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final ok = await ref
        .read(forgotPasswordControllerProvider.notifier)
        .verifyCode(_codeController.text.trim());
    if (!mounted) return;
    if (!ok) {
      final error = ref.read(forgotPasswordControllerProvider).error;
      if (error != null) showTopToast(context, error);
    }
  }

  Future<void> _resend() async {
    final ok =
        await ref.read(forgotPasswordControllerProvider.notifier).resendCode();
    if (!mounted) return;
    showTopToast(
      context,
      ok
          ? 'Code resent.'
          : (ref.read(forgotPasswordControllerProvider).error ?? ''),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(forgotPasswordControllerProvider);
    final colors = context.colors;

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'We sent a 4-digit code to ${state.email}',
            style: TextStyle(color: colors.textSecondary, fontSize: 13),
          ).animate().fadeIn(duration: 350.ms),
          AppSpacing.md.v,
          ModernTextField(
            label: 'Verification code',
            hint: '0000',
            controller: _codeController,
            prefixIcon: Icons.pin_outlined,
            keyboardType: TextInputType.number,
            validator: Validators.otpCode,
          ).animate().fadeIn(delay: 60.ms, duration: 350.ms),
          AppSpacing.xl.v,
          PrimaryButton(
            label: 'Verify',
            isLoading: state.isLoading,
            onPressed: _submit,
          ).animate().fadeIn(delay: 120.ms, duration: 350.ms),
          AppSpacing.md.v,
          Center(
            child: TextButton(
              onPressed: _resend,
              child: Text(
                'Resend code',
                style: TextStyle(
                  color: colors.accent,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NewPasswordStep extends ConsumerStatefulWidget {
  const _NewPasswordStep();

  @override
  ConsumerState<_NewPasswordStep> createState() => _NewPasswordStepState();
}

class _NewPasswordStepState extends ConsumerState<_NewPasswordStep> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final ok = await ref
        .read(forgotPasswordControllerProvider.notifier)
        .submitNewPassword(_passwordController.text, _confirmController.text);
    if (!mounted) return;
    if (!ok) {
      final error = ref.read(forgotPasswordControllerProvider).error;
      if (error != null) showTopToast(context, error);
    }
    // On success the router's redirect (watching isAuthenticated) takes it
    // from here — see app_routes.dart's `goingToPreAuthPage` bounce-home.
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(
      forgotPasswordControllerProvider.select((s) => s.isLoading),
    );
    final colors = context.colors;

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ModernTextField(
            label: 'New password',
            hint: '••••••••',
            controller: _passwordController,
            prefixIcon: Icons.lock_outline_rounded,
            obscureText: _obscurePassword,
            validator: Validators.password,
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
          ).animate().fadeIn(duration: 350.ms),
          AppSpacing.md.v,
          ModernTextField(
            label: 'Confirm new password',
            hint: '••••••••',
            controller: _confirmController,
            prefixIcon: Icons.lock_outline_rounded,
            obscureText: _obscureConfirm,
            validator: (v) =>
                v != _passwordController.text ? 'Passwords do not match' : null,
            suffixIcon: IconButton(
              icon: Icon(
                _obscureConfirm
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
                color: colors.textMuted,
                size: 20,
              ),
              onPressed: () =>
                  setState(() => _obscureConfirm = !_obscureConfirm),
            ),
          ).animate().fadeIn(delay: 60.ms, duration: 350.ms),
          AppSpacing.xl.v,
          PrimaryButton(
            label: 'Reset password',
            isLoading: isLoading,
            onPressed: _submit,
          ).animate().fadeIn(delay: 120.ms, duration: 350.ms),
        ],
      ),
    );
  }
}
