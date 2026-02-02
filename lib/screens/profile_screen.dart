import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import '../core/theme.dart';
import '../core/analytics.dart';
import '../core/profile_cache.dart';
import '../core/profile_refresh_notifier.dart';
import '../models/profile.dart';
import '../models/itinerary.dart';
import '../models/user_city.dart';
import '../data/countries.dart';
import '../widgets/itinerary_feed_card.dart';
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
  int _followersCount = 0;
  int _followingCount = 0;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initOrLoad();
    ProfileRefreshNotifier.addListener(_onRefreshRequested);
  }

  @override
  void dispose() {
    ProfileRefreshNotifier.removeListener(_onRefreshRequested);
    super.dispose();
  }

  void _onRefreshRequested() {
    if (mounted) _load(silent: true);
  }

  void _initOrLoad() {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;
    if (ProfileCache.hasData(userId)) {
      final cached = ProfileCache.get(userId);
      if (mounted) {
        setState(() {
          _profile = cached.profile;
          _myItineraries = cached.myItineraries;
          _pastCities = cached.pastCities;
          _followersCount = cached.followersCount;
          _followingCount = cached.followingCount;
          _isLoading = false;
          _error = null;
        });
      }
      _load(silent: true);
    } else {
      _load(silent: false);
    }
  }

  Future<void> _load({bool silent = false}) async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;
    if (!mounted) return;
    if (!silent) {
      setState(() => _isLoading = true);
    }
    try {
      final results = await Future.wait([
        SupabaseService.getProfile(userId),
        SupabaseService.getUserItineraries(userId, publicOnly: false),
        SupabaseService.getPastCities(userId),
        SupabaseService.getFollowerCount(userId),
        SupabaseService.getFollowingCount(userId),
      ]);
      final profile = results[0] as Profile?;
      final myItineraries = results[1] as List<Itinerary>;
      final pastCities = results[2] as List<UserPastCity>;
      final followersCount = results[3] as int;
      final followingCount = results[4] as int;
      if (!mounted) return;
      ProfileCache.put(
        userId,
        profile: profile,
        myItineraries: myItineraries,
        pastCities: pastCities,
        followersCount: followersCount,
        followingCount: followingCount,
      );
      setState(() {
        _profile = profile;
        _myItineraries = myItineraries;
        _pastCities = pastCities;
        _followersCount = followersCount;
        _followingCount = followingCount;
        _error = null;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      if (silent) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not refresh. Pull down to retry.')),
          );
        }
        return;
      }
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
      final bytes = await xfile.readAsBytes();
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
        appBar: AppBar(title: Text(_profile?.name ?? 'Profile')),
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
        appBar: AppBar(title: Text(_profile?.name ?? 'Profile')),
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
    final userId = Supabase.instance.client.auth.currentUser?.id ?? p.id;
    return Scaffold(
      appBar: AppBar(
        title: Text(p.name ?? 'Profile'),
        actions: [
          IconButton(icon: const Icon(Icons.edit_outlined), onPressed: () => _showEditProfileSheet(p)),
          IconButton(icon: const Icon(Icons.settings_outlined), onPressed: () => context.push('/profile/settings')),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => _load(silent: true),
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _buildProfileHeaderContent(p, userId)),
            _buildTripsSliver(userId),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeaderContent(Profile p, String userId) {
    final visitedCountries = _mergedVisitedCountries(p, _myItineraries);
    final currentCity = p.currentCity?.trim();
    final hasCity = currentCity != null && currentCity.isNotEmpty;
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingLg),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(AppTheme.spacingMd),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: Theme.of(context).colorScheme.shadow.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
            ),
            child: Row(
              children: [
                GestureDetector(
                  onTap: _isUploadingPhoto ? null : _uploadPhoto,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [BoxShadow(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2), blurRadius: 8, offset: const Offset(0, 2))],
                        ),
                        child: CircleAvatar(
                          radius: 36,
                          backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                          child: CircleAvatar(
                            radius: 34,
                            backgroundImage: p.photoUrl != null ? NetworkImage(p.photoUrl!) : null,
                            child: p.photoUrl == null ? Icon(Icons.person_outline, size: 36, color: Theme.of(context).colorScheme.onSurfaceVariant) : null,
                          ),
                        ),
                      ),
                      if (_isUploadingPhoto)
                        Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                          child: Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Theme.of(context).colorScheme.surface, strokeWidth: 3))),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: AppTheme.spacingMd),
                Expanded(
                  child: hasCity
                      ? InkWell(
                          onTap: () => context.push('/city/${Uri.encodeComponent(currentCity)}?userId=$userId'),
                          borderRadius: BorderRadius.circular(12),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Row(
                              children: [
                                Icon(Icons.location_city, size: 22, color: Theme.of(context).colorScheme.primary),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    currentCity,
                                    style: Theme.of(context).textTheme.titleMedium,
                                  ),
                                ),
                                Icon(Icons.chevron_right, size: 24, color: Theme.of(context).colorScheme.onSurfaceVariant),
                              ],
                            ),
                          ),
                        )
                      : InkWell(
                          onTap: () async {
                            await context.push('/profile/stats?open=current_city');
                            if (mounted) _load();
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Row(
                              children: [
                                Icon(Icons.location_city, size: 22, color: Theme.of(context).colorScheme.onSurfaceVariant),
                                const SizedBox(width: 8),
                                Text(
                                  'Not set',
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                                ),
                                Icon(Icons.chevron_right, size: 24, color: Theme.of(context).colorScheme.onSurfaceVariant),
                              ],
                            ),
                          ),
                        ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppTheme.spacingLg),
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  icon: Icons.public_outlined,
                  value: '${visitedCountries.length}',
                  label: 'Countries',
                  color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.5),
                  iconColor: Theme.of(context).colorScheme.primary,
                  showBadge: visitedCountries.isEmpty,
                  onTap: () async {
                    await context.push('/map/countries?codes=${visitedCountries.join(',')}&editable=1');
                    if (mounted) _load();
                  },
                ),
              ),
              const SizedBox(width: AppTheme.spacingSm),
              Expanded(
                child: _StatCard(
                  icon: Icons.location_city_outlined,
                  value: '${(hasCity ? 1 : 0) + _pastCities.length}',
                  label: 'Lived',
                  color: Theme.of(context).colorScheme.secondaryContainer.withValues(alpha: 0.5),
                  iconColor: Theme.of(context).colorScheme.secondary,
                  onTap: () async {
                    final livedCount = (hasCity ? 1 : 0) + _pastCities.length;
                    final open = livedCount == 0 ? 'current_city' : null;
                    await context.push(open != null ? '/profile/stats?open=$open' : '/profile/stats');
                    if (mounted) _load();
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacingMd),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingLg, vertical: AppTheme.spacingMd),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () async {
                      await context.push('/profile/followers');
                      if (mounted) _load();
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: _ProfileStatChip(label: 'Followers', value: '$_followersCount'),
                  ),
                ),
                Container(width: 1, height: 32, color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3)),
                Expanded(
                  child: InkWell(
                    onTap: () async {
                      await context.push('/profile/following');
                      if (mounted) _load();
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: _ProfileStatChip(label: 'Following', value: '$_followingCount'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppTheme.spacingLg),
          Row(
            children: [
              Text('Trips', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
              if (_myItineraries.isNotEmpty)
                Text(' (${_myItineraries.length})', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
            ],
          ),
          const SizedBox(height: AppTheme.spacingSm),
        ],
      ),
    );
  }

  Widget _buildTripsSliver(String userId) {
    if (_myItineraries.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.only(top: 8, left: AppTheme.spacingLg, right: AppTheme.spacingLg),
          child: Text(
            'No trips yet',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
        ),
      );
    }
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (_, i) {
          final it = _myItineraries[i];
          return RepaintBoundary(
            child: ItineraryFeedCard(
              itinerary: it,
              description: _descriptionFor(it),
              locations: _locationsFor(it),
              onTap: () => context.push('/itinerary/${it.id}'),
              onEdit: () => context.push('/itinerary/${it.id}/edit'),
            ),
          );
        },
        childCount: _myItineraries.length,
        addRepaintBoundaries: true,
      ),
    );
  }

  String _descriptionFor(Itinerary it) {
    if (it.styleTags.isNotEmpty) {
      return '${it.destination} • ${it.styleTags.take(2).join(', ').toLowerCase()}';
    }
    return it.destination;
  }

  String _locationsFor(Itinerary it) {
    if (it.stops.isEmpty) return it.destination;
    final venues = it.stops.where((s) => s.isVenue).toList();
    final toShow = venues.isNotEmpty ? venues : it.stops.where((s) => s.isLocation).toList();
    if (toShow.isEmpty) return it.destination;
    return toShow.take(2).map((s) => s.name).join(' • ');
  }

  Future<void> _showEditProfileSheet(Profile p) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.35,
        expand: false,
        builder: (_, scrollController) => ListView(
          controller: scrollController,
          padding: const EdgeInsets.all(AppTheme.spacingLg),
          children: [
            Text('Edit Profile', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: AppTheme.spacingLg),
            ListTile(
              leading: const Icon(Icons.person_outline),
              title: const Text('Name'),
              subtitle: Text(p.name?.isNotEmpty == true ? p.name! : 'Not set'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () async {
                Navigator.pop(ctx);
                await _showNameEditor(p.name ?? '', (name) => _updateProfile(name: name));
              },
            ),
            ListTile(
              leading: const Icon(Icons.location_city_outlined),
              title: const Text('Lived'),
              subtitle: const Text('Home town, lived before, travel styles'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () async {
                Navigator.pop(ctx);
                final hasCity = p.currentCity?.trim().isNotEmpty == true;
                final hasPast = _pastCities.isNotEmpty;
                final hasStyles = (p.travelStyles).isNotEmpty;
                String? open;
                if (!hasCity) open = 'current_city';
                else if (!hasPast) open = 'past_cities';
                else if (!hasStyles) open = 'travel_styles';
                await context.push(open != null ? '/profile/stats?open=$open' : '/profile/stats');
                if (mounted) _load();
              },
            ),
          ],
        ),
      ),
    );
  }

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

  Future<void> _updateProfile({String? name, List<String>? visitedCountries}) async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;
    final data = <String, dynamic>{};
    if (name != null) data['name'] = name;
    if (visitedCountries != null) data['visited_countries'] = visitedCountries;
    await SupabaseService.updateProfile(userId, data);
    await _load();
  }

}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;
  final Color iconColor;
  final bool showBadge;
  final VoidCallback? onTap;

  const _StatCard({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
    required this.iconColor,
    this.showBadge = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 26, color: iconColor),
        const SizedBox(height: AppTheme.spacingSm),
        Text(value, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface)),
        const SizedBox(height: 2),
        Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
      ],
    );
    final child = Container(
      padding: const EdgeInsets.all(AppTheme.spacingMd),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Theme.of(context).colorScheme.shadow.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: showBadge
          ? Stack(
              clipBehavior: Clip.none,
              children: [
                content,
                Positioned(
                  top: 0,
                  right: 0,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                      border: Border.all(color: Theme.of(context).colorScheme.surface, width: 1.5),
                    ),
                  ),
                ),
              ],
            )
          : content,
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

class _ProfileStatChip extends StatelessWidget {
  final String label;
  final String value;

  const _ProfileStatChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.onSurface)),
        const SizedBox(height: 2),
        Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
      ],
    );
  }
}

