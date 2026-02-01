import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/theme.dart';
import '../core/analytics.dart';
import '../core/saved_cache.dart';
import '../models/itinerary.dart';
import '../services/supabase_service.dart';

class SavedScreen extends StatefulWidget {
  const SavedScreen({super.key});

  @override
  State<SavedScreen> createState() => _SavedScreenState();
}

class _SavedScreenState extends State<SavedScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Itinerary> _bookmarked = [];
  List<Itinerary> _planning = [];
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _initOrLoad();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _initOrLoad() {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;
    if (SavedCache.hasData(userId)) {
      final cached = SavedCache.get(userId);
      if (mounted) {
        setState(() {
          _bookmarked = cached.bookmarked;
          _planning = cached.planning;
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
      final results = await Future.wait([
        SupabaseService.getBookmarkedItineraries(userId),
        SupabaseService.getPlanningItineraries(userId),
      ]);
      if (!mounted) return;
      final bookmarked = results[0];
      final planning = results[1];
      SavedCache.put(userId, bookmarked: bookmarked, planning: planning);
      if (mounted) {
        setState(() {
          _bookmarked = bookmarked;
          _planning = planning;
          _isLoading = false;
        });
      }
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
        _error = 'Something went wrong. Please try again.';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    Analytics.logScreenView('saved');
    return Scaffold(
      appBar: AppBar(
        title: const Text('Saved'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.bookmark_outline), text: 'Bookmarked'),
            Tab(icon: Icon(Icons.edit_road_outlined), text: 'Planning'),
          ],
        ),
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(width: 40, height: 40, child: CircularProgressIndicator(strokeWidth: 2, color: Theme.of(context).colorScheme.primary)),
                  const SizedBox(height: AppTheme.spacingLg),
                  Text('Loading…', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
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
                        Icon(Icons.bookmark_remove_outlined, size: 64, color: Theme.of(context).colorScheme.outline),
                        const SizedBox(height: AppTheme.spacingLg),
                        Text(_error!, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyLarge),
                        const SizedBox(height: AppTheme.spacingLg),
                        FilledButton.icon(onPressed: _load, icon: const Icon(Icons.refresh, size: 20), label: const Text('Retry')),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: () => _load(silent: true),
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _ItineraryList(itineraries: _bookmarked, emptyMessage: 'No bookmarked itineraries', canEdit: false),
                      _ItineraryList(itineraries: _planning, emptyMessage: 'No itineraries in planning', canEdit: true),
                    ],
                  ),
                ),
    );
  }
}

class _ItineraryList extends StatelessWidget {
  final List<Itinerary> itineraries;
  final String emptyMessage;
  final bool canEdit;

  const _ItineraryList({required this.itineraries, required this.emptyMessage, this.canEdit = false});

  @override
  Widget build(BuildContext context) {
    if (itineraries.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacingLg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(canEdit ? Icons.edit_road_outlined : Icons.bookmark_outline, size: 64, color: Theme.of(context).colorScheme.outline),
              const SizedBox(height: AppTheme.spacingLg),
              Text(emptyMessage, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
            ],
          ),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(AppTheme.spacingMd),
      itemCount: itineraries.length,
      addRepaintBoundaries: true,
      itemBuilder: (_, i) {
        final it = itineraries[i];
        return Card(
          margin: const EdgeInsets.only(bottom: AppTheme.spacingMd),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              child: Icon(Icons.route_outlined, color: Theme.of(context).colorScheme.onPrimaryContainer),
            ),
            title: Text(it.title, style: Theme.of(context).textTheme.titleSmall),
            subtitle: Text('${it.destination} • ${it.daysCount} days', style: Theme.of(context).textTheme.bodySmall),
            trailing: canEdit
                ? IconButton(
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: () => context.push('/itinerary/${it.id}/edit'),
                  )
                : Icon(Icons.chevron_right, color: Theme.of(context).colorScheme.onSurfaceVariant),
            onTap: () => context.push('/itinerary/${it.id}'),
          ),
        );
      },
    );
  }
}
