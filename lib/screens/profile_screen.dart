import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import '../core/theme.dart';
import '../core/analytics.dart';
import '../models/profile.dart';
import '../models/itinerary.dart';
import '../models/user_city.dart';
import '../data/countries.dart';
import '../widgets/google_places_field.dart';
import '../services/supabase_service.dart';

/// Merges profile visited countries with countries from all user itineraries.
List<String> _mergedVisitedCountries(Profile profile, List<Itinerary> itineraries) {
  final fromProfile = profile.visitedCountries.toSet();
  for (final it in itineraries) {
    for (final code in destinationToCountryCodes(it.destination)) {
      fromProfile.add(code);
    }
  }
  return fromProfile.toList()..sort();
}

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Profile? _profile;
  List<Itinerary> _myItineraries = [];
  List<UserPastCity> _pastCities = [];
  List<UserTopSpot> _currentCitySpots = [];
  int _tripsCount = 0;
  int _followersCount = 0;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        SupabaseService.getProfile(userId),
        SupabaseService.getUserItineraries(userId, publicOnly: false),
        SupabaseService.getTripsCount(userId),
        SupabaseService.getFollowerCount(userId),
        SupabaseService.getPastCities(userId),
      ]);
      final profile = results[0] as Profile?;
      final currentCity = profile?.currentCity?.trim();
      List<UserTopSpot> currentCitySpots = [];
      if (currentCity != null && currentCity.isNotEmpty) {
        currentCitySpots = await SupabaseService.getTopSpots(userId, currentCity);
      }
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _myItineraries = results[1] as List<Itinerary>;
        _tripsCount = results[2] as int;
        _followersCount = results[3] as int;
        _pastCities = results[4] as List<UserPastCity>;
        _currentCitySpots = currentCitySpots;
        _error = null;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Something went wrong. Pull down to retry.';
        _isLoading = false;
      });
    }
  }

  bool _isUploadingPhoto = false;

  Future<void> _uploadPhoto() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;
    final picker = ImagePicker();
    final xfile = await picker.pickImage(source: ImageSource.gallery, maxWidth: 512, maxHeight: 512, imageQuality: 85);
    if (xfile == null) return;
    setState(() => _isUploadingPhoto = true);
    try {
      final bytes = await xfile.readAsBytes() as Uint8List;
      final path = xfile.path;
      final ext = (path.contains('.') && !path.startsWith('blob:'))
          ? path.split('.').last.toLowerCase()
          : 'jpg';
      final url = await SupabaseService.uploadAvatar(userId, bytes, ext);
      await SupabaseService.updateProfile(userId, {'photo_url': url});
      await _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not upload photo. Please try again.')));
    } finally {
      if (mounted) setState(() => _isUploadingPhoto = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    Analytics.logScreenView('profile');
    if (_isLoading && _profile == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Profile')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(width: 40, height: 40, child: CircularProgressIndicator(strokeWidth: 2, color: Theme.of(context).colorScheme.primary)),
              const SizedBox(height: AppTheme.spacingLg),
              Text('Loading profile…', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
            ],
          ),
        ),
      );
    }
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Profile')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.spacingLg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.person_off_outlined, size: 64, color: Theme.of(context).colorScheme.outline),
                const SizedBox(height: AppTheme.spacingLg),
                Text(_error!, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyLarge),
                const SizedBox(height: AppTheme.spacingLg),
                FilledButton.icon(onPressed: _load, icon: const Icon(Icons.refresh, size: 20), label: const Text('Retry')),
              ],
            ),
          ),
        ),
      );
    }
    final p = _profile!;
    final visitedCountries = _mergedVisitedCountries(p, _myItineraries);
    return Scaffold(
      appBar: AppBar(title: const Text('Profile'), actions: [IconButton(icon: const Icon(Icons.logout), onPressed: () => _signOut())]),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(AppTheme.spacingMd),
          children: [
            Center(
              child: GestureDetector(
                onTap: _isUploadingPhoto ? null : _uploadPhoto,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: CircleAvatar(
                        radius: 52,
                        backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                        child: CircleAvatar(
                          radius: 50,
                          backgroundImage: p.photoUrl != null ? NetworkImage(p.photoUrl!) : null,
                          child: p.photoUrl == null ? Icon(Icons.person_outline, size: 48, color: Theme.of(context).colorScheme.onSurfaceVariant) : null,
                        ),
                      ),
                    ),
                    if (_isUploadingPhoto)
                      Container(
                        width: 104,
                        height: 104,
                        decoration: BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                        child: Center(child: SizedBox(width: 32, height: 32, child: CircularProgressIndicator(color: Theme.of(context).colorScheme.surface, strokeWidth: 3))),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: _StatCard(
                    icon: Icons.public_outlined,
                    value: '${visitedCountries.length}',
                    label: 'Countries',
                    color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.5),
                    iconColor: Theme.of(context).colorScheme.primary,
                    onTap: () async {
                      await context.push('/map/countries?codes=${visitedCountries.join(',')}');
                      if (mounted) _load();
                    },
                  ),
                ),
                const SizedBox(width: AppTheme.spacingSm),
                Expanded(
                  child: _StatCard(
                    icon: Icons.route_outlined,
                    value: '$_tripsCount',
                    label: 'Trips',
                    color: Theme.of(context).colorScheme.secondaryContainer.withValues(alpha: 0.5),
                    iconColor: Theme.of(context).colorScheme.secondary,
                    onTap: () => context.push('/profile/trips'),
                  ),
                ),
                const SizedBox(width: AppTheme.spacingSm),
                Expanded(
                  child: _StatCard(
                    icon: Icons.people_outline,
                    value: '$_followersCount',
                    label: 'Followers',
                    color: Theme.of(context).colorScheme.tertiaryContainer.withValues(alpha: 0.5),
                    iconColor: Theme.of(context).colorScheme.tertiary,
                    onTap: () => context.push('/profile/followers'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
          _CurrentCitySection(
            currentCity: p.currentCity,
            spots: _currentCitySpots,
            onEdit: () => _editCurrentCity(p),
            onTapCity: p.currentCity != null && p.currentCity!.trim().isNotEmpty
                ? () => context.push('/city/${Uri.encodeComponent(p.currentCity!.trim())}?userId=${p.id}')
                : null,
          ),
          const SizedBox(height: AppTheme.spacingLg),
          _PastCitiesSection(
            pastCities: _pastCities,
            onEdit: () => _editPastCities(p),
            onTapCity: (city) => context.push('/city/${Uri.encodeComponent(city)}?userId=${p.id}'),
          ),
          const SizedBox(height: AppTheme.spacingLg),
          _Section(title: 'Name', count: null, onEdit: () => _editName(p)),
          Text(p.name?.isNotEmpty == true ? p.name! : 'Not set', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppTheme.spacingLg),
          _Section(title: 'Travel styles', count: p.travelStyles.length, onEdit: () => _editTravelStyles(p)),
          if (p.travelStyles.isNotEmpty) ...[
            const SizedBox(height: AppTheme.spacingSm),
            Wrap(spacing: AppTheme.spacingSm, runSpacing: AppTheme.spacingSm, children: p.travelStyles.map((s) => Chip(label: Text(s))).toList()),
          ],
          const SizedBox(height: AppTheme.spacingSm),
          Text('Mode: ${p.travelMode ?? "Not set"}', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }

  Future<void> _signOut() async {
    try {
      await Supabase.instance.client.auth.signOut();
      if (mounted) context.go('/');
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not sign out. Please try again.')));
    }
  }

  void _editName(Profile p) => _showNameEditor(p.name ?? '', (name) => _updateProfile(name: name));
  void _editCurrentCity(Profile p) => _showCurrentCityEditor(p.currentCity ?? '', (city) => _updateProfile(currentCity: city));
  void _editPastCities(Profile p) => _showPastCitiesEditor(_pastCities, () => _load());
  void _editTravelStyles(Profile p) => _showStylesEditor(p.travelStyles, (list) => _updateProfile(travelStyles: list));

  Future<void> _showNameEditor(String initial, void Function(String) onSave) async {
    final controller = TextEditingController(text: initial);
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacingLg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Edit name', style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: AppTheme.spacingLg),
              TextField(
                controller: controller,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  hintText: 'Enter your name',
                  prefixIcon: Icon(Icons.person_outline),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                  const Spacer(),
                  FilledButton(
                    onPressed: () {
                      final name = controller.text.trim();
                      if (name.isEmpty) {
                        ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Please enter your name')));
                      } else {
                        onSave(name);
                        Navigator.pop(ctx);
                        _load();
                      }
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

  Future<void> _updateProfile({String? name, String? currentCity, List<String>? visitedCountries, List<String>? travelStyles}) async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;
    final data = <String, dynamic>{};
    if (name != null) data['name'] = name;
    if (currentCity != null) data['current_city'] = currentCity.trim().isEmpty ? null : currentCity.trim();
    if (visitedCountries != null) data['visited_countries'] = visitedCountries;
    if (travelStyles != null) data['travel_styles'] = travelStyles!.map((s) => s.toLowerCase()).toList();
    await SupabaseService.updateProfile(userId, data);
    await _load();
  }

  Future<void> _showCurrentCityEditor(String initial, void Function(String) onSave) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacingLg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Current City', style: Theme.of(context).textTheme.headlineSmall),
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
                  child: Text('Current: $initial', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                ),
              const SizedBox(height: 16),
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ],
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
                  Text('Past Cities', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  Text('Cities you previously lived in', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
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
                                builder: (dctx) => Padding(
                                  padding: const EdgeInsets.all(AppTheme.spacingLg),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                      Text('Add past city', style: Theme.of(dctx).textTheme.titleLarge),
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
}

class _CurrentCitySection extends StatelessWidget {
  final String? currentCity;
  final List<UserTopSpot> spots;
  final VoidCallback onEdit;
  final VoidCallback? onTapCity;

  const _CurrentCitySection({
    required this.currentCity,
    required this.spots,
    required this.onEdit,
    this.onTapCity,
  });

  @override
  Widget build(BuildContext context) {
    final hasCity = currentCity != null && currentCity!.trim().isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Current City', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
            const Spacer(),
            TextButton.icon(onPressed: onEdit, icon: const Icon(Icons.edit_outlined, size: 18), label: const Text('Edit')),
          ],
        ),
        const SizedBox(height: AppTheme.spacingSm),
        if (!hasCity)
          Text('Not set', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant))
        else ...[
          InkWell(
            onTap: onTapCity,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Icon(Icons.location_city, size: 22, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 8),
                  Text(currentCity!, style: Theme.of(context).textTheme.titleMedium),
                  if (onTapCity != null) Icon(Icons.chevron_right, size: 20, color: Theme.of(context).colorScheme.onSurfaceVariant),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppTheme.spacingSm),
          Text('Top spots in $currentCity', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: AppTheme.spacingXs),
          if (spots.isEmpty)
            Text('No spots yet', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant))
          else
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: spots.take(10).map((s) => Chip(
                label: Text('${topSpotCategoryLabels[s.category] ?? s.category}: ${s.name}'),
                labelStyle: Theme.of(context).textTheme.bodySmall,
              )).toList(),
            ),
          if (spots.length > 10) Padding(padding: const EdgeInsets.only(top: 4), child: Text('+${spots.length - 10} more', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant))),
        ],
      ],
    );
  }
}

class _PastCitiesSection extends StatelessWidget {
  final List<UserPastCity> pastCities;
  final VoidCallback onEdit;
  final void Function(String) onTapCity;

  const _PastCitiesSection({
    required this.pastCities,
    required this.onEdit,
    required this.onTapCity,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Past Cities', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
            if (pastCities.isNotEmpty) Text(' (${pastCities.length})', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
            const Spacer(),
            TextButton.icon(onPressed: onEdit, icon: const Icon(Icons.edit_outlined, size: 18), label: const Text('Edit')),
          ],
        ),
        const SizedBox(height: AppTheme.spacingSm),
        if (pastCities.isEmpty)
          Text('None', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant))
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: pastCities.map((c) => ActionChip(
              avatar: Icon(Icons.location_city_outlined, size: 18, color: Theme.of(context).colorScheme.primary),
              label: Text(c.cityName),
              onPressed: () => onTapCity(c.cityName),
            )).toList(),
          ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;
  final Color iconColor;
  final VoidCallback? onTap;

  const _StatCard({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
    required this.iconColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final child = Container(
      padding: const EdgeInsets.all(AppTheme.spacingMd),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Theme.of(context).colorScheme.shadow.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 26, color: iconColor),
          const SizedBox(height: AppTheme.spacingSm),
          Text(value, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface)),
          const SizedBox(height: 2),
          Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
        ],
      ),
    );
    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: child,
      );
    }
    return child;
  }
}

class _Section extends StatelessWidget {
  final String title;
  final int? count;
  final VoidCallback? onEdit;

  const _Section({required this.title, this.count, this.onEdit});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
        if (count != null) Text(' ($count)', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
        const Spacer(),
        if (onEdit != null) TextButton.icon(onPressed: onEdit, icon: const Icon(Icons.edit_outlined, size: 18), label: const Text('Edit')),
      ],
    );
  }
}
