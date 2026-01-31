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
  final _nameController = TextEditingController();
  final _searchController = TextEditingController();
  Set<String> _selectedCountries = {};
  Set<String> _selectedStyles = {};
  String? _selectedMode;
  bool _isLoading = false;
  String _searchQuery = '';
  String? _nameError;

  @override
  void dispose() {
    _nameController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  List<MapEntry<String, String>> get _filteredCountries {
    if (_searchQuery.isEmpty) return countries.entries.toList();
    final q = _searchQuery.toLowerCase();
    return countries.entries
        .where((e) => e.value.toLowerCase().contains(q) || e.key.toLowerCase().contains(q))
        .toList();
  }

  Future<void> _completeOnboarding() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    final name = _nameController.text.trim();
    if (userId == null) return;
    if (name.isEmpty) {
      setState(() => _nameError = 'Please enter your name');
      return;
    }
    setState(() => _isLoading = true);
    try {
      await SupabaseService.updateProfile(userId, {
        'name': name,
        'visited_countries': _selectedCountries.toList(),
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
    final stepTitles = ['Your name', 'Countries visited', 'Travel preferences'];
    return Scaffold(
      appBar: AppBar(
        title: Text(stepTitles[_step.clamp(0, 2)]),
        actions: [
          TextButton(
            onPressed: _signOut,
            child: const Text('Sign out'),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Step indicator
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingLg, vertical: AppTheme.spacingMd),
              child: Row(
                children: List.generate(3, (i) {
                  final active = i <= _step;
                  return Expanded(
                    child: Container(
                      margin: EdgeInsets.only(right: i < 2 ? 8 : 0),
                      height: 4,
                      decoration: BoxDecoration(
                        color: active
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  );
                }),
              ),
            ),
            Expanded(
              child: _step == 0 ? _buildNameStep() : _step == 1 ? _buildCountriesStep() : _buildStylesStep(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNameStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppTheme.spacingLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: AppTheme.spacingMd),
          Text(
            "What's your name?",
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: AppTheme.spacingSm),
          Text(
            "We'll use this when you share your trips",
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: AppTheme.spacingXl),
          TextField(
            controller: _nameController,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              labelText: 'Name',
              hintText: 'Enter your name',
              errorText: _nameError,
              prefixIcon: const Icon(Icons.person_outline_rounded),
            ),
            onChanged: (_) => setState(() => _nameError = null),
          ),
          const SizedBox(height: AppTheme.spacingXl),
          FilledButton(
            onPressed: () {
              final name = _nameController.text.trim();
              if (name.isEmpty) {
                setState(() => _nameError = 'Please enter your name');
              } else {
                setState(() {
                  _nameError = null;
                  _step = 1;
                });
              }
            },
            child: const Text('Next'),
          ),
        ],
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
            decoration: InputDecoration(
              hintText: 'Search countries...',
              prefixIcon: const Icon(Icons.search_rounded),
              filled: true,
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
              return Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    setState(() {
                      if (selected) {
                        _selectedCountries.remove(e.key);
                      } else {
                        _selectedCountries.add(e.key);
                      }
                    });
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
                    child: Row(
                      children: [
                        Icon(
                          selected ? Icons.check_circle_rounded : Icons.circle_outlined,
                          color: selected ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.outline,
                          size: 24,
                        ),
                        const SizedBox(width: AppTheme.spacingMd),
                        Text(e.value, style: Theme.of(context).textTheme.bodyLarge),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(AppTheme.spacingMd),
          child: FilledButton(
            onPressed: () => setState(() => _step = 2),
            child: const Text('Next'),
          ),
        ),
      ],
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
