import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/theme.dart';
import '../core/analytics.dart';
import '../data/countries.dart';
import '../services/supabase_service.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  int _step = 0;
  final _searchController = TextEditingController();
  Set<String> _selectedCountries = {};
  Set<String> _selectedStyles = {};
  String? _selectedMode;
  bool _isLoading = false;
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<MapEntry<String, String>> get _filteredCountries {
    if (_searchQuery.isEmpty) return countries.entries.toList();
    final q = _searchQuery.toLowerCase();
    return countries.entries.where((e) => e.value.toLowerCase().contains(q) || e.key.toLowerCase().contains(q)).toList();
  }

  Future<void> _completeOnboarding() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;
    setState(() => _isLoading = true);
    try {
      await SupabaseService.updateProfile(userId, {
        'visited_countries': _selectedCountries.toList(),
        'travel_styles': _selectedStyles.map((s) => s.toLowerCase()).toList(),
        'travel_mode': _selectedMode?.toLowerCase(),
        'onboarding_complete': true,
      });
      Analytics.logEvent('onboarding_complete');
      if (mounted) context.go('/search');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_step == 0 ? 'Countries visited' : 'Travel preferences')),
      body: SafeArea(
        child: _step == 0 ? _buildCountriesStep() : _buildStylesStep(),
      ),
    );
  }

  Widget _buildCountriesStep() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(AppTheme.spacingMd),
          child: TextField(
            controller: _searchController,
            decoration: const InputDecoration(
              hintText: 'Search countries...',
              prefixIcon: Icon(Icons.search),
            ),
            onChanged: (v) => setState(() => _searchQuery = v),
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingMd),
            itemCount: _filteredCountries.length,
            itemBuilder: (_, i) {
              final e = _filteredCountries[i];
              final selected = _selectedCountries.contains(e.key);
              return CheckboxListTile(
                value: selected,
                onChanged: (_) {
                  setState(() {
                    if (selected) {
                      _selectedCountries.remove(e.key);
                    } else {
                      _selectedCountries.add(e.key);
                    }
                  });
                },
                title: Text(e.value),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(AppTheme.spacingMd),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => setState(() => _step = 1),
              child: const Text('Next'),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStylesStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppTheme.spacingMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Travel styles (multi-select)', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
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
          const SizedBox(height: 24),
          Text('Travel mode (single)', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
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
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _selectedMode == null || _isLoading
                  ? null
                  : _completeOnboarding,
              child: _isLoading ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Save & Continue'),
            ),
          ),
        ],
      ),
    );
  }
}
