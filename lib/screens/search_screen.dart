import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../core/theme.dart';
import '../core/analytics.dart';
import '../models/itinerary.dart';
import '../services/supabase_service.dart';
import '../data/countries.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _searchController = TextEditingController();
  List<Itinerary> _results = [];
  bool _isLoading = false;
  String? _error;
  int? _filterDays;
  List<String> _filterStyles = [];
  String? _filterMode;

  @override
  void initState() {
    super.initState();
    _search();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final results = await SupabaseService.searchItineraries(
        query: _searchController.text.trim().isEmpty ? null : _searchController.text.trim(),
        daysCount: _filterDays,
        styles: _filterStyles.isEmpty ? null : _filterStyles,
        mode: _filterMode,
      );
      if (!mounted) return;
      setState(() {
        _results = results;
        _isLoading = false;
      });
      Analytics.logEvent('search_performed', {'result_count': results.length});
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
        actions: [
          IconButton(icon: const Icon(Icons.filter_list), onPressed: _showFilters),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(AppTheme.spacingMd),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Destination or keywords...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    _search();
                  },
                ),
              ),
              onSubmitted: (_) => _search(),
            ),
          ),
          if (_isLoading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else if (_error != null)
            Expanded(child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [Text(_error!, textAlign: TextAlign.center), const SizedBox(height: 16), FilledButton(onPressed: _search, child: const Text('Retry'))])))
          else if (_results.isEmpty)
            Expanded(child: Center(child: Text('No itineraries found', style: TextStyle(color: Colors.grey[600]))))
          else
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingMd),
                itemCount: _results.length,
                itemBuilder: (_, i) => _ItineraryCard(
                  itinerary: _results[i],
                  onTap: () => context.push('/itinerary/${_results[i].id}'),
                  onAuthorTap: () => context.push('/author/${_results[i].authorId}'),
                ),
              ),
            ),
        ],
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
                  Text('Duration (days)', style: Theme.of(context).textTheme.titleSmall),
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
                  const SizedBox(height: 16),
                  Text('Travel style', style: Theme.of(context).textTheme.titleSmall),
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
                  const SizedBox(height: 16),
                  Text('Mode', style: Theme.of(context).textTheme.titleSmall),
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
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      TextButton(onPressed: () => setModal(() { days = null; styles = []; mode = null; }), child: const Text('Clear')),
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
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacingMd),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(it.title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(it.destination, style: TextStyle(color: Colors.grey[600], fontSize: 14)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.calendar_today, size: 14, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text('${it.daysCount} days', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                  const SizedBox(width: 12),
                  if (it.mode != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(8)),
                      child: Text(it.mode!.toUpperCase(), style: TextStyle(fontSize: 12, color: Colors.blue.shade700)),
                    ),
                  const Spacer(),
                  if (it.authorName != null)
                    InkWell(
                      onTap: onAuthorTap,
                      borderRadius: BorderRadius.circular(4),
                      child: Text('by ${it.authorName}', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                    ),
                ],
              ),
              if (it.styleTags.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: it.styleTags.map((s) => Chip(label: Text(s, style: const TextStyle(fontSize: 11)), materialTapTargetSize: MaterialTapTargetSize.shrinkWrap)).toList(),
                ),
              ],
              if (it.stopsCount != null) ...[
                const SizedBox(height: 4),
                Text('${it.stopsCount} stops', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
