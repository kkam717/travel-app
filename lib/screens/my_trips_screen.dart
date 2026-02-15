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
        title: Text(
          _isOwnTrips ? AppStrings.t(context, 'my_trips') : AppStrings.t(context, 'trips'),
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
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
                            Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(24),
                              ),
                              child: Icon(Icons.route_rounded, size: 40, color: Theme.of(context).colorScheme.primary),
                            ),
                            const SizedBox(height: AppTheme.spacingLg),
                            Text(AppStrings.t(context, 'no_trips_yet'), style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
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
                        padding: const EdgeInsets.fromLTRB(AppTheme.spacingLg, AppTheme.spacingMd, AppTheme.spacingLg, AppTheme.spacingXl),
                        itemCount: _itineraries.length,
                        itemBuilder: (_, i) {
                          final it = _itineraries[i];
                          final cs = Theme.of(context).colorScheme;
                          final cardColor = Theme.of(context).brightness == Brightness.light
                              ? Colors.white
                              : cs.surfaceContainerHighest;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: AppTheme.spacingMd),
                            child: Container(
                              decoration: BoxDecoration(
                                color: cardColor,
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                    color: cs.shadow.withValues(alpha: 0.06),
                                    blurRadius: 16,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Material(
                                color: Colors.transparent,
                                borderRadius: BorderRadius.circular(20),
                                child: InkWell(
                                  onTap: () => context.push('/itinerary/${it.id}'),
                                  borderRadius: BorderRadius.circular(20),
                                  child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 48,
                                          height: 48,
                                          decoration: BoxDecoration(
                                            color: cs.primary.withValues(alpha: 0.10),
                                            borderRadius: BorderRadius.circular(14),
                                          ),
                                          child: Icon(Icons.route_rounded, color: cs.primary, size: 22),
                                        ),
                                        const SizedBox(width: 14),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                it.title,
                                                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                                  fontWeight: FontWeight.w700,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                '${it.destination} · ${it.daysCount} ${AppStrings.t(context, 'days')}',
                                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                                  color: cs.onSurfaceVariant,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ],
                                          ),
                                        ),
                                        if (_isOwnTrips)
                                          Container(
                                            decoration: BoxDecoration(
                                              color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
                                              borderRadius: BorderRadius.circular(10),
                                            ),
                                            child: IconButton(
                                              icon: Icon(Icons.edit_outlined, size: 18, color: cs.onSurfaceVariant),
                                              onPressed: () => context.push('/itinerary/${it.id}/edit'),
                                              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                                              padding: const EdgeInsets.all(8),
                                            ),
                                          ),
                                        const SizedBox(width: 4),
                                        Icon(Icons.chevron_right_rounded, color: cs.onSurfaceVariant, size: 20),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}
