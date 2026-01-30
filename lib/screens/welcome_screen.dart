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
