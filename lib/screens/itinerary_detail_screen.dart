import 'package:flutter/foundation.dart' show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/theme.dart';
import '../core/constants.dart';
import '../core/analytics.dart';
import '../models/itinerary.dart';
import '../services/supabase_service.dart';
import '../utils/map_urls.dart';
import '../widgets/itinerary_map.dart';
import '../widgets/itinerary_timeline.dart' show ItineraryTimeline, TransportOverrides, TransportType, transportTypeFromString;

class ItineraryDetailScreen extends StatefulWidget {
  final String itineraryId;

  const ItineraryDetailScreen({super.key, required this.itineraryId});

  @override
  State<ItineraryDetailScreen> createState() => _ItineraryDetailScreenState();
}

class _ItineraryDetailScreenState extends State<ItineraryDetailScreen> {
  Itinerary? _itinerary;
  bool _isBookmarked = false;
  bool _isFollowing = false;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final it = await SupabaseService.getItinerary(widget.itineraryId);
      if (!mounted) return;
      final userId = Supabase.instance.client.auth.currentUser?.id;
      bool bookmarked = false;
      bool following = false;
      if (userId != null && it != null) {
        bookmarked = await SupabaseService.isBookmarked(userId, widget.itineraryId);
        if (it.authorId != userId) {
          following = await SupabaseService.isFollowing(userId, it.authorId);
        }
      }
      if (!mounted) return;
      setState(() {
        _itinerary = it;
        _isBookmarked = bookmarked;
        _isFollowing = following;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load itinerary. Please try again.';
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleFollow() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    final it = _itinerary;
    if (userId == null || it == null || it.authorId == userId) return;
    if (!mounted) return;
    setState(() => _isFollowing = !_isFollowing);
    try {
      if (_isFollowing) {
        await SupabaseService.followUser(userId, it.authorId);
      } else {
        await SupabaseService.unfollowUser(userId, it.authorId);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isFollowing = !_isFollowing);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not update follow status. Please try again.')));
      }
    }
  }

  Future<void> _toggleBookmark() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;
    if (!mounted) return;
    setState(() => _isBookmarked = !_isBookmarked);
    try {
      if (_isBookmarked) {
        await SupabaseService.addBookmark(userId, widget.itineraryId);
      } else {
        await SupabaseService.removeBookmark(userId, widget.itineraryId);
      }
      Analytics.logEvent('bookmark_toggled', {'itinerary_id': widget.itineraryId, 'bookmarked': _isBookmarked});
    } catch (e) {
      if (mounted) {
        setState(() => _isBookmarked = !_isBookmarked);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not update bookmark. Please try again.')));
      }
    }
  }

  Future<void> _openInMaps(ItineraryStop stop) async {
    final uri = MapUrls.buildItineraryStopMapUrl(stop);
    try {
      final mode = kIsWeb ? LaunchMode.platformDefault : LaunchMode.externalNonBrowserApplication;
      final launched = await launchUrl(uri, mode: mode);
      if (!launched && await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else if (!launched && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open Maps')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open Maps')));
      }
    }
  }

  TransportOverrides? _transportOverridesFor(Itinerary it) {
    final list = it.transportTransitions;
    if (list == null || list.isEmpty) return null;
    final overrides = <int, TransportType>{};
    for (var i = 0; i < list.length; i++) {
      overrides[i] = transportTypeFromString(list[i]);
    }
    return overrides;
  }

  Future<void> _forkItinerary() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    final it = _itinerary;
    if (userId == null || it == null) return;
    setState(() => _isLoading = true);
    try {
      var pos = 0;
      final stopsData = it.stops.map((s) {
        final m = <String, dynamic>{
          'name': s.name,
          'category': s.category,
          'stop_type': s.stopType,
          'lat': s.lat,
          'lng': s.lng,
          'external_url': s.externalUrl,
          'day': s.day,
          'position': pos++,
        };
        return m;
      }).toList();
      final forked = await SupabaseService.createItinerary(
        authorId: userId,
        title: '${it.title} (copy)',
        destination: it.destination,
        daysCount: it.daysCount,
        styleTags: it.styleTags,
        mode: it.mode ?? modeStandard,
        visibility: visibilityPrivate,
        forkedFromId: it.id,
        stopsData: stopsData,
        transportTransitions: it.transportTransitions,
      );
      Analytics.logEvent('itinerary_forked', {'from': it.id, 'to': forked.id});
      if (mounted) context.go('/itinerary/${forked.id}');
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not fork itinerary. Please try again.')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    Analytics.logScreenView('itinerary_detail');
    if (_isLoading && _itinerary == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Itinerary')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 40,
                height: 40,
                child: CircularProgressIndicator(strokeWidth: 2, color: Theme.of(context).colorScheme.primary),
              ),
              const SizedBox(height: AppTheme.spacingLg),
              Text('Loading itinerary…', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
            ],
          ),
        ),
      );
    }
    if (_error != null || _itinerary == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Itinerary')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.spacingLg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.map_outlined, size: 64, color: Theme.of(context).colorScheme.outline),
                const SizedBox(height: AppTheme.spacingLg),
                Text(_error ?? 'Not found', textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyLarge),
                const SizedBox(height: AppTheme.spacingLg),
                FilledButton.icon(onPressed: _load, icon: const Icon(Icons.refresh, size: 20), label: const Text('Retry')),
              ],
            ),
          ),
        ),
      );
    }
    final it = _itinerary!;

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
        title: Text(it.title),
        actions: [
          IconButton(
            icon: Icon(_isBookmarked ? Icons.bookmark : Icons.bookmark_outline),
            onPressed: _toggleBookmark,
          ),
          PopupMenuButton(
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'fork', child: Text('Add to Planning (fork)')),
              const PopupMenuItem(value: 'author', child: Text('View author profile')),
            ],
            onSelected: (v) {
              if (v == 'fork') _forkItinerary();
              else if (v == 'author') context.push('/author/${it.authorId}');
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppTheme.spacingMd),
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: ItineraryMap(stops: it.stops, destination: it.destination, height: 260),
          ),
          const SizedBox(height: AppTheme.spacingLg),
          Text(it.destination, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: AppTheme.spacingSm),
          Wrap(
            spacing: AppTheme.spacingMd,
            runSpacing: AppTheme.spacingSm,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.calendar_today_outlined, size: 18, color: Theme.of(context).colorScheme.onSurfaceVariant),
                  const SizedBox(width: 6),
                  Text('${it.daysCount} days', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                ],
              ),
              if (it.mode != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(it.mode!.toUpperCase(), style: Theme.of(context).textTheme.labelMedium?.copyWith(color: Theme.of(context).colorScheme.primary)),
                ),
            ],
          ),
          if (it.authorName != null) ...[
            const SizedBox(height: AppTheme.spacingSm),
            Row(
              children: [
                InkWell(
                  onTap: () => context.push('/author/${it.authorId}'),
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.person_outline, size: 18, color: Theme.of(context).colorScheme.primary),
                        const SizedBox(width: 6),
                        Text('by ${it.authorName}', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ),
                ),
                if (Supabase.instance.client.auth.currentUser?.id != it.authorId) ...[
                  const SizedBox(width: AppTheme.spacingMd),
                  FilledButton.tonal(
                    onPressed: _toggleFollow,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(_isFollowing ? 'Following' : 'Follow'),
                  ),
                ],
              ],
            ),
          ],
          const SizedBox(height: AppTheme.spacingLg),
          Text('Places', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: AppTheme.spacingMd),
          ItineraryTimeline(
            itinerary: it,
            transportOverrides: _transportOverridesFor(it),
            onOpenInMaps: _openInMaps,
          ),
        ],
      ),
    );
  }
}
