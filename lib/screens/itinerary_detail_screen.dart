import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/theme.dart';
import '../core/constants.dart';
import '../core/analytics.dart';
import '../models/itinerary.dart';
import '../services/supabase_service.dart';
import '../widgets/itinerary_map.dart';

class ItineraryDetailScreen extends StatefulWidget {
  final String itineraryId;

  const ItineraryDetailScreen({super.key, required this.itineraryId});

  @override
  State<ItineraryDetailScreen> createState() => _ItineraryDetailScreenState();
}

class _ItineraryDetailScreenState extends State<ItineraryDetailScreen> {
  Itinerary? _itinerary;
  bool _isBookmarked = false;
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
      if (userId != null) bookmarked = await SupabaseService.isBookmarked(userId, widget.itineraryId);
      if (!mounted) return;
      setState(() {
        _itinerary = it;
        _isBookmarked = bookmarked;
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
    final Uri uri;
    if (stop.lat != null && stop.lng != null) {
      final lat = stop.lat!;
      final lng = stop.lng!;
      uri = defaultTargetPlatform == TargetPlatform.iOS
          ? Uri.parse('https://maps.apple.com/?ll=$lat,$lng')
          : Uri.parse('geo:$lat,$lng');
    } else {
      final query = Uri.encodeComponent(stop.name);
      uri = defaultTargetPlatform == TargetPlatform.iOS
          ? Uri.parse('https://maps.apple.com/?q=$query')
          : Uri.parse('geo:0,0?q=$query');
    }
    try {
      // Prefer native Maps app over browser
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalNonBrowserApplication,
      );
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
      return Scaffold(appBar: AppBar(title: const Text('Itinerary')), body: const Center(child: CircularProgressIndicator()));
    }
    if (_error != null || _itinerary == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Itinerary')),
        body: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [Text(_error ?? 'Not found'), const SizedBox(height: 16), FilledButton(onPressed: _load, child: const Text('Retry'))])),
      );
    }
    final it = _itinerary!;
    final stopsByDay = <int, List<ItineraryStop>>{};
    for (final s in it.stops) {
      stopsByDay.putIfAbsent(s.day, () => []).add(s);
    }
    for (final list in stopsByDay.values) {
      list.sort((a, b) => a.position.compareTo(b.position));
    }
    final sortedDays = stopsByDay.keys.toList()..sort();

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/home'),
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
          ItineraryMap(stops: it.stops, height: 280),
          const SizedBox(height: 16),
          Text(it.destination, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.calendar_today, size: 16, color: Colors.grey[600]),
              const SizedBox(width: 4),
              Text('${it.daysCount} days', style: TextStyle(color: Colors.grey[600])),
              const SizedBox(width: 16),
              if (it.mode != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(8)),
                  child: Text(it.mode!.toUpperCase(), style: TextStyle(fontSize: 12, color: Colors.blue.shade700)),
                ),
            ],
          ),
          if (it.authorName != null) ...[
            const SizedBox(height: 8),
            InkWell(
              onTap: () => context.push('/author/${it.authorId}'),
              child: Text('by ${it.authorName}', style: TextStyle(color: Colors.blue, fontSize: 14)),
            ),
          ],
          const SizedBox(height: 24),
          Text('Places', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          ...sortedDays.map((day) {
            final dayStops = stopsByDay[day]!;
            final locations = dayStops.where((s) => s.isLocation).toList();
            final venues = dayStops.where((s) => s.isVenue).toList();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Day $day', style: Theme.of(context).textTheme.titleSmall?.copyWith(color: Colors.grey[700], fontWeight: FontWeight.bold)),
                    if (locations.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Flexible(
                        child: Wrap(
                          spacing: 4,
                          runSpacing: 4,
                          children: locations.map((loc) => InkWell(
                            onTap: () => _openInMaps(loc),
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.grey[200],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.location_city, size: 14, color: Colors.grey[700]),
                                  const SizedBox(width: 4),
                                  Text(loc.name, style: TextStyle(fontSize: 12, color: Colors.grey[700])),
                                  const SizedBox(width: 4),
                                  Icon(Icons.open_in_new, size: 12, color: Colors.grey[600]),
                                ],
                              ),
                            ),
                          )).toList(),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                ...venues.map((s) => Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                          child: Icon(Icons.place, size: 20, color: Theme.of(context).colorScheme.onPrimaryContainer),
                        ),
                        title: Text(s.name),
                        subtitle: s.category != null && s.category != 'location' ? Text(s.category!) : null,
                        trailing: Icon(Icons.open_in_new, size: 18, color: Colors.grey[600]),
                        onTap: () => _openInMaps(s),
                      ),
                    )),
                if (locations.isNotEmpty && venues.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text('No places added', style: TextStyle(color: Colors.grey[500], fontSize: 13)),
                  ),
                const SizedBox(height: 12),
              ],
            );
          }),
          if (it.stops.isEmpty) Text('No places', style: TextStyle(color: Colors.grey[600])),
        ],
      ),
    );
  }
}
