import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../core/theme.dart';
import '../core/analytics.dart';
import '../l10n/app_strings.dart';
import '../widgets/profile_banner_2026.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    Analytics.logScreenView('welcome');
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background: premium gradient banner (reusing profile banner aesthetic)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: MediaQuery.sizeOf(context).height * 0.45,
            child: ProfileBanner2026(
              seedKey: 'welcome_banner',
              height: MediaQuery.sizeOf(context).height * 0.45,
              bottomRadius: 0,
              enableShimmer: true,
            ),
          ),
          // Gradient fade to surface
          Positioned(
            top: MediaQuery.sizeOf(context).height * 0.3,
            left: 0,
            right: 0,
            bottom: 0,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    cs.surface.withValues(alpha: 0.0),
                    cs.surface.withValues(alpha: 0.8),
                    cs.surface,
                    cs.surface,
                  ],
                  stops: const [0.0, 0.2, 0.4, 1.0],
                ),
              ),
            ),
          ),
          // Content
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingXl),
              child: Column(
                children: [
                  const Spacer(flex: 3),
                  // Logo / Brand
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: cs.shadow.withValues(alpha: 0.15),
                          blurRadius: 24,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.explore_rounded,
                      size: 42,
                      color: cs.primary,
                    ),
                  ),
                  const SizedBox(height: AppTheme.spacingLg),
                  Text(
                    AppStrings.t(context, 'app_name'),
                    style: theme.textTheme.displayMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: -1.0,
                    ),
                  ),
                  const SizedBox(height: AppTheme.spacingSm),
                  Text(
                    AppStrings.t(context, 'app_tagline'),
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: cs.onSurfaceVariant,
                      height: 1.4,
                      fontWeight: FontWeight.w400,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const Spacer(flex: 2),
                  // Auth buttons
                  _AuthButton(
                    icon: Icons.apple_rounded,
                    label: AppStrings.t(context, 'continue_with_apple'),
                    onPressed: () {
                      Analytics.logEvent('auth_apple_clicked');
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(AppStrings.t(context, 'apple_sign_in_coming_soon'))),
                      );
                    },
                    style: _AuthButtonStyle.dark,
                  ),
                  const SizedBox(height: 12),
                  _AuthButton(
                    icon: Icons.g_mobiledata_rounded,
                    label: AppStrings.t(context, 'continue_with_google'),
                    onPressed: () {
                      Analytics.logEvent('auth_google_clicked');
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(AppStrings.t(context, 'google_sign_in_coming_soon'))),
                      );
                    },
                    style: _AuthButtonStyle.outlined,
                  ),
                  const SizedBox(height: 12),
                  _AuthButton(
                    icon: Icons.email_rounded,
                    label: AppStrings.t(context, 'continue_with_email'),
                    onPressed: () {
                      Analytics.logEvent('auth_email_clicked');
                      context.push('/auth/email');
                    },
                    style: _AuthButtonStyle.primary,
                  ),
                  const SizedBox(height: AppTheme.spacingXl),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

enum _AuthButtonStyle { primary, dark, outlined }

class _AuthButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final _AuthButtonStyle style;

  const _AuthButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.style = _AuthButtonStyle.outlined,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    Color backgroundColor;
    Color foregroundColor;
    BorderSide? borderSide;

    switch (style) {
      case _AuthButtonStyle.primary:
        backgroundColor = cs.primary;
        foregroundColor = cs.onPrimary;
        borderSide = null;
      case _AuthButtonStyle.dark:
        backgroundColor = isDark ? Colors.white : const Color(0xFF1C1917);
        foregroundColor = isDark ? const Color(0xFF1C1917) : Colors.white;
        borderSide = null;
      case _AuthButtonStyle.outlined:
        backgroundColor = Colors.transparent;
        foregroundColor = cs.onSurface;
        borderSide = BorderSide(color: cs.outline.withValues(alpha: 0.5));
    }

    return SizedBox(
      width: double.infinity,
      height: 54,
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          backgroundColor: backgroundColor,
          foregroundColor: foregroundColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: borderSide ?? BorderSide.none,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 22),
            const SizedBox(width: 12),
            Text(
              label,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: foregroundColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
