import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/theme.dart';
import '../core/analytics.dart';
import '../core/home_cache.dart';
import '../models/itinerary.dart';
import '../models/profile.dart';
import '../services/supabase_service.dart';
import '../widgets/static_map_image.dart';

const int _pageSize = 20;
const int _discoverLimit = 5;

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Itinerary> _feed = [];
  List<Itinerary> _discover = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  String? _error;
  final Map<String, bool> _bookmarked = {};
  final ScrollController _scrollController = ScrollController();
  int _newTripsCount = 0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _initOrLoad();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_isLoadingMore || !_hasMore || _feed.isEmpty) return;
    final pos = _scrollController.position;
    if (pos.pixels >= pos.maxScrollExtent - 400) {
      _loadMore();
    }
  }

  void _initOrLoad() {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;
    final cached = HomeCache.get(userId);
    if (HomeCache.hasData(userId)) {
      if (mounted) {
        setState(() {
          _feed = cached.feed;
          _bookmarked.clear();
          _bookmarked.addAll(cached.bookmarked);
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
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }
    try {
      final profile = SupabaseService.getProfile(userId);
      final feed = SupabaseService.getFeedItineraries(userId, limit: _pageSize);
      final myItineraries = SupabaseService.getUserItineraries(userId, publicOnly: false);
      final discover = SupabaseService.getDiscoverItineraries(userId, limit: _discoverLimit);
      final results = await Future.wait([profile, feed, myItineraries, discover]);
      if (!mounted) return;
      final profileResult = results[0] as Profile?;
      final feedList = results[1] as List<Itinerary>;
      final myItinerariesList = results[2] as List<Itinerary>;
      final discoverList = results[3] as List<Itinerary>;
      final allIds = [...feedList.map((i) => i.id), ...discoverList.map((i) => i.id)];
      final bookmarkedIds = allIds.isEmpty ? <String>{} : await SupabaseService.getBookmarkedItineraryIds(userId, allIds);
      if (!mounted) return;
      final bookmarkedMap = {for (final it in [...feedList, ...discoverList]) it.id: bookmarkedIds.contains(it.id)};
      HomeCache.put(
        userId,
        profile: profileResult,
        myItineraries: myItinerariesList,
        feed: feedList,
        bookmarked: bookmarkedMap,
      );
      setState(() {
        _feed = feedList;
        _discover = discoverList;
        _bookmarked.clear();
        _bookmarked.addAll(bookmarkedMap);
        _isLoading = false;
        _hasMore = feedList.length >= _pageSize;
      });
      Analytics.logScreenView('home');
    } catch (e) {
      if (!mounted) return;
      if (silent) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not refresh. Pull down to retry.')));
        return;
      }
      setState(() {
        _error = 'Something went wrong. Pull down to retry.';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || !_hasMore || _feed.isEmpty) return;
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;
    final last = _feed.last;
    final cursor = last.createdAt?.toIso8601String();
    if (cursor == null) return;
    _isLoadingMore = true;
    if (mounted) setState(() {});
    try {
      final more = await SupabaseService.getFeedItineraries(userId, limit: _pageSize, afterCreatedAt: cursor);
      if (!mounted) return;
      final bookmarkedIds = more.isEmpty ? <String>{} : await SupabaseService.getBookmarkedItineraryIds(userId, more.map((i) => i.id).toList());
      if (!mounted) return;
      final bookmarkedMap = {for (final it in more) it.id: bookmarkedIds.contains(it.id)};
      if (mounted) {
        setState(() {
          _feed = [..._feed, ...more];
          _bookmarked.addAll(bookmarkedMap);
          _isLoadingMore = false;
          _hasMore = more.length >= _pageSize;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  Future<void> _onRefresh() async {
    final beforeCount = _feed.length;
    await _load(silent: true);
    if (!mounted) return;
    final newCount = _feed.length;
    _newTripsCount = newCount > beforeCount ? newCount - beforeCount : 0;
    if (_newTripsCount > 0 && mounted) {
      HapticFeedback.mediumImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_newTripsCount == 1 ? '1 new trip' : '$_newTripsCount new trips'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _toggleBookmark(String itineraryId) async {
    HapticFeedback.lightImpact();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: _isLoading
            ? _buildSkeletonLoading()
            : _error != null
                ? _buildErrorState()
                : RefreshIndicator(
                    onRefresh: _onRefresh,
                    child: CustomScrollView(
                      controller: _scrollController,
                      physics: const AlwaysScrollableScrollPhysics(),
                      slivers: [
                        SliverToBoxAdapter(child: _buildHeader()),
                        if (_discover.isNotEmpty) ...[
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(AppTheme.spacingLg, AppTheme.spacingMd, AppTheme.spacingLg, AppTheme.spacingSm),
                              child: Text('For you', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                            ),
                          ),
                          SliverToBoxAdapter(
                            child: SizedBox(
                              height: 220,
                              child: ListView.builder(
                                scrollDirection: Axis.horizontal,
                                padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingMd),
                                itemCount: _discover.length,
                                itemBuilder: (_, i) {
                                  final it = _discover[i];
                                  return Padding(
                                    padding: const EdgeInsets.only(right: AppTheme.spacingMd),
                                    child: SizedBox(
                                      width: 280,
                                      child: _FeedCard(
                                        itinerary: it,
                                        description: _descriptionFor(it),
                                        locations: _locationsFor(it),
                                        isBookmarked: _bookmarked[it.id] ?? false,
                                        onBookmark: () => _toggleBookmark(it.id),
                                        onTap: () => context.push('/itinerary/${it.id}'),
                                        onAuthorTap: () => context.push('/author/${it.authorId}'),
                                        variant: _CardVariant.compact,
                                        index: i,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                          const SliverToBoxAdapter(child: SizedBox(height: AppTheme.spacingLg)),
                        ],
                        if (_feed.isEmpty)
                          SliverFillRemaining(child: _buildEmptyState())
                        else
                          SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (_, i) {
                                if (i == _feed.length) {
                                  return _buildLoadMoreOrEnd();
                                }
                                final it = _feed[i];
                                return _SwipeableFeedCard(
                                  itinerary: it,
                                  description: _descriptionFor(it),
                                  locations: _locationsFor(it),
                                  isBookmarked: _bookmarked[it.id] ?? false,
                                  onBookmark: () => _toggleBookmark(it.id),
                                  onTap: () => context.push('/itinerary/${it.id}'),
                                  onAuthorTap: () => context.push('/author/${it.authorId}'),
                                  variant: _CardVariant.standard,
                                  index: i,
                                );
                              },
                              childCount: _feed.length + 1,
                            ),
                          ),
                        SliverToBoxAdapter(child: _buildPeekPadding()),
                      ],
                    ),
                  ),
      ),
    );
  }

  Widget _buildSkeletonLoading() {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(child: _buildHeader()),
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (_, i) => _SkeletonCard(variant: _CardVariant.values[i % 3]),
            childCount: 6,
          ),
        ),
      ],
    );
  }

  Widget _buildLoadMoreOrEnd() {
    if (_isLoadingMore) {
      return const Padding(
        padding: EdgeInsets.all(AppTheme.spacingLg),
        child: Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))),
      );
    }
    if (_hasMore && _feed.isNotEmpty) {
      return Padding(
        padding: const EdgeInsets.all(AppTheme.spacingMd),
        child: Center(
          child: Text(
            '${_feed.length} trips so far • Keep scrolling for more',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
        ),
      );
    }
    return const SizedBox(height: AppTheme.spacingMd);
  }

  Widget _buildPeekPadding() {
    return Container(
      height: 24,
      margin: const EdgeInsets.only(bottom: AppTheme.spacingMd),
      alignment: Alignment.center,
      child: _feed.isNotEmpty && _hasMore
          ? Icon(Icons.keyboard_arrow_down_rounded, size: 20, color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.5))
          : null,
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppTheme.spacingLg, AppTheme.spacingLg, AppTheme.spacingLg, AppTheme.spacingMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Welcome back',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            'Discover your next adventure',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingXl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.explore_rounded, size: 56, color: Theme.of(context).colorScheme.primary),
            ),
            const SizedBox(height: AppTheme.spacingLg),
            Text(
              'No trips in your feed yet',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppTheme.spacingSm),
            Text(
              'Follow people or create your first trip to get started',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppTheme.spacingXl),
            FilledButton.icon(
              onPressed: () => context.go('/search'),
              icon: const Icon(Icons.search_rounded, size: 20),
              label: const Text('Discover trips'),
            ),
          ],
        ),
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
            Text(_error!, style: Theme.of(context).textTheme.bodyLarge, textAlign: TextAlign.center),
            const SizedBox(height: AppTheme.spacingLg),
            FilledButton(onPressed: () => _load(silent: false), child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}

enum _CardVariant { standard, tall, compact }

class _SwipeableFeedCard extends StatelessWidget {
  final Itinerary itinerary;
  final String description;
  final String locations;
  final bool isBookmarked;
  final VoidCallback onBookmark;
  final VoidCallback onTap;
  final VoidCallback onAuthorTap;
  final _CardVariant variant;
  final int index;

  const _SwipeableFeedCard({
    required this.itinerary,
    required this.description,
    required this.locations,
    required this.isBookmarked,
    required this.onBookmark,
    required this.onTap,
    required this.onAuthorTap,
    required this.variant,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 300 + (index * 80).clamp(0, 400)),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - value)),
            child: child,
          ),
        );
      },
      child: Dismissible(
        key: Key('swipe-${itinerary.id}'),
        direction: DismissDirection.horizontal,
        background: Container(
          margin: const EdgeInsets.fromLTRB(AppTheme.spacingLg, 0, AppTheme.spacingLg, AppTheme.spacingMd),
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: AppTheme.spacingLg),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Icon(Icons.bookmark_add_rounded, color: Theme.of(context).colorScheme.primary, size: 32),
        ),
        confirmDismiss: (direction) async {
          if (!isBookmarked) {
            HapticFeedback.mediumImpact();
            onBookmark();
          }
          return false;
        },
        child: _FeedCard(
          itinerary: itinerary,
          description: description,
          locations: locations,
          isBookmarked: isBookmarked,
          onBookmark: onBookmark,
          onTap: onTap,
          onAuthorTap: onAuthorTap,
          variant: variant,
          index: index,
        ),
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
  final _CardVariant variant;
  final int index;

  const _FeedCard({
    required this.itinerary,
    required this.description,
    required this.locations,
    required this.isBookmarked,
    required this.onBookmark,
    required this.onTap,
    required this.onAuthorTap,
    required this.variant,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    final it = itinerary;
    final isCompact = variant == _CardVariant.compact;
    final mapHeight = variant == _CardVariant.tall ? 240.0 : (isCompact ? 120.0 : 200.0);

    return Card(
      margin: const EdgeInsets.fromLTRB(AppTheme.spacingLg, 0, AppTheme.spacingLg, AppTheme.spacingMd),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: EdgeInsets.all(isCompact ? AppTheme.spacingSm : AppTheme.spacingMd),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final contentWidth = constraints.maxWidth;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: onAuthorTap,
                      borderRadius: BorderRadius.circular(8),
                      child: Row(
                        children: [
                          Icon(Icons.person_outline_rounded, size: 16, color: Theme.of(context).colorScheme.onSurfaceVariant),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              it.authorName ?? 'Unknown',
                              style: TextStyle(fontSize: 14, color: Theme.of(context).colorScheme.onSurfaceVariant, fontWeight: FontWeight.w500),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(isBookmarked ? Icons.bookmark_rounded : Icons.bookmark_border_rounded, color: isBookmarked ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.onSurfaceVariant),
                    onPressed: onBookmark,
                    style: IconButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(40, 40)),
                  ),
                ],
              ),
              if (it.bookmarkCount != null && it.bookmarkCount! > 0) ...[
                const SizedBox(height: 2),
                Text(
                  '${it.bookmarkCount} saved',
                  style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w500),
                ),
              ],
              if (it.updatedAt != null) ...[
                const SizedBox(height: 2),
                Text(_formatDate(it.updatedAt!), style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
              ],
              const SizedBox(height: AppTheme.spacingSm),
              Text(
                it.title,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                maxLines: isCompact ? 1 : 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (description.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  description,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant, height: 1.4),
                  maxLines: isCompact ? 1 : 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: AppTheme.spacingMd),
              Wrap(
                spacing: 16,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.calendar_today_rounded, size: 14, color: Theme.of(context).colorScheme.onSurfaceVariant),
                      const SizedBox(width: 4),
                      Text('${it.daysCount} days', style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                    ],
                  ),
                  if (it.mode != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: it.mode == 'luxury' ? Colors.purple.shade50 : Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        it.mode!.toUpperCase(),
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: it.mode == 'luxury' ? Colors.purple.shade700 : Theme.of(context).colorScheme.primary),
                      ),
                    ),
                  if (locations.isNotEmpty)
                    ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: contentWidth - 100),
                      child: Text(locations, style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant), maxLines: 2, overflow: TextOverflow.ellipsis),
                    ),
                ],
              ),
              const SizedBox(height: AppTheme.spacingMd),
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: StaticMapImage(
                  itinerary: it,
                  width: contentWidth,
                  height: mapHeight,
                  pathColor: Theme.of(context).colorScheme.primary,
                ),
              ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
  }
}

class _SkeletonCard extends StatelessWidget {
  final _CardVariant variant;

  const _SkeletonCard({required this.variant});

  @override
  Widget build(BuildContext context) {
    final mapHeight = variant == _CardVariant.tall ? 240.0 : 200.0;
    return Card(
      margin: const EdgeInsets.fromLTRB(AppTheme.spacingLg, 0, AppTheme.spacingLg, AppTheme.spacingMd),
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(width: 80, height: 14, decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(4))),
                const Spacer(),
                Container(width: 24, height: 24, decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(12))),
              ],
            ),
            const SizedBox(height: 12),
            Container(width: 180, height: 20, decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(4))),
            const SizedBox(height: 8),
            Container(width: double.infinity, height: 14, decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(4))),
            const SizedBox(height: 16),
            Row(
              children: [
                Container(width: 60, height: 12, decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(4))),
                const SizedBox(width: 16),
                Container(width: 50, height: 12, decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(4))),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              height: mapHeight,
              decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(14)),
            ),
          ],
        ),
      ),
    );
  }
}
