import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../core/theme.dart';
import '../core/analytics.dart';
import '../l10n/app_strings.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    Analytics.logScreenView('welcome');
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingXl),
          child: Column(
            children: [
              const Spacer(flex: 2),
              // Hero
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(28),
                ),
                child: Icon(
                  Icons.explore_rounded,
                  size: 52,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(height: AppTheme.spacingXl),
              Text(
                AppStrings.t(context, 'app_name'),
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.5,
                    ),
              ),
              const SizedBox(height: AppTheme.spacingSm),
              Text(
                AppStrings.t(context, 'app_tagline'),
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      height: 1.4,
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
              ),
              const SizedBox(height: AppTheme.spacingMd),
              _AuthButton(
                icon: Icons.g_mobiledata_rounded,
                label: AppStrings.t(context, 'continue_with_google'),
                onPressed: () {
                  Analytics.logEvent('auth_google_clicked');
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(AppStrings.t(context, 'google_sign_in_coming_soon'))),
                  );
                },
              ),
              const SizedBox(height: AppTheme.spacingMd),
              _AuthButton(
                icon: Icons.email_rounded,
                label: AppStrings.t(context, 'continue_with_email'),
                filled: true,
                onPressed: () {
                  Analytics.logEvent('auth_email_clicked');
                  context.push('/auth/email');
                },
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}

class _AuthButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final bool filled;

  const _AuthButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.filled = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: filled
          ? FilledButton.icon(
              onPressed: onPressed,
              icon: Icon(icon, size: 22),
              label: Text(label),
            )
          : OutlinedButton.icon(
              onPressed: onPressed,
              icon: Icon(icon, size: 22),
              label: Text(label),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: Theme.of(context).colorScheme.outline),
              ),
            ),
    );
  }
}
