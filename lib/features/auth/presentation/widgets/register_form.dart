import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gate_closes/core/utils/context_extensions.dart';
import 'package:gate_closes/core/utils/validators.dart';
import 'package:gate_closes/features/auth/presentation/controllers/register_controller.dart';
import 'package:gate_closes/routes/route_names.dart';
import 'package:gate_closes/shared/widgets/buttons.dart';
import 'package:gate_closes/shared/widgets/modern_text_field.dart';
import 'package:gate_closes/shared/widgets/top_toast.dart';
import 'package:gate_closes/theme/tokens/spacing.dart';
import 'package:go_router/go_router.dart';

/// The 4-step signup wizard (`RegisterStep`), dispatched by
/// `RegisterController`'s current step. Each step is its own widget with its
/// own field controllers — swapping between them is a normal widget
/// rebuild, not a `PageView`, since steps are one-directional (no going
/// back to re-edit a submitted step).
class RegisterForm extends ConsumerWidget {
  const RegisterForm({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final step = ref.watch(
      registerControllerProvider.select((s) => s.step),
    );

    return switch (step) {
      RegisterStep.email => const _EmailStep(),
      RegisterStep.otp => const _OtpStep(),
      RegisterStep.password => const _PasswordStep(),
      RegisterStep.usernameGender => const _UsernameGenderStep(),
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
        .read(registerControllerProvider.notifier)
        .submitEmail(_emailController.text.trim());
    if (!mounted) return;
    if (!ok) {
      final error = ref.read(registerControllerProvider).error;
      if (error != null) showTopToast(context, error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(
      registerControllerProvider.select((s) => s.isLoading),
    );
    final colors = context.colors;

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ModernTextField(
            label: 'Email',
            hint: 'you@example.com',
            controller: _emailController,
            prefixIcon: Icons.email_outlined,
            keyboardType: TextInputType.emailAddress,
            validator: Validators.email,
          ).animate().fadeIn(duration: 350.ms).slideY(begin: 0.1, end: 0),
          AppSpacing.xl.v,
          PrimaryButton(
            label: 'Continue',
            isLoading: isLoading,
            onPressed: _submit,
          ).animate().fadeIn(delay: 80.ms, duration: 350.ms),
          AppSpacing.lg.v,
          Wrap(
            alignment: WrapAlignment.center,
            children: [
              Text(
                'Already have an account? ',
                style: TextStyle(color: colors.textSecondary, fontSize: 14),
              ),
              GestureDetector(
                onTap: () => context.go(RouteNames.login),
                child: Text(
                  'Sign in',
                  style: TextStyle(
                    color: colors.accent,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ).animate().fadeIn(delay: 140.ms),
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
        .read(registerControllerProvider.notifier)
        .verifyOtp(_codeController.text.trim());
    if (!mounted) return;
    if (!ok) {
      final error = ref.read(registerControllerProvider).error;
      if (error != null) showTopToast(context, error);
    }
  }

  Future<void> _resend() async {
    final ok = await ref.read(registerControllerProvider.notifier).resendOtp();
    if (!mounted) return;
    showTopToast(
      context,
      ok ? 'Code resent.' : (ref.read(registerControllerProvider).error ?? ''),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(registerControllerProvider);
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

class _PasswordStep extends ConsumerStatefulWidget {
  const _PasswordStep();

  @override
  ConsumerState<_PasswordStep> createState() => _PasswordStepState();
}

class _PasswordStepState extends ConsumerState<_PasswordStep> {
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
        .read(registerControllerProvider.notifier)
        .submitPassword(_passwordController.text, _confirmController.text);
    if (!mounted) return;
    if (!ok) {
      final error = ref.read(registerControllerProvider).error;
      if (error != null) showTopToast(context, error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(
      registerControllerProvider.select((s) => s.isLoading),
    );
    final colors = context.colors;

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ModernTextField(
            label: 'Password',
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
            label: 'Confirm password',
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
            label: 'Continue',
            isLoading: isLoading,
            onPressed: _submit,
          ).animate().fadeIn(delay: 120.ms, duration: 350.ms),
        ],
      ),
    );
  }
}

class _UsernameGenderStep extends ConsumerStatefulWidget {
  const _UsernameGenderStep();

  @override
  ConsumerState<_UsernameGenderStep> createState() =>
      _UsernameGenderStepState();
}

class _UsernameGenderStepState extends ConsumerState<_UsernameGenderStep> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  String? _gender;

  @override
  void dispose() {
    _usernameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_gender == null) {
      showTopToast(context, 'Select a gender to continue.');
      return;
    }
    final ok = await ref
        .read(registerControllerProvider.notifier)
        .submitUsernameGender(_usernameController.text.trim(), _gender!);
    if (!mounted) return;
    if (!ok) {
      final error = ref.read(registerControllerProvider).error;
      if (error != null) showTopToast(context, error);
    }
    // On success there's nothing left to do here — logging in flips
    // AuthController's state, and the router's redirect (watching
    // isAuthenticated) takes it from there.
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(
      registerControllerProvider.select((s) => s.isLoading),
    );
    final colors = context.colors;

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ModernTextField(
            label: 'Username',
            hint: 'traveler_jane',
            controller: _usernameController,
            prefixIcon: Icons.badge_outlined,
            validator: Validators.username,
          ).animate().fadeIn(duration: 350.ms),
          AppSpacing.md.v,
          Text(
            'Gender',
            style: TextStyle(
              color: colors.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          AppSpacing.xs.v,
          Row(
            children: [
              for (final option in const ['Male', 'Female']) ...[
                Expanded(
                  child: _GenderOption(
                    label: option,
                    selected: _gender == option,
                    onTap: () => setState(() => _gender = option),
                  ),
                ),
                if (option != 'Female') AppSpacing.sm.h,
              ],
            ],
          ).animate().fadeIn(delay: 60.ms, duration: 350.ms),
          AppSpacing.xl.v,
          PrimaryButton(
            label: "Let's go!",
            isLoading: isLoading,
            onPressed: _submit,
          ).animate().fadeIn(delay: 120.ms, duration: 350.ms),
        ],
      ),
    );
  }
}

class _GenderOption extends StatelessWidget {
  const _GenderOption({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color:
              selected ? colors.accent.withValues(alpha: 0.15) : colors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? colors.accent : colors.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? colors.accent : colors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
