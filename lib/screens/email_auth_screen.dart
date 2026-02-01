import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/theme.dart';
import '../core/analytics.dart';

class EmailAuthScreen extends StatefulWidget {
  const EmailAuthScreen({super.key});

  @override
  State<EmailAuthScreen> createState() => _EmailAuthScreenState();
}

class _EmailAuthScreenState extends State<EmailAuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isSignUp = false;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      if (_isSignUp) {
        await Supabase.instance.client.auth.signUp(
          email: _emailController.text.trim(),
          password: _passwordController.text,
          data: {'name': _nameController.text.trim()},
        );
        Analytics.logEvent('auth_signup_success');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Account created')),
          );
          context.go('/onboarding');
        }
      } else {
        await Supabase.instance.client.auth.signInWithPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
        Analytics.logEvent('auth_signin_success');
        if (mounted) context.go('/home');
      }
    } on AuthException catch (e) {
      setState(() {
        _errorMessage = e.message;
        _isLoading = false;
      });
      Analytics.logEvent('auth_error', {'message': e.message});
    } catch (e, st) {
      debugPrint('Signup error: $e\n$st');
      setState(() {
        _errorMessage = e is AuthException ? e.message : 'Something went wrong. Please try again.';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Email'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppTheme.spacingLg),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: AppTheme.spacingMd),
                Text(
                  _isSignUp ? 'Create account' : 'Welcome back',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: AppTheme.spacingSm),
                Text(
                  _isSignUp ? 'Enter your name, email and password to get started' : 'Sign in to continue planning your trips',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: AppTheme.spacingXl),
                if (_isSignUp)
                  TextFormField(
                    controller: _nameController,
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Name',
                      hintText: 'Your name',
                      prefixIcon: Icon(Icons.person_outline_rounded),
                    ),
                    validator: (v) => v == null || v.trim().isEmpty ? 'Enter your name' : null,
                  ),
                if (_isSignUp) const SizedBox(height: AppTheme.spacingMd),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    hintText: 'you@example.com',
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                  validator: (v) => v == null || v.isEmpty ? 'Enter your email' : null,
                ),
                const SizedBox(height: AppTheme.spacingMd),
                TextFormField(
                  controller: _passwordController,
                  obscureText: true,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _submit(),
                  decoration: InputDecoration(
                    labelText: 'Password',
                    hintText: _isSignUp ? 'Min 6 characters' : null,
                    prefixIcon: const Icon(Icons.lock_outline_rounded),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Enter your password';
                    if (_isSignUp && v.length < 6) return 'Password must be at least 6 characters';
                    return null;
                  },
                ),
                if (_errorMessage != null) ...[
                  const SizedBox(height: AppTheme.spacingMd),
                  Container(
                    padding: const EdgeInsets.all(AppTheme.spacingMd),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.errorContainer.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline_rounded, size: 20, color: Theme.of(context).colorScheme.error),
                        const SizedBox(width: AppTheme.spacingSm),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 14),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: AppTheme.spacingXl),
                FilledButton(
                  onPressed: _isLoading ? null : _submit,
                  child: _isLoading
                      ? SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Theme.of(context).colorScheme.onPrimary,
                          ),
                        )
                      : Text(_isSignUp ? 'Create account' : 'Sign in'),
                ),
                const SizedBox(height: AppTheme.spacingMd),
                TextButton(
                  onPressed: _isLoading
                      ? null
                      : () {
                          setState(() {
                            _isSignUp = !_isSignUp;
                            _errorMessage = null;
                            if (!_isSignUp) _nameController.clear();
                          });
                        },
                  child: Text(
                    _isSignUp ? 'Already have an account? Sign in' : "Don't have an account? Sign up",
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
