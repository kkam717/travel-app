import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/theme.dart';
import '../core/analytics.dart';
import '../core/rate_limiter.dart';
import '../core/input_validation.dart';
import '../l10n/app_strings.dart';

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
      validateEmail(_emailController.text);
      validatePassword(_passwordController.text, isSignUp: _isSignUp);
      final action = _isSignUp ? RateLimitActions.authSignUp : RateLimitActions.authSignIn;
      RateLimiter.instance.checkLimit(action, maxPerMinute: RateLimitActions.defaultAuthPerMinute);

      if (_isSignUp) {
        final name = sanitizeString(_nameController.text, maxLen: maxNameLength);
        await Supabase.instance.client.auth.signUp(
          email: _emailController.text.trim(),
          password: _passwordController.text,
          data: {'name': name},
        );
        Analytics.logEvent('auth_signup_success');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(AppStrings.t(context, 'account_created'))),
          );
          context.go('/onboarding');
        }
      } else {
        await Supabase.instance.client.auth.signInWithPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
        Analytics.logEvent('auth_signin_success');
        if (mounted) context.go('/explore');
      }
    } on RateLimitExceededException catch (_) {
      setState(() {
        _errorMessage = AppStrings.t(context, 'rate_limit_try_again');
        _isLoading = false;
      });
    } on ValidationException catch (e) {
      setState(() {
        _errorMessage = e.message;
        _isLoading = false;
      });
    } on AuthException catch (e) {
      setState(() {
        _errorMessage = e.message;
        _isLoading = false;
      });
      Analytics.logEvent('auth_error', {'message': e.message});
    } catch (e, st) {
      debugPrint('Signup error: $e\n$st');
      setState(() {
        _errorMessage = e is AuthException ? e.message : AppStrings.t(context, 'something_went_wrong');
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppStrings.t(context, 'email')),
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
                  _isSignUp ? AppStrings.t(context, 'create_account') : AppStrings.t(context, 'welcome_back'),
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: AppTheme.spacingSm),
                Text(
                  _isSignUp ? AppStrings.t(context, 'create_account_subtitle') : AppStrings.t(context, 'sign_in_subtitle'),
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
                    decoration: InputDecoration(
                      labelText: AppStrings.t(context, 'name'),
                      hintText: AppStrings.t(context, 'your_name'),
                      prefixIcon: Icon(Icons.person_outline_rounded),
                    ),
                    validator: (v) => v == null || v.trim().isEmpty ? AppStrings.t(context, 'please_enter_name') : null,
                  ),
                if (_isSignUp) const SizedBox(height: AppTheme.spacingMd),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: AppStrings.t(context, 'email'),
                    hintText: AppStrings.t(context, 'you_example_email'),
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                  validator: (v) => v == null || v.isEmpty ? AppStrings.t(context, 'enter_email') : null,
                ),
                const SizedBox(height: AppTheme.spacingMd),
                TextFormField(
                  controller: _passwordController,
                  obscureText: true,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _submit(),
                  decoration: InputDecoration(
                    labelText: AppStrings.t(context, 'password'),
                    hintText: _isSignUp ? AppStrings.t(context, 'min_6_characters') : null,
                    prefixIcon: const Icon(Icons.lock_outline_rounded),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return AppStrings.t(context, 'enter_password');
                    if (_isSignUp && v.length < 6) return AppStrings.t(context, 'password_min_6');
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
                      : Text(_isSignUp ? AppStrings.t(context, 'create_account') : AppStrings.t(context, 'sign_in')),
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
                    _isSignUp ? AppStrings.t(context, 'already_have_account') : AppStrings.t(context, 'dont_have_account'),
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
