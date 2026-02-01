import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/theme.dart';
import '../core/analytics.dart';
import '../core/profile_cache.dart';
import '../data/countries.dart';
import '../models/profile.dart';
import '../models/user_city.dart';
import '../services/google_places_service.dart';
import '../services/supabase_service.dart';
import '../widgets/google_places_field.dart';

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
      final code = await GooglePlacesService.geocodeToCountryCode(city);
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
                Text('Home Town', style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: AppTheme.spacingLg),
                GooglePlacesField(
                  hint: 'Search for your city…',
                  placeType: 'locality',
                  onSelected: (name, _, __, ___) {
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
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
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
                  Text('Lived Before', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  Text(
                    'Cities you previously lived in',
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
                            title: Text('Add city', style: TextStyle(color: Theme.of(context).colorScheme.primary)),
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
                                          Text('Add city', style: Theme.of(dctx).textTheme.titleLarge),
                                          const SizedBox(height: 16),
                                          GooglePlacesField(
                                            hint: 'Search for a city…',
                                            placeType: 'locality',
                                            onSelected: (placeName, _, __, ___) {
                                              Navigator.pop(dctx, placeName);
                                            },
                                          ),
                                          const SizedBox(height: 16),
                                          TextButton(onPressed: () => Navigator.pop(dctx), child: const Text('Cancel')),
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
                                if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not remove: $e')));
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
                    child: const Text('Done'),
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Travel styles', style: Theme.of(context).textTheme.titleMedium),
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
                  TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                  const Spacer(),
                  FilledButton(
                    onPressed: () {
                      onSave(selected.toList());
                      Navigator.pop(ctx);
                      _load();
                    },
                    child: const Text('Save'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Analytics.logScreenView('profile_stats');
    return Scaffold(
      appBar: AppBar(
        title: const Text('Stats'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        actions: [
          if (_isOwnProfile && !_isLoading)
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => _showEditSheet(),
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
                    child: CircularProgressIndicator(strokeWidth: 2, color: Theme.of(context).colorScheme.primary),
                  ),
                  const SizedBox(height: AppTheme.spacingLg),
                  Text(
                    'Loading…',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
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
                        Icon(Icons.error_outline, size: 64, color: Theme.of(context).colorScheme.outline),
                        const SizedBox(height: AppTheme.spacingLg),
                        Text(_error!, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyLarge),
                        const SizedBox(height: AppTheme.spacingLg),
                        FilledButton.icon(onPressed: _load, icon: const Icon(Icons.refresh, size: 20), label: const Text('Retry')),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(AppTheme.spacingLg),
                    children: [
                      _buildSection(
                        'Home Town',
                        _profile?.currentCity?.trim().isNotEmpty == true
                            ? _profile!.currentCity!
                            : 'Not set',
                        Icons.location_city,
                        onTap: _profile?.currentCity?.trim().isNotEmpty == true
                            ? () => context.push('/city/${Uri.encodeComponent(_profile!.currentCity!)}?userId=$_effectiveUserId')
                            : (_isOwnProfile
                                ? () async {
                                    await _showCurrentCityEditor(_profile?.currentCity ?? '', (city) => _updateProfile(currentCity: city));
                                  }
                                : null),
                      ),
                      const SizedBox(height: AppTheme.spacingLg),
                      _buildSection(
                        'Lived Before',
                        _pastCities.isEmpty ? 'None' : _pastCities.map((c) => c.cityName).join(', '),
                        Icons.history_outlined,
                        chips: _pastCities.map((c) => ActionChip(
                              avatar: Icon(Icons.location_city_outlined, size: 18, color: Theme.of(context).colorScheme.primary),
                              label: Text(c.cityName),
                              onPressed: () => context.push('/city/${Uri.encodeComponent(c.cityName)}?userId=$_effectiveUserId'),
                            )).toList(),
                        onTap: _pastCities.isEmpty && _isOwnProfile
                            ? () async {
                                await _showPastCitiesEditor(_pastCities, _load);
                              }
                            : null,
                      ),
                      const SizedBox(height: AppTheme.spacingLg),
                      _buildSection(
                        'Travel styles',
                        (_profile?.travelStyles ?? []).isEmpty ? 'None' : (_profile!.travelStyles).join(', '),
                        Icons.style_outlined,
                        chips: (_profile?.travelStyles ?? []).map((s) => Chip(label: Text(s))).toList(),
                        onTap: (_profile?.travelStyles ?? []).isEmpty && _isOwnProfile
                            ? () async {
                                await _showStylesEditor(_profile?.travelStyles ?? [], (list) => _updateProfile(travelStyles: list));
                              }
                            : null,
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildSection(
    String title,
    String subtitle,
    IconData icon, {
    VoidCallback? onTap,
    List<Widget>? chips,
  }) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingMd),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 22, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 8),
              Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: AppTheme.spacingSm),
          if (chips != null && chips.isNotEmpty)
            Wrap(spacing: 8, runSpacing: 8, children: chips)
          else if (onTap != null)
            InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        subtitle,
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    ),
                    Icon(Icons.chevron_right, color: Theme.of(context).colorScheme.onSurfaceVariant),
                  ],
                ),
              ),
            )
          else
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: subtitle == 'None' ? Theme.of(context).colorScheme.onSurfaceVariant : null,
                  ),
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
          Text('Edit Stats', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: AppTheme.spacingLg),
          ListTile(
            leading: const Icon(Icons.location_city_outlined),
            title: const Text('Home town'),
            subtitle: Text(p.currentCity?.trim().isNotEmpty == true ? p.currentCity! : 'Not set'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () async {
              Navigator.pop(ctx);
              await _showCurrentCityEditor(p.currentCity ?? '', (city) => _updateProfile(currentCity: city));
            },
          ),
          ListTile(
            leading: const Icon(Icons.history_outlined),
            title: const Text('Lived before'),
            subtitle: Text(_pastCities.isEmpty ? 'None' : '${_pastCities.length} cities'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () async {
              Navigator.pop(ctx);
              await _showPastCitiesEditor(_pastCities, _load);
            },
          ),
          ListTile(
            leading: const Icon(Icons.style_outlined),
            title: const Text('Travel styles'),
            subtitle: Text(p.travelStyles.isEmpty ? 'None' : p.travelStyles.join(', ')),
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
