import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/theme.dart';
import '../core/analytics.dart';
import '../l10n/app_strings.dart';
import '../models/itinerary.dart';
import '../services/supabase_service.dart';

class MyTripsScreen extends StatefulWidget {
  final String? userId;

  const MyTripsScreen({super.key, this.userId});

  @override
  State<MyTripsScreen> createState() => _MyTripsScreenState();
}

class _MyTripsScreenState extends State<MyTripsScreen> {
  List<Itinerary> _itineraries = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(MyTripsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userId != widget.userId) _load();
  }

  bool get _isOwnTrips => widget.userId == null;

  Future<void> _load() async {
    final userId = widget.userId ?? Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      // RLS already enforces visibility (public, own, mutual friends). No need to filter by visibility client-side.
      final itineraries = await SupabaseService.getUserItineraries(userId, publicOnly: false);
      if (!mounted) return;
      setState(() {
        _itineraries = itineraries;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Something went wrong. Pull down to retry.';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    Analytics.logScreenView('my_trips');
    return Scaffold(
      appBar: AppBar(
        title: Text(_isOwnTrips ? AppStrings.t(context, 'my_trips') : AppStrings.t(context, 'trips')),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 40,
                    height: 40,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Theme.of(context).colorScheme.primary),
                  ),
                  const SizedBox(height: AppTheme.spacingLg),
                  Text(AppStrings.t(context, 'loading_trips'), style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
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
                        Icon(Icons.route_outlined, size: 64, color: Theme.of(context).colorScheme.outline),
                        const SizedBox(height: AppTheme.spacingLg),
                        Text(_error!, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyLarge),
                        const SizedBox(height: AppTheme.spacingLg),
                        FilledButton.icon(onPressed: _load, icon: const Icon(Icons.refresh, size: 20), label: Text(AppStrings.t(context, 'retry'))),
                      ],
                    ),
                  ),
                )
              : _itineraries.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(AppTheme.spacingLg),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.route_outlined, size: 64, color: Theme.of(context).colorScheme.outline),
                            const SizedBox(height: AppTheme.spacingLg),
                            Text(AppStrings.t(context, 'no_trips_yet'), style: Theme.of(context).textTheme.titleMedium),
                            const SizedBox(height: AppTheme.spacingSm),
                            Text(
                              _isOwnTrips ? AppStrings.t(context, 'create_first_trip_to_start') : AppStrings.t(context, 'no_trips_yet'),
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                            ),
                            if (_isOwnTrips) ...[
                              const SizedBox(height: AppTheme.spacingLg),
                              FilledButton.icon(
                                onPressed: () => context.go('/create'),
                                icon: const Icon(Icons.add, size: 20),
                                label: Text(AppStrings.t(context, 'create_trip')),
                              ),
                            ],
                          ],
                        ),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(AppTheme.spacingMd),
                        itemCount: _itineraries.length,
                        itemBuilder: (_, i) {
                          final it = _itineraries[i];
                          return Card(
                            margin: const EdgeInsets.only(bottom: AppTheme.spacingMd),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                                child: Icon(Icons.route_outlined, color: Theme.of(context).colorScheme.onPrimaryContainer),
                              ),
                              title: Text(it.title, style: Theme.of(context).textTheme.titleSmall),
                              subtitle: Text('${it.destination} • ${it.daysCount} ${AppStrings.t(context, 'days')}', style: Theme.of(context).textTheme.bodySmall),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (_isOwnTrips)
                                    IconButton(
                                      icon: const Icon(Icons.edit_outlined),
                                      onPressed: () => context.push('/itinerary/${it.id}/edit'),
                                    ),
                                  Icon(Icons.chevron_right, color: Theme.of(context).colorScheme.onSurfaceVariant),
                                ],
                              ),
                              onTap: () => context.push('/itinerary/${it.id}'),
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}
