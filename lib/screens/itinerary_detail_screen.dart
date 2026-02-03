import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/theme.dart';
import '../core/constants.dart';
import '../core/analytics.dart';
import '../core/app_link.dart';
import '../core/locale_notifier.dart';
import '../l10n/app_strings.dart';
import '../models/itinerary.dart';
import '../services/supabase_service.dart';
import '../services/translation_service.dart' show translate, isContentInDifferentLanguage;
import '../utils/map_urls.dart';
import '../widgets/itinerary_map.dart';
import '../widgets/itinerary_timeline.dart' show ItineraryTimeline, TransportDescriptions, TransportOverrides, TransportType, transportTypeFromString;

class ItineraryDetailScreen extends StatefulWidget {
  final String itineraryId;

  const ItineraryDetailScreen({super.key, required this.itineraryId});

  @override
  State<ItineraryDetailScreen> createState() => _ItineraryDetailScreenState();
}

class _ItineraryDetailScreenState extends State<ItineraryDetailScreen> {
  Itinerary? _itinerary;
  bool _isBookmarked = false;
  bool _isLiked = false;
  int _likeCount = 0;
  bool _isFollowing = false;
  bool _isLoading = true;
  String? _error;
  String? _translatedTitle;
  String? _translatedDestination;
  bool _isTranslating = false;
  bool? _showTranslateButton;

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
      bool liked = false;
      int likeCount = 0;
      bool following = false;
      if (userId != null && it != null) {
        bookmarked = await SupabaseService.isBookmarked(userId, widget.itineraryId);
        if (it.authorId != userId) {
          following = await SupabaseService.isFollowing(userId, it.authorId);
          final counts = await SupabaseService.getLikeCounts([widget.itineraryId]);
          liked = (await SupabaseService.getLikedItineraryIds(userId, [widget.itineraryId])).contains(widget.itineraryId);
          likeCount = counts[widget.itineraryId] ?? it.likeCount ?? 0;
        } else {
          final counts = await SupabaseService.getLikeCounts([widget.itineraryId]);
          likeCount = counts[widget.itineraryId] ?? it.likeCount ?? 0;
        }
      }
      if (!mounted) return;
      setState(() {
        _itinerary = it;
        _isBookmarked = bookmarked;
        _isLiked = liked;
        _likeCount = likeCount;
        _isFollowing = following;
        _isLoading = false;
      });
      if (it != null) _checkShowTranslate(it);
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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppStrings.t(context, 'could_not_update_follow_status'))));
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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppStrings.t(context, 'could_not_update_bookmark'))));
      }
    }
  }

  Future<void> _toggleLike() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    final it = _itinerary;
    if (userId == null || it == null || it.authorId == userId) return;
    if (!mounted) return;
    final wasLiked = _isLiked;
    setState(() {
      _isLiked = !_isLiked;
      _likeCount = (_likeCount + (wasLiked ? -1 : 1)).clamp(0, 0x7fffffff);
    });
    try {
      if (_isLiked) {
        await SupabaseService.addLike(userId, widget.itineraryId);
      } else {
        await SupabaseService.removeLike(userId, widget.itineraryId);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLiked = wasLiked;
          _likeCount = (_likeCount + (wasLiked ? 1 : -1)).clamp(0, 0x7fffffff);
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppStrings.t(context, 'could_not_refresh'))));
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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppStrings.t(context, 'could_not_open_maps'))));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppStrings.t(context, 'could_not_open_maps'))));
      }
    }
  }

  Future<void> _checkShowTranslate(Itinerary it) async {
    final text = '${it.title} ${it.destination}'.trim();
    if (text.length < 3) {
      if (mounted) setState(() => _showTranslateButton = false);
      return;
    }
    final different = await isContentInDifferentLanguage(text, LocaleNotifier.instance.localeCode);
    if (mounted) setState(() => _showTranslateButton = different);
  }

  TransportOverrides? _transportOverridesFor(Itinerary it) {
    final list = it.transportTransitions;
    if (list == null || list.isEmpty) return null;
    final overrides = <int, TransportType>{};
    for (var i = 0; i < list.length; i++) {
      overrides[i] = transportTypeFromString(list[i].type);
    }
    return overrides;
  }

  TransportDescriptions? _transportDescriptionsFor(Itinerary it) {
    final list = it.transportTransitions;
    if (list == null || list.isEmpty) return null;
    final descs = <int, String>{};
    for (var i = 0; i < list.length; i++) {
      final d = list[i].description;
      if (d != null && d.trim().isNotEmpty) descs[i] = d;
    }
    return descs.isEmpty ? null : descs;
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
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppStrings.t(context, 'could_not_fork_itinerary'))));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    Analytics.logScreenView('itinerary_detail');
    if (_isLoading && _itinerary == null) {
      return Scaffold(
        appBar: AppBar(title: Text(AppStrings.t(context, 'itinerary'))),
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
              Text(AppStrings.t(context, 'loading_itinerary'), style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
            ],
          ),
        ),
      );
    }
    if (_error != null || _itinerary == null) {
      return Scaffold(
        appBar: AppBar(title: Text(AppStrings.t(context, 'itinerary'))),
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
                FilledButton.icon(onPressed: _load, icon: const Icon(Icons.refresh, size: 20), label: Text(AppStrings.t(context, 'retry'))),
              ],
            ),
          ),
        ),
      );
    }
    final it = _itinerary!;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (context.canPop()) {
          context.pop(<String, dynamic>{'liked': _isLiked, 'likeCount': _likeCount, 'bookmarked': _isBookmarked});
        } else {
          context.go('/home');
        }
      },
      child: Scaffold(
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.9),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () {
                if (context.canPop()) {
                  context.pop(<String, dynamic>{'liked': _isLiked, 'likeCount': _likeCount, 'bookmarked': _isBookmarked});
                } else {
                  context.go('/home');
                }
              },
            ),
          ),
          actions: [
            Container(
              margin: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.9),
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: const Icon(Icons.share_outlined),
                onPressed: () => shareItineraryLink(widget.itineraryId, title: it.title),
              ),
            ),
            Container(
              margin: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.9),
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: Icon(_isBookmarked ? Icons.bookmark : Icons.bookmark_outline),
                onPressed: _toggleBookmark,
              ),
            ),
            Container(
              margin: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.9),
                shape: BoxShape.circle,
              ),
              child: PopupMenuButton(
                itemBuilder: (_) => [
                  PopupMenuItem(value: 'fork', child: Text(AppStrings.t(context, 'add_to_planning'))),
                  PopupMenuItem(value: 'author', child: Text(AppStrings.t(context, 'view_author_profile'))),
                ],
                onSelected: (v) {
                  if (v == 'fork') _forkItinerary();
                  else if (v == 'author') context.push('/author/${it.authorId}');
                },
              ),
            ),
          ],
        ),
        body: Stack(
          children: [
            // Full-screen map
            ItineraryMap(
              stops: it.stops,
              destination: it.destination,
              height: MediaQuery.of(context).size.height,
              fullScreen: true,
              transportTransitions: it.transportTransitions,
            ),
            // Draggable bottom sheet with details
            DraggableScrollableSheet(
              initialChildSize: 0.4,
              minChildSize: 0.3,
              maxChildSize: 0.95,
              builder: (context, scrollController) {
                return Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 10,
                        offset: const Offset(0, -2),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // Drag handle
                      Container(
                        margin: const EdgeInsets.symmetric(vertical: 12),
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      // Scrollable content
                      Expanded(
                        child: ListView(
                          controller: scrollController,
                          padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingMd),
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Expanded(
                                  child: Text(
                                    _translatedTitle ?? it.title,
                                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                                  ),
                                ),
                                if (_showTranslateButton == true)
                                  IconButton(
                                    icon: _isTranslating
                                        ? SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Theme.of(context).colorScheme.primary))
                                        : const Icon(Icons.translate_outlined),
                                    onPressed: _isTranslating
                                        ? null
                                        : (_translatedTitle != null || _translatedDestination != null)
                                            ? () => setState(() {
                                                  _translatedTitle = null;
                                                  _translatedDestination = null;
                                                })
                                            : () async {
                                                setState(() => _isTranslating = true);
                                                final titleResult = await translate(text: it.title, targetLanguageCode: LocaleNotifier.instance.localeCode);
                                                final destResult = await translate(text: it.destination, targetLanguageCode: LocaleNotifier.instance.localeCode);
                                                if (mounted) setState(() {
                                                  _translatedTitle = titleResult;
                                                  _translatedDestination = destResult;
                                                  _isTranslating = false;
                                                });
                                              },
                                  ),
                              ],
                            ),
                            const SizedBox(height: AppTheme.spacingMd),
                            Text(
                              _translatedDestination ?? it.destination,
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            if (Supabase.instance.client.auth.currentUser?.id != it.authorId) ...[
                              const SizedBox(height: AppTheme.spacingSm),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  InkWell(
                                    onTap: _toggleLike,
                                    borderRadius: BorderRadius.circular(20),
                                    child: Padding(
                                      padding: const EdgeInsets.only(top: 8, right: 8, bottom: 8),
                                      child: Icon(_isLiked ? Icons.thumb_up_rounded : Icons.thumb_up_outlined, size: 22, color: _isLiked ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.onSurfaceVariant),
                                    ),
                                  ),
                                  if (_likeCount > 0) ...[
                                    const SizedBox(width: 4),
                                    Text('$_likeCount ${AppStrings.t(context, 'likes')}', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                                  ],
                                ],
                              ),
                            ],
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
                                    Text('${it.daysCount} ${AppStrings.t(context, 'days')}', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
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
                            Text(AppStrings.t(context, 'places'), style: Theme.of(context).textTheme.headlineSmall),
                            const SizedBox(height: AppTheme.spacingMd),
                            ItineraryTimeline(
                              itinerary: it,
                              transportOverrides: _transportOverridesFor(it),
                              transportDescriptions: _transportDescriptionsFor(it),
                              onOpenInMaps: _openInMaps,
                            ),
                            SizedBox(height: MediaQuery.of(context).padding.bottom + AppTheme.spacingMd),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
