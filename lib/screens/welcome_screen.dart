import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../core/theme.dart';
import '../core/analytics.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  Future<void> _developerSignIn(BuildContext context) async {
    final email = dotenv.env['DEV_EMAIL']?.trim();
    final password = dotenv.env['DEV_PASSWORD'];
    if (email == null || email.isEmpty || password == null || password.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Add DEV_EMAIL and DEV_PASSWORD to .env')),
        );
      }
      return;
    }
    try {
      await Supabase.instance.client.auth.signInWithPassword(email: email, password: password);
      Analytics.logEvent('auth_dev_signin_success');
      if (context.mounted) context.go('/home');
    } on AuthException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Dev sign in failed: ${e.message}')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Dev sign in failed: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    Analytics.logScreenView('welcome');
    final hasDevCredentials = (dotenv.env['DEV_EMAIL']?.trim().isNotEmpty ?? false) &&
        (dotenv.env['DEV_PASSWORD']?.isNotEmpty ?? false);
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
                'Travel App',
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.5,
                    ),
              ),
              const SizedBox(height: AppTheme.spacingSm),
              Text(
                'Plan trips, discover places, share adventures',
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
                label: 'Continue with Apple',
                onPressed: () {
                  Analytics.logEvent('auth_apple_clicked');
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Apple Sign In coming soon')),
                  );
                },
              ),
              const SizedBox(height: AppTheme.spacingMd),
              _AuthButton(
                icon: Icons.g_mobiledata_rounded,
                label: 'Continue with Google',
                onPressed: () {
                  Analytics.logEvent('auth_google_clicked');
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Google Sign In coming soon')),
                  );
                },
              ),
              const SizedBox(height: AppTheme.spacingMd),
              _AuthButton(
                icon: Icons.email_rounded,
                label: 'Continue with Email',
                filled: true,
                onPressed: () {
                  Analytics.logEvent('auth_email_clicked');
                  context.push('/auth/email');
                },
              ),
              if (hasDevCredentials) ...[
                const SizedBox(height: AppTheme.spacingMd),
                _AuthButton(
                  icon: Icons.bug_report_rounded,
                  label: 'Developer sign in',
                  onPressed: () => _developerSignIn(context),
                ),
              ],
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
