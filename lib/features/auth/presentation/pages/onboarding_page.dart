import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_template/core/services/storage_service.dart';
import 'package:flutter_template/core/utils/context_extensions.dart';
import 'package:flutter_template/routes/route_names.dart';
import 'package:flutter_template/shared/widgets/ambient_background.dart';
import 'package:flutter_template/shared/widgets/buttons.dart';
import 'package:flutter_template/theme/tokens/effects.dart';
import 'package:flutter_template/theme/tokens/radius.dart';
import 'package:flutter_template/theme/tokens/spacing.dart';
import 'package:go_router/go_router.dart';

/// A one-time onboarding flow shown to new users after registration / first
/// launch. Mark it seen in [StorageService] and navigate to home.
///
/// CUSTOMIZE: Replace the `_slides` content with your own copy and icons.
class OnboardingPage extends ConsumerStatefulWidget {
  const OnboardingPage({super.key});

  @override
  ConsumerState<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends ConsumerState<OnboardingPage> {
  final _controller = PageController();
  int _currentPage = 0;

  static const _slides = [
    _Slide(
      icon: Icons.rocket_launch_rounded,
      title: 'Get started fast',
      body: 'This template ships a complete clean architecture skeleton so '
          'you can jump straight into your features.',
    ),
    _Slide(
      icon: Icons.palette_rounded,
      title: 'Premium design system',
      body: 'Design tokens, glassmorphic dark/light themes, and a full '
          'component library — ready to customize.',
    ),
    _Slide(
      icon: Icons.lock_rounded,
      title: 'Auth out of the box',
      body: 'Secure token storage, silent refresh, router guards, and '
          'registration — all wired up.',
    ),
  ];

  Future<void> _finish() async {
    await ref.read(storageServiceProvider).setOnboardingSeen();
    if (mounted) context.go(RouteNames.home);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLast = _currentPage == _slides.length - 1;
    final colors = context.colors;

    return Scaffold(
      backgroundColor: colors.background,
      body: AmbientBackground(
        child: SafeArea(
          child: Column(
            children: [
              // Skip button
              Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: TextButton(
                    onPressed: _finish,
                    child: Text(
                      'Skip',
                      style: TextStyle(
                        color: colors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),

              // Page view
              Expanded(
                child: PageView.builder(
                  controller: _controller,
                  itemCount: _slides.length,
                  onPageChanged: (i) => setState(() => _currentPage = i),
                  itemBuilder: (context, index) =>
                      _SlidePage(slide: _slides[index]),
                ),
              ),

              // Dots indicator
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  _slides.length,
                  (i) => AnimatedContainer(
                    duration: const Duration(milliseconds: 280),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: i == _currentPage ? 24 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: i == _currentPage ? colors.accent : colors.border,
                      borderRadius: AppRadius.brPill,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: AppSpacing.xl),

              // CTA
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 400),
                  child: PrimaryButton(
                    label: isLast ? "Let's go!" : 'Next',
                    onPressed: isLast
                        ? _finish
                        : () => _controller.nextPage(
                              duration: const Duration(milliseconds: 350),
                              curve: Curves.easeOutCubic,
                            ),
                  ),
                ),
              ),

              const SizedBox(height: AppSpacing.xl),
            ],
          ),
        ),
      ),
    );
  }
}

class _SlidePage extends StatelessWidget {
  const _SlidePage({required this.slide});
  final _Slide slide;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 110,
            height: 110,
            decoration: BoxDecoration(
              color: colors.accent,
              borderRadius: BorderRadius.circular(32),
              boxShadow: AppEffects.accentGlow(colors.accentGlow15),
            ),
            child: Icon(slide.icon, size: 52, color: colors.accentOn),
          )
              .animate()
              .fadeIn(duration: 400.ms)
              .scale(begin: const Offset(0.85, 0.85)),
          const SizedBox(height: AppSpacing.xl),
          Text(
            slide.title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: colors.textPrimary,
                  fontWeight: FontWeight.w800,
                ),
          )
              .animate()
              .fadeIn(delay: 80.ms, duration: 400.ms)
              .slideY(begin: 0.2, end: 0),
          const SizedBox(height: AppSpacing.md),
          Text(
            slide.body,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colors.textSecondary,
                  height: 1.5,
                ),
          ).animate().fadeIn(delay: 160.ms, duration: 400.ms),
        ],
      ),
    );
  }
}

class _Slide {
  const _Slide({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;
}
