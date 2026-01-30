import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../core/theme.dart';
import '../core/analytics.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    Analytics.logScreenView('welcome');
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacingLg),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(flex: 2),
              Icon(Icons.explore_rounded, size: 80, color: Theme.of(context).colorScheme.primary),
              const SizedBox(height: AppTheme.spacingLg),
              Text(
                'Travel App',
                style: Theme.of(context).textTheme.headlineLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const Spacer(flex: 2),
              _AuthButton(
                icon: Icons.apple_rounded,
                label: 'Continue with Apple',
                onPressed: () {
                  Analytics.logEvent('auth_apple_clicked');
                  // TODO: Phase 2 - Sign in with Apple
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Apple Sign In coming in Phase 2')),
                  );
                },
              ),
              const SizedBox(height: AppTheme.spacingMd),
              _AuthButton(
                icon: Icons.g_mobiledata_rounded,
                label: 'Continue with Google',
                onPressed: () {
                  Analytics.logEvent('auth_google_clicked');
                  // TODO: Phase 2 - Sign in with Google
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Google Sign In coming in Phase 2')),
                  );
                },
              ),
              const SizedBox(height: AppTheme.spacingMd),
              _AuthButton(
                icon: Icons.email_rounded,
                label: 'Continue with Email',
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

  const _AuthButton({required this.icon, required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 24),
        label: Text(label),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          side: BorderSide(color: Theme.of(context).colorScheme.outline),
        ),
      ),
    );
  }
}
