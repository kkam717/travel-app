import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/theme.dart';
import '../models/itinerary.dart';
import '../models/profile.dart';
import '../models/user_city.dart';
import '../services/supabase_service.dart';

class AuthorProfileScreen extends StatefulWidget {
  final String authorId;

  const AuthorProfileScreen({super.key, required this.authorId});

  @override
  State<AuthorProfileScreen> createState() => _AuthorProfileScreenState();
}

class _AuthorProfileScreenState extends State<AuthorProfileScreen> {
  Profile? _profile;
  List<Itinerary> _itineraries = [];
  List<UserPastCity> _pastCities = [];
  List<UserTopSpot> _currentCitySpots = [];
  int _followersCount = 0;
  int _followingCount = 0;
  bool _isLoading = true;
  String? _error;
  bool _isFollowing = false;

  bool get _isOwnProfile => Supabase.instance.client.auth.currentUser?.id == widget.authorId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      final isMutual = userId != null && !_isOwnProfile ? SupabaseService.isMutualFriend(userId, widget.authorId) : Future.value(false);
      final results = await Future.wait([
        SupabaseService.getProfile(widget.authorId),
        SupabaseService.getFollowerCount(widget.authorId),
        SupabaseService.getFollowingCount(widget.authorId),
        userId != null && !_isOwnProfile ? SupabaseService.isFollowing(userId, widget.authorId) : Future.value(false),
        isMutual,
      ]);
      final profile = results[0] as Profile?;
      final followersCount = results[1] as int;
      final followingCount = results[2] as int;
      final isFollowing = results[3] as bool;
      final mutualFriend = results[4] as bool;
      final itineraries = await SupabaseService.getUserItineraries(widget.authorId, publicOnly: !_isOwnProfile && !mutualFriend);
      final pastCities = await SupabaseService.getPastCities(widget.authorId);
      List<UserTopSpot> currentCitySpots = [];
      final currentCity = profile?.currentCity?.trim();
      if (currentCity != null && currentCity.isNotEmpty) {
        currentCitySpots = await SupabaseService.getTopSpots(widget.authorId, currentCity);
      }
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _itineraries = itineraries;
        _pastCities = pastCities;
        _currentCitySpots = currentCitySpots;
        _followersCount = followersCount;
        _followingCount = followingCount;
        _isFollowing = isFollowing;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Something went wrong. Please try again.';
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleFollow() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null || _isOwnProfile) return;
    if (!mounted) return;
    setState(() => _isFollowing = !_isFollowing);
    try {
      if (_isFollowing) {
        await SupabaseService.followUser(userId, widget.authorId);
      } else {
        await SupabaseService.unfollowUser(userId, widget.authorId);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isFollowing = !_isFollowing);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not update follow status. Please try again.')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_profile?.name ?? 'Profile'),
        actions: [
          if (!_isOwnProfile && !_isLoading)
            Padding(
              padding: const EdgeInsets.only(right: AppTheme.spacingSm),
              child: FilledButton.icon(
                onPressed: _toggleFollow,
                icon: Icon(_isFollowing ? Icons.check : Icons.person_add, size: 18),
                label: Text(_isFollowing ? 'Following' : 'Follow'),
              ),
            ),
        ],
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(width: 40, height: 40, child: CircularProgressIndicator(strokeWidth: 2, color: Theme.of(context).colorScheme.primary)),
                  const SizedBox(height: AppTheme.spacingLg),
                  Text('Loading profile…', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
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
                        Icon(Icons.person_off_outlined, size: 64, color: Theme.of(context).colorScheme.outline),
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
                  child: CustomScrollView(
                    slivers: [
                      SliverToBoxAdapter(
                        child: _buildProfileHeader(),
                      ),
                      SliverToBoxAdapter(
                        child: _buildCurrentCitySection(),
                      ),
                      SliverToBoxAdapter(
                        child: _buildPastCitiesSection(),
                      ),
                      if (_itineraries.isEmpty)
                        SliverFillRemaining(
                          child: Center(
                            child: Padding(
                              padding: const EdgeInsets.all(AppTheme.spacingLg),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.route_outlined, size: 64, color: Theme.of(context).colorScheme.outline),
                                  const SizedBox(height: AppTheme.spacingLg),
                                  Text('No itineraries', style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                                ],
                              ),
                            ),
                          ),
                        )
                      else
                        SliverPadding(
                          padding: const EdgeInsets.all(AppTheme.spacingMd),
                          sliver: SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (_, i) {
                                final it = _itineraries[i];
                                return Card(
                                  margin: const EdgeInsets.only(bottom: AppTheme.spacingMd),
                                  child: ListTile(
                                    leading: CircleAvatar(
                                      backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                                      child: Icon(Icons.route_outlined, color: Theme.of(context).colorScheme.onPrimaryContainer),
                                    ),
                                    title: Text(it.title, style: Theme.of(context).textTheme.titleSmall),
                                    subtitle: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('${it.destination} • ${it.daysCount} days', style: Theme.of(context).textTheme.bodySmall),
                                        if (it.stopsCount != null && it.stopsCount! > 0)
                                          Text('${it.stopsCount} stops', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                                      ],
                                    ),
                                    trailing: Icon(Icons.chevron_right, color: Theme.of(context).colorScheme.onSurfaceVariant),
                                    onTap: () => context.push('/itinerary/${it.id}'),
                                  ),
                                );
                              },
                              childCount: _itineraries.length,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildProfileHeader() {
    final p = _profile;
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingLg),
      child: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2), blurRadius: 16, offset: const Offset(0, 4))],
            ),
            child: CircleAvatar(
              radius: 52,
              backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: CircleAvatar(
                radius: 50,
                backgroundImage: p?.photoUrl != null ? NetworkImage(p!.photoUrl!) : null,
                child: p?.photoUrl == null ? Icon(Icons.person_outline, size: 48, color: Theme.of(context).colorScheme.onSurfaceVariant) : null,
              ),
            ),
          ),
          const SizedBox(height: AppTheme.spacingMd),
          Text(
            p?.name ?? 'Unknown',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppTheme.spacingLg),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingLg, vertical: AppTheme.spacingMd),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _StatChip(label: 'Trips', value: '${_itineraries.length}'),
                Container(width: 1, height: 32, color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3)),
                _StatChip(label: 'Followers', value: '$_followersCount'),
                Container(width: 1, height: 32, color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3)),
                _StatChip(label: 'Following', value: '$_followingCount'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentCitySection() {
    final p = _profile;
    final currentCity = p?.currentCity?.trim();
    final hasCity = currentCity != null && currentCity.isNotEmpty;
    if (!hasCity) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppTheme.spacingMd, 0, AppTheme.spacingMd, AppTheme.spacingMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Current City', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: AppTheme.spacingSm),
          InkWell(
            onTap: () => context.push('/city/${Uri.encodeComponent(currentCity)}?userId=${widget.authorId}'),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Icon(Icons.location_city, size: 22, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 8),
                  Text(currentCity, style: Theme.of(context).textTheme.titleMedium),
                  Icon(Icons.chevron_right, size: 20, color: Theme.of(context).colorScheme.onSurfaceVariant),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppTheme.spacingSm),
          Text('Top spots in $currentCity', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: AppTheme.spacingXs),
          if (_currentCitySpots.isEmpty)
            Text('No spots', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant))
          else
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: _currentCitySpots.take(10).map((s) => Chip(
                label: Text('${topSpotCategoryLabels[s.category] ?? s.category}: ${s.name}'),
                labelStyle: Theme.of(context).textTheme.bodySmall,
              )).toList(),
            ),
          if (_currentCitySpots.length > 10)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: GestureDetector(
                onTap: () => context.push('/city/${Uri.encodeComponent(currentCity)}?userId=${widget.authorId}'),
                child: Text('View all →', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.primary)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPastCitiesSection() {
    if (_pastCities.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppTheme.spacingMd, 0, AppTheme.spacingMd, AppTheme.spacingMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Past Cities', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: AppTheme.spacingSm),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _pastCities.map((c) => ActionChip(
              avatar: Icon(Icons.location_city_outlined, size: 18, color: Theme.of(context).colorScheme.primary),
              label: Text(c.cityName),
              onPressed: () => context.push('/city/${Uri.encodeComponent(c.cityName)}?userId=${widget.authorId}'),
            )).toList(),
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;

  const _StatChip({required this.label, required this.value});

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
