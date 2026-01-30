import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/theme.dart';
import '../core/analytics.dart';
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
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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
      final results = await Future.wait([
        SupabaseService.getBookmarkedItineraries(userId),
        SupabaseService.getPlanningItineraries(userId),
      ]);
      if (!mounted) return;
      final bookmarked = results[0] as List<Itinerary>;
      final planning = results[1] as List<Itinerary>;
      setState(() {
        _bookmarked = bookmarked;
        _planning = planning;
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

  @override
  Widget build(BuildContext context) {
    Analytics.logScreenView('saved');
    return Scaffold(
      appBar: AppBar(
        title: const Text('Saved'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [Tab(text: 'Bookmarked'), Tab(text: 'Planning')],
        ),
      ),
      body: _isLoading
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
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _ItineraryList(itineraries: _bookmarked, emptyMessage: 'No bookmarked itineraries'),
                    _ItineraryList(itineraries: _planning, emptyMessage: 'No itineraries in planning'),
                  ],
                ),
    );
  }
}

class _ItineraryList extends StatelessWidget {
  final List<Itinerary> itineraries;
  final String emptyMessage;

  const _ItineraryList({required this.itineraries, required this.emptyMessage});

  @override
  Widget build(BuildContext context) {
    if (itineraries.isEmpty) {
      return Center(child: Text(emptyMessage, style: TextStyle(color: Colors.grey[600])));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(AppTheme.spacingMd),
      itemCount: itineraries.length,
      itemBuilder: (_, i) {
        final it = itineraries[i];
        return Card(
          margin: const EdgeInsets.only(bottom: AppTheme.spacingMd),
          child: ListTile(
            title: Text(it.title),
            subtitle: Text('${it.destination} • ${it.daysCount} days'),
            onTap: () => context.push('/itinerary/${it.id}'),
          ),
        );
      },
    );
  }
}
