import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gate_closes/core/utils/context_extensions.dart';
import 'package:gate_closes/core/utils/validators.dart';
import 'package:gate_closes/features/auth/presentation/controllers/auth_controller.dart';
import 'package:gate_closes/features/profile/presentation/controllers/profile_controller.dart';
import 'package:gate_closes/shared/widgets/buttons.dart';
import 'package:gate_closes/shared/widgets/modern_text_field.dart';
import 'package:gate_closes/shared/widgets/top_toast.dart';
import 'package:gate_closes/theme/tokens/spacing.dart';
import 'package:go_router/go_router.dart';

class ProfileEditorPage extends ConsumerStatefulWidget {
  const ProfileEditorPage({super.key});

  @override
  ConsumerState<ProfileEditorPage> createState() => _ProfileEditorPageState();
}

class _ProfileEditorPageState extends ConsumerState<ProfileEditorPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _usernameController;
  String? _gender;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final user = ref.read(authControllerProvider).user;
    final profile = ref.read(profileControllerProvider).profile;
    _usernameController = TextEditingController(
      text: user?.name ?? profile?.name ?? '',
    );
    _gender = user?.gender;
  }

  @override
  void dispose() {
    _usernameController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;
    if (_gender == null) {
      showTopToast(context, 'Please select a gender');
      return;
    }

    setState(() => _isSaving = true);
    final ok = await ref.read(authControllerProvider.notifier).editProfile(
          username: _usernameController.text.trim(),
          gender: _gender,
        );

    if (!mounted) return;
    setState(() => _isSaving = false);

    if (ok) {
      await ref.read(profileControllerProvider.notifier).fetchProfile();
      if (!mounted) return;
      showTopToast(context, 'Profile updated successfully');
      context.pop();
    } else {
      final error = ref.read(authControllerProvider).error;
      showTopToast(context, error ?? 'Failed to update profile');
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final user = ref.watch(authControllerProvider).user;
    final initial =
        (user?.name.isNotEmpty ?? false) ? user!.name[0].toUpperCase() : '?';

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: Text(
          'Edit Profile',
          style: TextStyle(
            color: colors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        backgroundColor: colors.background,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: colors.textPrimary,
          ),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: AppSpacing.edgeInsetsLg,
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: CircleAvatar(
                    radius: 46,
                    backgroundColor: colors.accent,
                    child: Text(
                      initial,
                      style: TextStyle(
                        fontSize: 34,
                        fontWeight: FontWeight.bold,
                        color: colors.accentOn,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                ModernTextField(
                  label: 'USERNAME',
                  hint: 'traveler_jane',
                  controller: _usernameController,
                  prefixIcon: Icons.badge_outlined,
                  validator: Validators.username,
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  'GENDER',
                  style: TextStyle(
                    color: colors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Row(
                  children: [
                    for (final option in const ['Male', 'Female']) ...[
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _gender = option),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: _gender == option
                                  ? colors.accent.withValues(alpha: 0.15)
                                  : colors.surface,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: _gender == option
                                    ? colors.accent
                                    : colors.border,
                                width: _gender == option ? 1.5 : 1,
                              ),
                            ),
                            child: Text(
                              option,
                              style: TextStyle(
                                color: _gender == option
                                    ? colors.accent
                                    : colors.textPrimary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),
                      if (option != 'Female')
                        const SizedBox(width: AppSpacing.sm),
                    ],
                  ],
                ),
                const SizedBox(height: AppSpacing.xxl),
                PrimaryButton(
                  label: 'Save Changes',
                  isLoading: _isSaving,
                  onPressed: _handleSave,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
