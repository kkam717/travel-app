import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/theme.dart';
import '../core/analytics.dart';
import '../data/countries.dart';
import '../models/itinerary.dart';
import '../models/profile.dart';
import '../services/supabase_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Profile? _profile;
  List<Itinerary> _myItineraries = [];
  int _tripsCount = 0;
  int _followersCount = 0;
  List<Itinerary> _feed = [];
  bool _isLoading = true;
  String? _error;
  final Map<String, bool> _bookmarked = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final profile = await SupabaseService.getProfile(userId);
      final trips = SupabaseService.getTripsCount(userId);
      final followers = SupabaseService.getFollowerCount(userId);
      final feed = SupabaseService.getFeedItineraries(userId);
      final myItineraries = SupabaseService.getUserItineraries(userId, publicOnly: false);
      final results = await Future.wait([trips, followers, feed, myItineraries]);
      if (!mounted) return;
      final tripsCount = results[0] as int;
      final followersCount = results[1] as int;
      final feedList = results[2] as List<Itinerary>;
      final myItinerariesList = results[3] as List<Itinerary>;
      final bookmarkChecks = await Future.wait(feedList.map((it) => SupabaseService.isBookmarked(userId, it.id)));
      if (!mounted) return;
      final bookmarkedMap = <String, bool>{};
      for (var i = 0; i < feedList.length; i++) {
        bookmarkedMap[feedList[i].id] = bookmarkChecks[i] as bool;
      }
      setState(() {
        _profile = profile;
        _myItineraries = myItinerariesList;
        _tripsCount = tripsCount;
        _followersCount = followersCount;
        _feed = feedList;
        _bookmarked.addAll(bookmarkedMap);
        _isLoading = false;
      });
      Analytics.logScreenView('home');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Something went wrong. Pull down to retry.';
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleBookmark(String itineraryId) async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;
    final wasBookmarked = _bookmarked[itineraryId] ?? false;
    if (!mounted) return;
    setState(() => _bookmarked[itineraryId] = !wasBookmarked);
    try {
      if (wasBookmarked) {
        await SupabaseService.removeBookmark(userId, itineraryId);
      } else {
        await SupabaseService.addBookmark(userId, itineraryId);
      }
    } catch (e) {
      if (mounted) setState(() => _bookmarked[itineraryId] = wasBookmarked);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not update bookmark. Please try again.')));
    }
  }

  String _descriptionFor(Itinerary it) {
    if (it.styleTags.isNotEmpty) {
      return 'Explore ${it.destination} with ${it.styleTags.take(2).join(', ').toLowerCase()}';
    }
    return 'Discover ${it.destination}';
  }

  String _locationsFor(Itinerary it) {
    if (it.stops.isNotEmpty) {
      return it.stops.take(3).map((s) => s.name).join('. ');
    }
    return it.destination;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_error!, textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        FilledButton(onPressed: _load, child: const Text('Retry')),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _load,
                    child: CustomScrollView(
                      slivers: [
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(AppTheme.spacingMd, AppTheme.spacingMd, AppTheme.spacingMd, 0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Welcome back!', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold, color: Colors.grey[900])),
                                const SizedBox(height: 4),
                                Text('Discover your next adventure', style: TextStyle(fontSize: 15, color: Colors.grey[600])),
                                const SizedBox(height: AppTheme.spacingLg),
                                Row(
                                  children: [
                                    Expanded(child: _StatCard(icon: Icons.location_on_outlined, value: '${mergedVisitedCountriesCount(_profile?.visitedCountries ?? [], _myItineraries.map((i) => i.destination).toList())}', label: 'Countries', color: Colors.blue.shade50, iconColor: Colors.blue.shade700)),
                                    const SizedBox(width: 12),
                                    Expanded(child: _StatCard(icon: Icons.trending_up, value: '$_tripsCount', label: 'Trips', color: Colors.purple.shade50, iconColor: Colors.purple.shade700)),
                                    const SizedBox(width: 12),
                                    Expanded(child: _StatCard(icon: Icons.people_outline, value: '$_followersCount', label: 'Followers', color: Colors.green.shade50, iconColor: Colors.green.shade700)),
                                  ],
                                ),
                                const SizedBox(height: AppTheme.spacingLg),
                                Text('Your Feed', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: Colors.grey[900])),
                                const SizedBox(height: AppTheme.spacingMd),
                              ],
                            ),
                          ),
                        ),
                        if (_feed.isEmpty)
                          SliverFillRemaining(
                            child: Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.explore_outlined, size: 64, color: Colors.grey[400]),
                                  const SizedBox(height: 16),
                                  Text('No trips in your feed yet', style: TextStyle(color: Colors.grey[600], fontSize: 16)),
                                  const SizedBox(height: 8),
                                  Text('Follow people or create your first trip!', style: TextStyle(color: Colors.grey[500], fontSize: 14)),
                                  const SizedBox(height: 24),
                                  FilledButton.icon(
                                    onPressed: () => context.go('/search'),
                                    icon: const Icon(Icons.search),
                                    label: const Text('Discover trips'),
                                  ),
                                ],
                              ),
                            ),
                          )
                        else
                          SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (_, i) {
                                final it = _feed[i];
                                return _FeedCard(
                                  itinerary: it,
                                  description: _descriptionFor(it),
                                  locations: _locationsFor(it),
                                  isBookmarked: _bookmarked[it.id] ?? false,
                                  onBookmark: () => _toggleBookmark(it.id),
                                  onTap: () => context.push('/itinerary/${it.id}'),
                                  onAuthorTap: () => context.push('/author/${it.authorId}'),
                                );
                              },
                              childCount: _feed.length,
                            ),
                          ),
                      ],
                    ),
                  ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;
  final Color iconColor;

  const _StatCard({required this.icon, required this.value, required this.label, required this.color, required this.iconColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingMd),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 24, color: iconColor),
          const SizedBox(height: 8),
          Text(value, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: Colors.grey[900])),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 13, color: Colors.grey[600])),
        ],
      ),
    );
  }
}

class _FeedCard extends StatelessWidget {
  final Itinerary itinerary;
  final String description;
  final String locations;
  final bool isBookmarked;
  final VoidCallback onBookmark;
  final VoidCallback onTap;
  final VoidCallback onAuthorTap;

  const _FeedCard({
    required this.itinerary,
    required this.description,
    required this.locations,
    required this.isBookmarked,
    required this.onBookmark,
    required this.onTap,
    required this.onAuthorTap,
  });

  @override
  Widget build(BuildContext context) {
    final it = itinerary;
    return Card(
      margin: const EdgeInsets.fromLTRB(AppTheme.spacingMd, 0, AppTheme.spacingMd, AppTheme.spacingMd),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacingMd),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(it.title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: Colors.grey[900])),
                        const SizedBox(height: 6),
                        InkWell(
                          onTap: onAuthorTap,
                          borderRadius: BorderRadius.circular(4),
                          child: Row(
                            children: [
                              Icon(Icons.person_outline, size: 14, color: Colors.grey[600]),
                              const SizedBox(width: 4),
                              Text(it.authorName ?? 'Unknown', style: TextStyle(fontSize: 13, color: Colors.grey[600])),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(isBookmarked ? Icons.bookmark : Icons.bookmark_border, color: isBookmarked ? Theme.of(context).colorScheme.primary : Colors.grey),
                    onPressed: onBookmark,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(description, style: TextStyle(fontSize: 14, color: Colors.grey[700], height: 1.4)),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.calendar_today, size: 14, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text('${it.daysCount} days', style: TextStyle(fontSize: 13, color: Colors.grey[600])),
                  const SizedBox(width: 12),
                  if (it.mode != null) ...[
                    Icon(Icons.attach_money, size: 14, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: it.mode == 'luxury' ? Colors.purple.shade50 : Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(it.mode!.toUpperCase(), style: TextStyle(fontSize: 11, color: it.mode == 'luxury' ? Colors.purple.shade700 : Colors.blue.shade700, fontWeight: FontWeight.w500)),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 8),
              Text(locations, style: TextStyle(fontSize: 13, color: Colors.grey[600])),
            ],
          ),
        ),
      ),
    );
  }
}
