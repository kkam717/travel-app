import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/theme.dart';
import '../core/analytics.dart';
import '../models/itinerary.dart';
import '../models/profile.dart';
import '../services/supabase_service.dart';
import '../data/countries.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _searchController = TextEditingController();
  List<ProfileSearchResult> _profileResults = [];
  List<Itinerary> _placeResults = [];
  Set<String> _followedProfileIds = {};
  bool _isLoading = false;
  String? _error;
  int? _filterDays;
  List<String> _filterStyles = [];
  String? _filterMode;
  Timer? _placesSearchDebounce;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_onTabChanged);
    _search();
  }

  @override
  void dispose() {
    _placesSearchDebounce?.cancel();
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _debouncedPlacesSearch() {
    _placesSearchDebounce?.cancel();
    _placesSearchDebounce = Timer(const Duration(milliseconds: 400), _search);
  }

  void _onTabChanged() {
    if (_tabController.indexIsChanging) return;
    _search();
  }

  Future<void> _toggleFollow(String profileId) async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;
    final wasFollowing = _followedProfileIds.contains(profileId);
    if (!mounted) return;
    setState(() {
      final next = {..._followedProfileIds};
      if (wasFollowing) next.remove(profileId); else next.add(profileId);
      _followedProfileIds = next;
    });
    try {
      if (wasFollowing) {
        await SupabaseService.unfollowUser(userId, profileId);
      } else {
        await SupabaseService.followUser(userId, profileId);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          final next = {..._followedProfileIds};
          if (wasFollowing) next.add(profileId); else next.remove(profileId);
          _followedProfileIds = next;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not update follow status. Please try again.')),
        );
      }
    }
  }

  Future<void> _search() async {
    if (!mounted) return;
    final query = _searchController.text.trim();
    setState(() {
      _isLoading = true;
      _error = null;
    });
    if (query.isEmpty) {
      if (!mounted) return;
      setState(() {
        _profileResults = [];
        _placeResults = [];
        _isLoading = false;
      });
      return;
    }
    try {
      if (_tabController.index == 0) {
        final userId = Supabase.instance.client.auth.currentUser?.id;
        final results = await Future.wait([
          SupabaseService.searchProfiles(query, limit: 30),
          userId != null ? SupabaseService.getFollowedIds(userId) : Future.value(<String>[]),
        ]);
        final profiles = results[0] as List<ProfileSearchResult>;
        final followedIds = results[1] as List<String>;
        if (!mounted) return;
        setState(() {
          _profileResults = profiles;
          _followedProfileIds = followedIds.toSet();
          _isLoading = false;
        });
        Analytics.logEvent('profile_search_performed', {'result_count': profiles.length});
      } else {
        final places = await SupabaseService.searchItineraries(
          query: query,
          daysCount: _filterDays,
          styles: _filterStyles.isEmpty ? null : _filterStyles,
          mode: _filterMode,
        );
        if (!mounted) return;
        setState(() {
          _placeResults = places;
          _isLoading = false;
        });
        Analytics.logEvent('place_search_performed', {'result_count': places.length});
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Something went wrong. Please try again.';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    Analytics.logScreenView('search');
    return Scaffold(
      appBar: AppBar(
        title: const Text('Search'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.person_outline_rounded), text: 'Profiles'),
            Tab(icon: Icon(Icons.place_outlined), text: 'Trips'),
          ],
        ),
        actions: [
          if (_tabController.index == 1)
            IconButton(
              icon: const Icon(Icons.tune_rounded),
              onPressed: _showFilters,
            ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(AppTheme.spacingMd),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: _tabController.index == 0 ? 'Search by name...' : 'Destination or keywords...',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.clear_rounded),
                  onPressed: () {
                    _searchController.clear();
                    _search();
                  },
                ),
              ),
              onSubmitted: (_) => _search(),
              onChanged: (_) {
                if (_tabController.index == 0) {
                  _search();
                } else {
                  _debouncedPlacesSearch();
                }
              },
            ),
          ),
          Expanded(
            child: _tabController.index == 0 ? _buildProfilesTab() : _buildPlacesTab(),
          ),
        ],
      ),
    );
  }

  Widget _buildProfilesTab() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return _buildErrorState();
    }
    if (_profileResults.isEmpty) {
      final searchEmpty = _searchController.text.trim().isEmpty;
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.person_search_rounded, size: 64, color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.5)),
            const SizedBox(height: AppTheme.spacingLg),
            Text(
              searchEmpty ? 'Type to search for profiles' : 'No profiles found',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingMd),
      itemCount: _profileResults.length,
      itemBuilder: (_, i) {
        final p = _profileResults[i];
        return _ProfileCard(
          profile: p,
          isFollowing: _followedProfileIds.contains(p.id),
          isOwnProfile: currentUserId == p.id,
          onTap: () => context.push('/author/${p.id}'),
          onFollowTap: currentUserId != null && currentUserId != p.id ? () => _toggleFollow(p.id) : null,
        );
      },
    );
  }

  Widget _buildPlacesTab() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return _buildErrorState();
    }
    if (_placeResults.isEmpty) {
      final searchEmpty = _searchController.text.trim().isEmpty;
      final hasFilters = _filterDays != null || _filterStyles.isNotEmpty || _filterMode != null;
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingXl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.explore_rounded, size: 64, color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.5)),
              const SizedBox(height: AppTheme.spacingLg),
              Text(
                searchEmpty ? 'Type to search for trips' : 'No trips found',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                textAlign: TextAlign.center,
              ),
              if (!searchEmpty) ...[
                const SizedBox(height: AppTheme.spacingSm),
                Text(
                  hasFilters ? 'Try clearing filters or a different search.' : 'Only public itineraries appear.',
                  style: Theme.of(context).textTheme.bodySmall,
                  textAlign: TextAlign.center,
                ),
                if (hasFilters) ...[
                  const SizedBox(height: AppTheme.spacingMd),
                  TextButton.icon(
                    onPressed: () {
                      setState(() {
                        _filterDays = null;
                        _filterStyles = [];
                        _filterMode = null;
                      });
                      _search();
                    },
                    icon: const Icon(Icons.clear_all_rounded, size: 18),
                    label: const Text('Clear filters'),
                  ),
                ],
              ],
            ],
          ),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingMd),
      itemCount: _placeResults.length,
      itemBuilder: (_, i) => _ItineraryCard(
        itinerary: _placeResults[i],
        onTap: () => context.push('/itinerary/${_placeResults[i].id}'),
        onAuthorTap: () => context.push('/author/${_placeResults[i].authorId}'),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingXl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_rounded, size: 64, color: Theme.of(context).colorScheme.onSurfaceVariant),
            const SizedBox(height: AppTheme.spacingLg),
            Text(_error!, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyLarge),
            const SizedBox(height: AppTheme.spacingLg),
            FilledButton(onPressed: _search, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }

  void _showFilters() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        int? days = _filterDays;
        List<String> styles = List.from(_filterStyles);
        String? mode = _filterMode;
        return StatefulBuilder(
          builder: (_, setModal) {
            return Padding(
              padding: const EdgeInsets.all(AppTheme.spacingLg),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Duration', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: AppTheme.spacingSm),
                  Wrap(
                    spacing: 8,
                    children: [7, 10, 14, 21].map((d) {
                      final selected = days == d;
                      return FilterChip(
                        label: Text('$d days'),
                        selected: selected,
                        onSelected: (_) => setModal(() => days = selected ? null : d),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: AppTheme.spacingLg),
                  Text('Travel style', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: AppTheme.spacingSm),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: travelStyles.map((s) {
                      final selected = styles.contains(s);
                      return FilterChip(
                        label: Text(s),
                        selected: selected,
                        onSelected: (_) => setModal(() {
                          if (selected) styles.remove(s);
                          else styles.add(s);
                        }),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: AppTheme.spacingLg),
                  Text('Mode', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: AppTheme.spacingSm),
                  Wrap(
                    spacing: 8,
                    children: travelModes.map((m) {
                      final selected = mode == m;
                      return ChoiceChip(
                        label: Text(m),
                        selected: selected,
                        onSelected: (_) => setModal(() => mode = selected ? null : m),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: AppTheme.spacingLg),
                  Row(
                    children: [
                      TextButton(
                        onPressed: () => setModal(() {
                          days = null;
                          styles = [];
                          mode = null;
                        }),
                        child: const Text('Clear'),
                      ),
                      const Spacer(),
                      FilledButton(
                        onPressed: () {
                          setState(() {
                            _filterDays = days;
                            _filterStyles = styles;
                            _filterMode = mode;
                          });
                          Navigator.pop(ctx);
                          _search();
                        },
                        child: const Text('Apply'),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _ProfileCard extends StatelessWidget {
  final ProfileSearchResult profile;
  final bool isFollowing;
  final bool isOwnProfile;
  final VoidCallback onTap;
  final VoidCallback? onFollowTap;

  const _ProfileCard({
    required this.profile,
    required this.isFollowing,
    required this.isOwnProfile,
    required this.onTap,
    this.onFollowTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: AppTheme.spacingMd),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacingMd),
          child: Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundImage: profile.photoUrl != null ? NetworkImage(profile.photoUrl!) : null,
                child: profile.photoUrl == null ? Icon(Icons.person_rounded, color: Theme.of(context).colorScheme.onSurfaceVariant) : null,
              ),
              const SizedBox(width: AppTheme.spacingMd),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      profile.name ?? 'Unknown',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.map_rounded, size: 14, color: Theme.of(context).colorScheme.onSurfaceVariant),
                        const SizedBox(width: 4),
                        Text('${profile.tripsCount} trips', style: Theme.of(context).textTheme.bodySmall),
                        const SizedBox(width: 12),
                        Icon(Icons.people_rounded, size: 14, color: Theme.of(context).colorScheme.onSurfaceVariant),
                        const SizedBox(width: 4),
                        Text('${profile.followersCount} followers', style: Theme.of(context).textTheme.bodySmall),
                      ],
                    ),
                  ],
                ),
              ),
              if (onFollowTap != null && !isOwnProfile)
                FilledButton.tonal(
                  onPressed: onFollowTap,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    minimumSize: Size.zero,
                  ),
                  child: Text(isFollowing ? 'Following' : 'Follow'),
                )
              else
                Icon(Icons.chevron_right_rounded, color: Theme.of(context).colorScheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

class _ItineraryCard extends StatelessWidget {
  final Itinerary itinerary;
  final VoidCallback onTap;
  final VoidCallback? onAuthorTap;

  const _ItineraryCard({required this.itinerary, required this.onTap, this.onAuthorTap});

  @override
  Widget build(BuildContext context) {
    final it = itinerary;
    return Card(
      margin: const EdgeInsets.only(bottom: AppTheme.spacingMd),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacingMd),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                it.title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                it.destination,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: AppTheme.spacingSm),
              Row(
                children: [
                  Icon(Icons.calendar_today_rounded, size: 14, color: Theme.of(context).colorScheme.onSurfaceVariant),
                  const SizedBox(width: 4),
                  Text('${it.daysCount} days', style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(width: 12),
                  if (it.mode != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(it.mode!.toUpperCase(), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.primary)),
                    ),
                  const Spacer(),
                  if (it.authorName != null)
                    InkWell(
                      onTap: onAuthorTap,
                      borderRadius: BorderRadius.circular(4),
                      child: Text('by ${it.authorName}', style: Theme.of(context).textTheme.bodySmall),
                    ),
                ],
              ),
              if (it.styleTags.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: it.styleTags.map((s) => Chip(label: Text(s, style: const TextStyle(fontSize: 11)), materialTapTargetSize: MaterialTapTargetSize.shrinkWrap)).toList(),
                ),
              ],
              if (it.stopsCount != null && it.stopsCount! > 0) ...[
                const SizedBox(height: 4),
                Text('${it.stopsCount} stops', style: Theme.of(context).textTheme.bodySmall),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
