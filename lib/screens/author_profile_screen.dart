import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/theme.dart';
import '../data/countries.dart';
import '../models/itinerary.dart';
import '../models/profile.dart';
import '../models/user_city.dart';
import '../services/supabase_service.dart';
import '../widgets/itinerary_feed_card.dart';

List<String> _mergedVisitedCountries(Profile? profile, List<Itinerary> itineraries) {
  final fromProfile = (profile?.visitedCountries ?? []).toSet();
  for (final it in itineraries) {
    for (final code in destinationToCountryCodes(it.destination)) {
      fromProfile.add(code);
    }
  }
  return fromProfile.toList()..sort();
}

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
  int _followersCount = 0;
  int _followingCount = 0;
  bool _isLoading = true;
  String? _error;
  bool _isFollowing = false;
  bool _isMutualFriend = false;

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
        SupabaseService.getPastCities(widget.authorId),
        SupabaseService.getFollowerCount(widget.authorId),
        SupabaseService.getFollowingCount(widget.authorId),
        userId != null && !_isOwnProfile ? SupabaseService.isFollowing(userId, widget.authorId) : Future.value(false),
        isMutual,
      ]);
      final profile = results[0] as Profile?;
      final pastCities = results[1] as List<UserPastCity>;
      final followersCount = results[2] as int;
      final followingCount = results[3] as int;
      final isFollowing = results[4] as bool;
      final mutualFriend = results[5] as bool;
      final itineraries = await SupabaseService.getUserItineraries(widget.authorId, publicOnly: !_isOwnProfile && !mutualFriend);
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _pastCities = pastCities;
        _itineraries = itineraries;
        _followersCount = followersCount;
        _followingCount = followingCount;
        _isFollowing = isFollowing;
        _isMutualFriend = mutualFriend;
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
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/home');
            }
          },
        ),
        title: Text(
          _profile?.name ?? 'Profile',
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
        ),
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
                      SliverToBoxAdapter(child: _buildProfileHeaderContent()),
                      _buildTripsSliver(),
                    ],
                  ),
                ),
    );
  }

  Widget _buildProfileHeaderContent() {
    final p = _profile;
    final currentCity = p?.currentCity?.trim();
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
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
                      backgroundImage: p?.photoUrl != null ? NetworkImage(p!.photoUrl!) : null,
                      child: p?.photoUrl == null ? Icon(Icons.person_outline, size: 36, color: Theme.of(context).colorScheme.onSurfaceVariant) : null,
                    ),
                  ),
                ),
                const SizedBox(width: AppTheme.spacingMd),
                Expanded(
                  child: hasCity
                      ? InkWell(
                          onTap: () => context.push('/city/${Uri.encodeComponent(currentCity!)}?userId=${widget.authorId}'),
                          borderRadius: BorderRadius.circular(12),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Row(
                              children: [
                                Icon(Icons.location_city, size: 22, color: Theme.of(context).colorScheme.primary),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    currentCity!,
                                    style: Theme.of(context).textTheme.titleMedium,
                                  ),
                                ),
                                Icon(Icons.chevron_right, size: 24, color: Theme.of(context).colorScheme.onSurfaceVariant),
                              ],
                            ),
                          ),
                        )
                      : Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Row(
                            children: [
                              Icon(Icons.location_city, size: 22, color: Theme.of(context).colorScheme.onSurfaceVariant),
                              const SizedBox(width: 8),
                              Text(
                                'Not set',
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                              ),
                            ],
                          ),
                        ),
                ),
                  ],
                ),
                if (!_isOwnProfile) ...[
                  const SizedBox(height: AppTheme.spacingMd),
                  SizedBox(
                    width: double.infinity,
                    child: _isFollowing
                        ? OutlinedButton.icon(
                            onPressed: _toggleFollow,
                            icon: const Icon(Icons.person, size: 20),
                            label: const Text('Following'),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              minimumSize: const Size(double.infinity, 40),
                            ),
                          )
                        : FilledButton.icon(
                            onPressed: _toggleFollow,
                            icon: const Icon(Icons.person_add, size: 20),
                            label: const Text('Follow'),
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              minimumSize: const Size(double.infinity, 40),
                            ),
                          ),
                  ),
                ],
              ],
            ),
          ),
          if (_isMutualFriend)
            Padding(
              padding: const EdgeInsets.only(top: AppTheme.spacingSm),
              child: Text(
                'You follow each other',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          const SizedBox(height: AppTheme.spacingLg),
          Row(
            children: [
              Expanded(
                child: _AuthorStatCard(
                  icon: Icons.public_outlined,
                  value: '${_mergedVisitedCountries(_profile, _itineraries).length}',
                  label: 'Countries',
                  color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.5),
                  iconColor: Theme.of(context).colorScheme.primary,
                  onTap: () {
                    final codes = _mergedVisitedCountries(_profile, _itineraries);
                    context.push('/map/countries?codes=${codes.join(',')}');
                  },
                ),
              ),
              const SizedBox(width: AppTheme.spacingSm),
              Expanded(
                child: _AuthorStatCard(
                  icon: Icons.location_city_outlined,
                  value: '${(hasCity ? 1 : 0) + _pastCities.length}',
                  label: 'Lived',
                  color: Theme.of(context).colorScheme.secondaryContainer.withValues(alpha: 0.5),
                  iconColor: Theme.of(context).colorScheme.secondary,
                  onTap: () => context.push('/profile/stats?userId=${widget.authorId}'),
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
                    onTap: () => context.push('/profile/followers?userId=${widget.authorId}'),
                    borderRadius: BorderRadius.circular(8),
                    child: _StatChip(label: 'Followers', value: '$_followersCount'),
                  ),
                ),
                Container(width: 1, height: 32, color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3)),
                Expanded(
                  child: InkWell(
                    onTap: () => context.push('/profile/following?userId=${widget.authorId}'),
                    borderRadius: BorderRadius.circular(8),
                    child: _StatChip(label: 'Following', value: '$_followingCount'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppTheme.spacingLg),
          Row(
            children: [
              Text('Trips', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
              if (_itineraries.isNotEmpty)
                Text(' (${_itineraries.length})', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
            ],
          ),
          const SizedBox(height: AppTheme.spacingSm),
        ],
      ),
    );
  }

  Widget _buildTripsSliver() {
    if (_itineraries.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.only(top: 8),
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
          final it = _itineraries[i];
          return RepaintBoundary(
            child: ItineraryFeedCard(
              itinerary: it,
              description: _descriptionFor(it),
              locations: _locationsFor(it),
              onTap: () => context.push('/itinerary/${it.id}'),
              onAuthorTap: null,
            ),
          );
        },
        childCount: _itineraries.length,
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

class _AuthorStatCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;
  final Color iconColor;
  final VoidCallback? onTap;

  const _AuthorStatCard({
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
