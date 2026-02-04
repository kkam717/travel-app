import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/theme.dart';
import '../core/analytics.dart';
import '../data/countries.dart' show travelStyles, travelModes;
import '../l10n/app_strings.dart';
import '../services/supabase_service.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  Set<String> _selectedStyles = {};
  String? _selectedMode;
  bool _isLoading = false;

  Future<void> _completeOnboarding() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;
    setState(() => _isLoading = true);
    try {
      await SupabaseService.updateProfile(userId, {
        'travel_styles': _selectedStyles.map((s) => s.toLowerCase()).toList(),
        'travel_mode': _selectedMode?.toLowerCase(),
        'onboarding_complete': true,
      });
      Analytics.logEvent('onboarding_complete');
      if (mounted) {
        await Future.delayed(const Duration(milliseconds: 200));
        if (mounted) context.go('/explore');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppStrings.t(context, 'could_not_save')), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _signOut() async {
    await Supabase.instance.client.auth.signOut();
    if (mounted) context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppStrings.t(context, 'travel_preferences')),
        actions: [
          TextButton(
            onPressed: _signOut,
            child: Text(AppStrings.t(context, 'sign_out')),
          ),
        ],
      ),
      body: SafeArea(
        child: _buildStylesStep(),
      ),
    );
  }

  Widget _buildStylesStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppTheme.spacingLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppStrings.t(context, 'travel_styles'),
            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: AppTheme.spacingSm),
          Text(
            AppStrings.t(context, 'select_travel_vibe'),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: AppTheme.spacingMd),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: travelStyles.map((s) {
              final selected = _selectedStyles.contains(s);
              return FilterChip(
                label: Text(s),
                selected: selected,
                onSelected: (_) {
                  setState(() {
                    if (selected) {
                      _selectedStyles.remove(s);
                    } else {
                      _selectedStyles.add(s);
                    }
                  });
                },
              );
            }).toList(),
          ),
          const SizedBox(height: AppTheme.spacingXl),
          Text(
            AppStrings.t(context, 'travel_mode'),
            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: AppTheme.spacingSm),
          Text(
            AppStrings.t(context, 'optional_budget_luxury'),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: AppTheme.spacingMd),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: travelModes.map((s) {
              final selected = _selectedMode == s;
              return ChoiceChip(
                label: Text(s),
                selected: selected,
                onSelected: (_) => setState(() => _selectedMode = s),
              );
            }).toList(),
          ),
          const SizedBox(height: AppTheme.spacingXl),
          FilledButton(
            onPressed: _isLoading ? null : _completeOnboarding,
            child: _isLoading
                ? SizedBox(
                    height: 24,
                    width: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Theme.of(context).colorScheme.onPrimary,
                    ),
                  )
                : Text(AppStrings.t(context, 'get_started')),
          ),
        ],
      ),
    );
  }
}
