import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/theme.dart';
import '../core/analytics.dart';
import '../models/itinerary.dart';
import '../services/supabase_service.dart';

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
    setState(() => _isLoading = true);
    try {
      final it = await SupabaseService.getItinerary(widget.itineraryId);
      final userId = Supabase.instance.client.auth.currentUser?.id;
      bool bookmarked = false;
      if (userId != null) bookmarked = await SupabaseService.isBookmarked(userId, widget.itineraryId);
      setState(() {
        _itinerary = it;
        _isBookmarked = bookmarked;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleBookmark() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;
    setState(() => _isBookmarked = !_isBookmarked); // Optimistic
    try {
      if (_isBookmarked) {
        await SupabaseService.addBookmark(userId, widget.itineraryId);
      } else {
        await SupabaseService.removeBookmark(userId, widget.itineraryId);
      }
      Analytics.logEvent('bookmark_toggled', {'itinerary_id': widget.itineraryId, 'bookmarked': _isBookmarked});
    } catch (e) {
      setState(() => _isBookmarked = !_isBookmarked); // Revert
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _forkItinerary() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    final it = _itinerary;
    if (userId == null || it == null) return;
    setState(() => _isLoading = true);
    try {
      final forked = await SupabaseService.createItinerary(
        authorId: userId,
        title: '${it.title} (copy)',
        destination: it.destination,
        daysCount: it.daysCount,
        styleTags: it.styleTags,
        mode: it.mode ?? 'standard',
        visibility: 'private',
        forkedFromId: it.id,
        stopsData: it.stops.map((s) => {'name': s.name, 'category': s.category, 'external_url': s.externalUrl, 'lat': s.lat, 'lng': s.lng, 'place_id': s.placeId}).toList(),
      );
      Analytics.logEvent('itinerary_forked', {'from': it.id, 'to': forked.id});
      if (mounted) context.go('/create'); // TODO: Open edit mode for forked itinerary
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
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
    return Scaffold(
      appBar: AppBar(
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
          if (it.hasMapStops)
            Container(
              height: 200,
              decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(12)),
              child: Center(child: Text('Map placeholder\n(integrate map SDK in Phase 2)', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey[600]))),
            )
          else
            Container(
              height: 120,
              decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(12)),
              child: Center(child: Icon(Icons.map, size: 48, color: Colors.grey[400])),
            ),
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
          Text('Stops', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          ...it.stops.asMap().entries.map((e) {
            final i = e.key + 1;
            final s = e.value;
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: CircleAvatar(child: Text('$i')),
                title: Text(s.name),
                subtitle: s.category != null ? Text(s.category!) : null,
                trailing: s.externalUrl != null ? IconButton(icon: const Icon(Icons.open_in_new), onPressed: () {}) : null,
              ),
            );
          }),
          if (it.stops.isEmpty) Text('No stops', style: TextStyle(color: Colors.grey[600])),
        ],
      ),
    );
  }
}
