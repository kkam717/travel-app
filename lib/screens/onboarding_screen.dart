import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/theme.dart';
import '../core/analytics.dart';
import '../data/countries.dart' show travelStyles, travelModes;
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
        if (mounted) context.go('/home');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not save. Please try again.'), backgroundColor: Colors.red),
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
        title: const Text('Travel preferences'),
        actions: [
          TextButton(
            onPressed: _signOut,
            child: const Text('Sign out'),
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
            'Travel styles',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: AppTheme.spacingSm),
          Text(
            'Select what describes your travel vibe (multi-select)',
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
            'Travel mode',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: AppTheme.spacingSm),
          Text(
            'Optional – budget, standard, or luxury',
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
                : const Text('Get started'),
          ),
        ],
      ),
    );
  }
}
