import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/theme.dart';
import '../core/analytics.dart';
import '../core/profile_cache.dart';
import '../data/countries.dart';
import '../models/profile.dart';
import '../models/user_city.dart';
import '../services/places_service.dart';
import '../services/supabase_service.dart';
import '../l10n/app_strings.dart';
import '../widgets/location_with_flag.dart';
import '../widgets/places_field.dart';

/// Shows home town, lived before cities, and travel styles.
/// Editable when viewing own profile.
class ProfileStatsScreen extends StatefulWidget {
  final String? userId;
  /// If set and the corresponding field is empty, auto-open its editor.
  /// Values: 'current_city', 'past_cities', 'travel_styles'
  final String? openEditor;

  const ProfileStatsScreen({super.key, this.userId, this.openEditor});

  @override
  State<ProfileStatsScreen> createState() => _ProfileStatsScreenState();
}

class _ProfileStatsScreenState extends State<ProfileStatsScreen> {
  Profile? _profile;
  List<UserPastCity> _pastCities = [];
  bool _isLoading = true;
  String? _error;

  String get _effectiveUserId =>
      widget.userId ?? Supabase.instance.client.auth.currentUser?.id ?? '';

  bool get _isOwnProfile =>
      widget.userId == null ||
      widget.userId == Supabase.instance.client.auth.currentUser?.id;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(ProfileStatsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userId != widget.userId) _load();
  }

  Future<void> _load() async {
    final userId = _effectiveUserId;
    if (userId.isEmpty) return;
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        SupabaseService.getProfile(userId),
        SupabaseService.getPastCities(userId),
      ]);
      if (!mounted) return;
      setState(() {
        _profile = results[0] as Profile?;
        _pastCities = results[1] as List<UserPastCity>;
        _isLoading = false;
      });
      if (_isOwnProfile && userId.isNotEmpty) {
        ProfileCache.updateProfileAndPastCities(userId, _profile, _pastCities);
        _syncLivedCountriesToVisited(userId);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Something went wrong. Pull down to retry.';
        _isLoading = false;
      });
    }
    if (mounted && _isOwnProfile && widget.openEditor != null) _maybeOpenEditor();
  }

  void _maybeOpenEditor() {
    final open = widget.openEditor;
    if (open == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      switch (open) {
        case 'current_city':
          if (_profile?.currentCity?.trim().isEmpty != false) {
            await _showCurrentCityEditor(_profile?.currentCity ?? '', (city) => _updateProfile(currentCity: city));
          }
          break;
        case 'past_cities':
          if (_pastCities.isEmpty) {
            await _showPastCitiesEditor(_pastCities, _load);
          }
          break;
        case 'travel_styles':
          if ((_profile?.travelStyles ?? []).isEmpty) {
            await _showStylesEditor(_profile?.travelStyles ?? [], (list) => _updateProfile(travelStyles: list));
          }
          break;
      }
    });
  }

  Future<void> _updateProfile({String? currentCity, List<String>? travelStyles}) async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null || !_isOwnProfile) return;
    final data = <String, dynamic>{};
    if (currentCity != null) {
      final newCity = currentCity.trim().isEmpty ? null : currentCity.trim();
      final previousCity = _profile?.currentCity?.trim();
      if (previousCity != null &&
          previousCity.isNotEmpty &&
          (newCity == null || previousCity.toLowerCase() != newCity.toLowerCase())) {
        final alreadyInPast = _pastCities.any(
          (c) => c.cityName.trim().toLowerCase() == previousCity.toLowerCase(),
        );
        if (!alreadyInPast) {
          try {
            await SupabaseService.addPastCity(userId, previousCity);
          } catch (_) {}
        }
      }
      if (newCity != null && newCity.isNotEmpty) {
        for (final past in _pastCities) {
          if (past.cityName.trim().toLowerCase() == newCity.toLowerCase()) {
            await SupabaseService.removePastCity(past.id);
            break;
          }
        }
      }
      data['current_city'] = newCity;
    }
    if (travelStyles != null) {
      data['travel_styles'] = travelStyles.map((s) => s.toLowerCase()).toList();
    }
    await SupabaseService.updateProfile(userId, data);
    await _load();
  }

  /// Ensures visited_countries includes countries from lived cities (current + past).
  Future<void> _syncLivedCountriesToVisited(String userId) async {
    final cities = <String>[];
    if (_profile?.currentCity?.trim().isNotEmpty == true) {
      cities.add(_profile!.currentCity!.trim());
    }
    cities.addAll(_pastCities.map((c) => c.cityName.trim()).where((s) => s.isNotEmpty));
    if (cities.isEmpty) return;

    final visited = (_profile?.visitedCountries ?? []).toSet();
    var changed = false;
    for (final city in cities) {
      final code = await PlacesService.geocodeToCountryCode(city);
      if (code != null && !visited.contains(code)) {
        visited.add(code);
        changed = true;
      }
    }
    if (changed && mounted) {
      final list = visited.toList()..sort();
      try {
        await SupabaseService.updateProfile(userId, {'visited_countries': list});
        if (!mounted) return;
        final updated = await SupabaseService.getProfile(userId);
        if (mounted && updated != null) {
          setState(() => _profile = updated);
          ProfileCache.updateProfileAndPastCities(userId, updated, _pastCities);
          ProfileCache.updateVisitedCountries(userId, list);
        }
      } catch (_) {}
    }
  }

  Future<void> _showCurrentCityEditor(String initial, void Function(String) onSave) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.spacingLg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(AppStrings.t(context, 'home_town'), style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: AppTheme.spacingLg),
                PlacesField(
                  hint: AppStrings.t(context, 'search_for_your_city'),
                  placeType: 'city',
                  countryCodes: (_profile?.visitedCountries != null && _profile!.visitedCountries.isNotEmpty)
                      ? _profile!.visitedCountries
                      : null,
                  onSelected: (name, _, __, ___, ____) {
                    onSave(name);
                    Navigator.pop(ctx);
                    _load();
                  },
                ),
                if (initial.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      'Current: $initial',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ),
                const SizedBox(height: 16),
                TextButton(onPressed: () => Navigator.pop(ctx), child: Text(AppStrings.t(context, 'cancel'))),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showPastCitiesEditor(List<UserPastCity> initial, VoidCallback onDone) async {
    List<UserPastCity> pastCities = List.from(initial);
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (_, setModal) {
          return DraggableScrollableSheet(
            initialChildSize: 0.6,
            expand: false,
            builder: (_, scrollController) => Padding(
              padding: const EdgeInsets.all(AppTheme.spacingMd),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(AppStrings.t(context, 'lived_before'), style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  Text(
                    AppStrings.t(context, 'cities_previously_lived'),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                  const SizedBox(height: AppTheme.spacingMd),
                  Expanded(
                    child: ListView.builder(
                      controller: scrollController,
                      itemCount: pastCities.length + 1,
                      itemBuilder: (_, i) {
                        if (i == pastCities.length) {
                          return ListTile(
                            leading: Icon(Icons.add, color: Theme.of(context).colorScheme.primary),
                            title: Text(AppStrings.t(context, 'add_city'), style: TextStyle(color: Theme.of(context).colorScheme.primary)),
                            onTap: () async {
                              final name = await showDialog<String>(
                                context: context,
                                builder: (dctx) => Dialog(
                                  child: Padding(
                                    padding: const EdgeInsets.all(AppTheme.spacingLg),
                                    child: SingleChildScrollView(
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        crossAxisAlignment: CrossAxisAlignment.stretch,
                                        children: [
                                          Text(AppStrings.t(context, 'add_city'), style: Theme.of(dctx).textTheme.titleLarge),
                                          const SizedBox(height: 16),
                                          PlacesField(
                                            hint: AppStrings.t(context, 'search_for_city'),
                                            placeType: 'city',
                                            countryCodes: (_profile?.visitedCountries != null && _profile!.visitedCountries.isNotEmpty)
                                                ? _profile!.visitedCountries
                                                : null,
                                            onSelected: (placeName, _, __, ___, ____) {
                                              Navigator.pop(dctx, placeName);
                                            },
                                          ),
                                          const SizedBox(height: 16),
                                          TextButton(onPressed: () => Navigator.pop(dctx), child: Text(AppStrings.t(context, 'cancel'))),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              );
                              if (name != null && name.isNotEmpty) {
                                final userId = Supabase.instance.client.auth.currentUser?.id;
                                if (userId != null) {
                                  try {
                                    final added = await SupabaseService.addPastCity(userId, name);
                                    if (added != null) setModal(() => pastCities = [...pastCities, added]);
                                  } catch (e) {
                                    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not add: $e')));
                                  }
                                }
                              }
                            },
                          );
                        }
                        final pastCity = pastCities[i];
                        return ListTile(
                          leading: Icon(Icons.location_city_outlined, color: Theme.of(context).colorScheme.onSurfaceVariant),
                          title: Text(pastCity.cityName),
                          trailing: IconButton(
                            icon: const Icon(Icons.close, size: 20),
                            onPressed: () async {
                              try {
                                await SupabaseService.removePastCity(pastCity.id);
                                setModal(() => pastCities = pastCities.where((c) => c.id != pastCity.id).toList());
                              } catch (e) {
                                if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${AppStrings.t(context, 'could_not_remove')}: $e')));
                              }
                            },
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: AppTheme.spacingMd),
                  FilledButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      onDone();
                    },
                    child: Text(AppStrings.t(context, 'done')),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _showStylesEditor(List<String> initial, void Function(List<String>) onSave) async {
    Set<String> selected = initial.toSet();
    await showModalBottomSheet(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (_, setModal) => Padding(
          padding: const EdgeInsets.all(24),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(AppStrings.t(context, 'travel_styles'), style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: travelStyles.map((s) {
                    final sel = selected.contains(s);
                    return FilterChip(
                      label: Text(s),
                      selected: sel,
                      onSelected: (_) => setModal(() {
                        if (sel) selected.remove(s);
                        else selected.add(s);
                      }),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    TextButton(onPressed: () => Navigator.pop(ctx), child: Text(AppStrings.t(context, 'cancel'))),
                    const Spacer(),
                    FilledButton(
                      onPressed: () {
                        onSave(selected.toList());
                        Navigator.pop(ctx);
                        _load();
                      },
                      child: Text(AppStrings.t(context, 'save')),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static IconData _iconForTravelStyle(String style) {
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

  @override
  Widget build(BuildContext context) {
    Analytics.logScreenView('profile_stats');
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        title: Text(
          AppStrings.t(context, 'travel_profile'),
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
          ),
        ),
        actions: [
          if (_isOwnProfile && !_isLoading)
            Container(
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(10),
              ),
              child: IconButton(
                icon: Icon(Icons.edit_outlined, size: 20, color: cs.onSurfaceVariant),
                onPressed: () => _showEditSheet(),
                constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                padding: const EdgeInsets.all(8),
              ),
            ),
        ],
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 40,
                    height: 40,
                    child: CircularProgressIndicator(strokeWidth: 2, color: cs.primary),
                  ),
                  const SizedBox(height: AppTheme.spacingLg),
                  Text(
                    AppStrings.t(context, 'loading'),
                    style: theme.textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            )
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(AppTheme.spacingLg),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.error_outline, size: 64, color: cs.outline),
                        const SizedBox(height: AppTheme.spacingLg),
                        Text(_error!, textAlign: TextAlign.center, style: theme.textTheme.bodyLarge),
                        const SizedBox(height: AppTheme.spacingLg),
                        FilledButton.icon(
                          onPressed: _load,
                          icon: const Icon(Icons.refresh, size: 20),
                          label: Text(AppStrings.t(context, 'retry')),
                        ),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(AppTheme.spacingLg, AppTheme.spacingMd, AppTheme.spacingLg, AppTheme.spacingXl + 80),
                    children: [
                      // Subtitle
                      Text(
                        AppStrings.t(context, 'how_you_travel_subtitle'),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: AppTheme.spacingLg),
                      _buildBaseLocationSection(theme, cs),
                      const SizedBox(height: AppTheme.spacingLg),
                      _buildPlacesLivedSection(theme, cs),
                      const SizedBox(height: AppTheme.spacingLg),
                      _buildTravelStylesSection(theme, cs),
                    ],
                  ),
                ),
    );
  }

  Widget _buildBaseLocationSection(ThemeData theme, ColorScheme cs) {
    final city = _profile?.currentCity?.trim();
    final hasCity = city != null && city.isNotEmpty;
    final displayText = hasCity ? city! : AppStrings.t(context, 'not_set');
    final cardColor = theme.brightness == Brightness.light
        ? Colors.white
        : cs.surfaceContainerHighest;

    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: cs.shadow.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: hasCity
              ? () => context.push('/city/${Uri.encodeComponent(city!)}?userId=$_effectiveUserId')
              : (_isOwnProfile
                  ? () async {
                      await _showCurrentCityEditor(_profile?.currentCity ?? '', (c) => _updateProfile(currentCity: c));
                    }
                  : null),
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                LocationFlagIcon(city: hasCity ? city : null, fontSize: 28),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppStrings.t(context, 'based_in'),
                        style: theme.textTheme.labelLarge?.copyWith(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.0,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        displayText,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: hasCity ? cs.onSurface : cs.onSurfaceVariant,
                          letterSpacing: -0.3,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                if (hasCity)
                  Icon(Icons.chevron_right_rounded, size: 20, color: cs.onSurfaceVariant),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPlacesLivedSection(ThemeData theme, ColorScheme cs) {
    final cardColor = theme.brightness == Brightness.light
        ? Colors.white
        : cs.surfaceContainerHighest;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: cs.shadow.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppStrings.t(context, 'places_youve_lived').toUpperCase(),
            style: theme.textTheme.labelLarge?.copyWith(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.0,
              color: cs.onSurfaceVariant,
            ),
          ),
          if (_isOwnProfile)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                AppStrings.t(context, 'tap_city_for_top_5_hint'),
                style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              ),
            ),
          const SizedBox(height: 16),
          if (_pastCities.isEmpty && _isOwnProfile)
            InkWell(
              onTap: () async => await _showPastCitiesEditor(_pastCities, _load),
              borderRadius: BorderRadius.circular(14),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: cs.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: cs.primary.withValues(alpha: 0.2)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add_rounded, size: 18, color: cs.primary),
                    const SizedBox(width: 8),
                    Text(
                      AppStrings.t(context, 'add_city'),
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: cs.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: _pastCities.map((c) {
                return Material(
                  color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(14),
                  child: InkWell(
                    onTap: () => context.push('/city/${Uri.encodeComponent(c.cityName)}?userId=$_effectiveUserId'),
                    borderRadius: BorderRadius.circular(14),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.location_city_rounded, size: 18, color: cs.onSurfaceVariant),
                          const SizedBox(width: 8),
                          Text(
                            c.cityName,
                            style: theme.textTheme.labelLarge?.copyWith(
                              fontWeight: FontWeight.w500,
                              color: cs.onSurface,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildTravelStylesSection(ThemeData theme, ColorScheme cs) {
    final styles = _profile?.travelStyles ?? [];
    final cardColor = theme.brightness == Brightness.light
        ? Colors.white
        : cs.surfaceContainerHighest;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: cs.shadow.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppStrings.t(context, 'how_you_like_to_travel').toUpperCase(),
            style: theme.textTheme.labelLarge?.copyWith(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.0,
              color: cs.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          if (styles.isEmpty && _isOwnProfile)
            InkWell(
              onTap: () async => await _showStylesEditor([], (list) => _updateProfile(travelStyles: list)),
              borderRadius: BorderRadius.circular(14),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                decoration: BoxDecoration(
                  color: cs.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: cs.primary.withValues(alpha: 0.2)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add_rounded, size: 20, color: cs.primary),
                    const SizedBox(width: 10),
                    Text(
                      AppStrings.t(context, 'travel_styles'),
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: cs.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: styles.map((s) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: cs.primary.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(_iconForTravelStyle(s), size: 20, color: cs.primary),
                      const SizedBox(width: 10),
                      Text(
                        s,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: cs.primary,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  Future<void> _showEditSheet() async {
    final p = _profile;
    if (p == null) return;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.all(AppTheme.spacingLg),
        children: [
          Text(AppStrings.t(context, 'edit_stats'), style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: AppTheme.spacingLg),
          ListTile(
            leading: const Icon(Icons.location_city_outlined),
            title: Text(AppStrings.t(context, 'home_town')),
            subtitle: Text(p.currentCity?.trim().isNotEmpty == true ? p.currentCity! : AppStrings.t(context, 'not_set')),
            trailing: const Icon(Icons.chevron_right),
            onTap: () async {
              Navigator.pop(ctx);
              await _showCurrentCityEditor(p.currentCity ?? '', (city) => _updateProfile(currentCity: city));
            },
          ),
          ListTile(
            leading: const Icon(Icons.history_outlined),
            title: Text(AppStrings.t(context, 'lived_before')),
            subtitle: Text(_pastCities.isEmpty ? AppStrings.t(context, 'none') : '${_pastCities.length} ${AppStrings.t(context, 'cities')}'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () async {
              Navigator.pop(ctx);
              await _showPastCitiesEditor(_pastCities, _load);
            },
          ),
          ListTile(
            leading: const Icon(Icons.style_outlined),
            title: Text(AppStrings.t(context, 'travel_styles')),
            subtitle: Text(p.travelStyles.isEmpty ? AppStrings.t(context, 'none') : p.travelStyles.join(', ')),
            trailing: const Icon(Icons.chevron_right),
            onTap: () async {
              Navigator.pop(ctx);
              await _showStylesEditor(p.travelStyles, (list) => _updateProfile(travelStyles: list));
            },
          ),
        ],
      ),
    );
  }
}
