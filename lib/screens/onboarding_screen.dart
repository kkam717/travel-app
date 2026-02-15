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
          SnackBar(content: Text(AppStrings.t(context, 'could_not_save')), backgroundColor: Theme.of(context).colorScheme.error),
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

  IconData _iconForStyle(String style) {
    final lower = style.toLowerCase();
    if (lower.contains('adventure')) return Icons.hiking_rounded;
    if (lower.contains('nature')) return Icons.eco_rounded;
    if (lower.contains('food')) return Icons.restaurant_rounded;
    if (lower.contains('culture')) return Icons.museum_rounded;
    if (lower.contains('relax')) return Icons.spa_rounded;
    if (lower.contains('nightlife')) return Icons.nightlife_rounded;
    if (lower.contains('urban')) return Icons.apartment_rounded;
    if (lower.contains('outdoor')) return Icons.terrain_rounded;
    if (lower.contains('slow')) return Icons.schedule_rounded;
    if (lower.contains('wellness')) return Icons.self_improvement_rounded;
    if (lower.contains('romantic')) return Icons.favorite_rounded;
    if (lower.contains('social')) return Icons.groups_rounded;
    if (lower.contains('family')) return Icons.family_restroom_rounded;
    if (lower.contains('road')) return Icons.directions_car_rounded;
    if (lower.contains('city')) return Icons.location_city_rounded;
    if (lower.contains('scenic')) return Icons.landscape_rounded;
    if (lower.contains('local')) return Icons.explore_rounded;
    if (lower.contains('offbeat')) return Icons.auto_awesome_rounded;
    return Icons.luggage_rounded;
  }

  IconData _iconForMode(String mode) {
    final lower = mode.toLowerCase();
    if (lower.contains('budget')) return Icons.savings_rounded;
    if (lower.contains('standard')) return Icons.luggage_rounded;
    if (lower.contains('luxury')) return Icons.diamond_rounded;
    return Icons.flight_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Custom header
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppTheme.spacingLg, AppTheme.spacingMd, AppTheme.spacingMd, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppStrings.t(context, 'travel_preferences'),
                          style: theme.textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          AppStrings.t(context, 'select_travel_vibe'),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: _signOut,
                    child: Text(
                      AppStrings.t(context, 'sign_out'),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppTheme.spacingLg),

            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingLg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Travel Styles
                    Text(
                      AppStrings.t(context, 'travel_styles'),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: travelStyles.map((s) {
                        final selected = _selectedStyles.contains(s);
                        return _StyleChip(
                          label: s,
                          icon: _iconForStyle(s),
                          selected: selected,
                          onTap: () {
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

                    // Travel Mode
                    Text(
                      AppStrings.t(context, 'travel_mode'),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      AppStrings.t(context, 'optional_budget_luxury'),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: travelModes.map((s) {
                        final selected = _selectedMode == s;
                        return Expanded(
                          child: Padding(
                            padding: EdgeInsets.only(
                              right: s != travelModes.last ? 10 : 0,
                            ),
                            child: _ModeCard(
                              label: s,
                              icon: _iconForMode(s),
                              selected: selected,
                              onTap: () => setState(() => _selectedMode = s),
                            ),
                          ),
                        );
                      }).toList(),
                    ),

                    const SizedBox(height: AppTheme.spacingXl),
                  ],
                ),
              ),
            ),

            // Bottom button
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppTheme.spacingLg, AppTheme.spacingSm, AppTheme.spacingLg, AppTheme.spacingMd),
              child: SizedBox(
                width: double.infinity,
                height: 54,
                child: FilledButton(
                  onPressed: _isLoading ? null : _completeOnboarding,
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: _isLoading
                      ? SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: cs.onPrimary,
                          ),
                        )
                      : Text(
                          AppStrings.t(context, 'get_started'),
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: cs.onPrimary,
                          ),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Style chip with icon
// ─────────────────────────────────────────────────────────────────────────────

class _StyleChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _StyleChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? cs.primary.withValues(alpha: 0.12) : cs.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? cs.primary : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: selected ? cs.primary : cs.onSurfaceVariant),
            const SizedBox(width: 8),
            Text(
              label,
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w600,
                color: selected ? cs.primary : cs.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Mode card (tall card with icon + label)
// ─────────────────────────────────────────────────────────────────────────────

class _ModeCard extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _ModeCard({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final cardColor = theme.brightness == Brightness.light
        ? Colors.white
        : cs.surfaceContainerHighest;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: selected ? cs.primary.withValues(alpha: 0.08) : cardColor,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? cs.primary : cs.outline.withValues(alpha: 0.3),
            width: selected ? 2 : 1,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: cs.primary.withValues(alpha: 0.15),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [
                  BoxShadow(
                    color: cs.shadow.withValues(alpha: 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 28,
              color: selected ? cs.primary : cs.onSurfaceVariant,
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w700,
                color: selected ? cs.primary : cs.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
