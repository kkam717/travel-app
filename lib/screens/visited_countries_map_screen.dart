import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/map_style.dart';
import '../core/theme.dart';
import '../data/countries.dart';
import '../services/countries_geojson_service.dart';
import '../services/supabase_service.dart';

class VisitedCountriesMapScreen extends StatefulWidget {
  final List<String> visitedCountryCodes;
  final bool canEdit;

  const VisitedCountriesMapScreen({super.key, required this.visitedCountryCodes, this.canEdit = false});

  @override
  State<VisitedCountriesMapScreen> createState() => _VisitedCountriesMapScreenState();
}

class _VisitedCountriesMapScreenState extends State<VisitedCountriesMapScreen> {
  List<String> _selectedCodes = [];
  Set<Polygon> _polygons = {};
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _selectedCodes = List.from(widget.visitedCountryCodes);
    _loadPolygons();
  }

  Future<void> _loadPolygons() async {
    final codes = _selectedCodes;
    if (codes.isEmpty) {
      setState(() {
        _polygons = {};
        _loading = false;
      });
      return;
    }
    try {
      final polygons = await CountriesGeoJsonService.getPolygonsForCountries(
        codes.toSet(),
      );
      if (mounted) {
        setState(() {
          _polygons = polygons;
          _loading = false;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _polygons = {};
          _loading = false;
          _error = e.toString();
        });
      }
    }
  }

  Future<void> _showEditCountries() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;
    final profile = await SupabaseService.getProfile(userId);
    Set<String> selected = (profile?.visitedCountries ?? _selectedCodes).toSet();
    if (!mounted) return;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (_, setModal) {
          return DraggableScrollableSheet(
            initialChildSize: 0.7,
            expand: false,
            builder: (_, scrollController) => Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(AppTheme.spacingMd),
                  child: Row(
                    children: [
                      Text('Edit visited countries', style: Theme.of(ctx).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                      const Spacer(),
                      TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: () async {
                          final list = selected.toList()..sort();
                          await SupabaseService.updateProfile(userId, {'visited_countries': list});
                          if (!ctx.mounted) return;
                          Navigator.pop(ctx);
                          if (!mounted) return;
                          setState(() {
                            _selectedCodes = list;
                            _loadPolygons();
                          });
                          final messenger = ScaffoldMessenger.maybeOf(context);
                          messenger?.showSnackBar(const SnackBar(content: Text('Countries updated')));
                        },
                        child: const Text('Save'),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    itemCount: countries.length,
                    itemBuilder: (_, i) {
                      final e = countries.entries.elementAt(i);
                      final sel = selected.contains(e.key);
                      return CheckboxListTile(
                        value: sel,
                        onChanged: (v) {
                          setModal(() {
                            if (v == true) {
                              selected.add(e.key);
                            } else {
                              selected.remove(e.key);
                            }
                          });
                        },
                        title: Text(e.value),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Countries visited'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        actions: [
          if (widget.canEdit)
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              onPressed: _showEditCountries,
              tooltip: 'Edit countries',
            ),
        ],
      ),
      body: Column(
        children: [
          if (_selectedCodes.isNotEmpty)
            Container(
              margin: const EdgeInsets.all(AppTheme.spacingMd),
              padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingMd, vertical: AppTheme.spacingSm),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [BoxShadow(color: Theme.of(context).colorScheme.shadow.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
              ),
              child: Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(width: AppTheme.spacingSm),
                  Text(
                    '${_selectedCodes.length} countries visited',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
          Expanded(
            child: _buildMapContent(context),
          ),
        ],
      ),
    );
  }

  Widget _buildMapContent(BuildContext context) {
    if (_loading) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(width: 40, height: 40, child: CircularProgressIndicator(strokeWidth: 2, color: Theme.of(context).colorScheme.primary)),
            const SizedBox(height: AppTheme.spacingLg),
            Text('Loading map…', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ],
        ),
      );
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 48, color: Colors.grey[400]),
              const SizedBox(height: 16),
              Text(
                'Could not load map',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.grey[700]),
              ),
              const SizedBox(height: 8),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      );
    }
    return GoogleMap(
      initialCameraPosition: const CameraPosition(
        target: LatLng(20, 0),
        zoom: 2,
      ),
      mapType: MapType.normal,
      style: googleMapsStyleJson,
      polygons: _polygons,
      onMapCreated: (ctrl) {
        if (_polygons.isNotEmpty) {
          _fitWorld(ctrl);
        }
      },
      gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
        Factory<OneSequenceGestureRecognizer>(() => EagerGestureRecognizer()),
      },
      myLocationButtonEnabled: false,
      myLocationEnabled: false,
      compassEnabled: false,
      mapToolbarEnabled: false,
      buildingsEnabled: false,
      zoomControlsEnabled: true,
    );
  }

  Future<void> _fitWorld(GoogleMapController ctrl) async {
    try {
      await ctrl.animateCamera(
        CameraUpdate.newLatLngBounds(
          LatLngBounds(
            southwest: const LatLng(-85, -180),
            northeast: const LatLng(85, 180),
          ),
          50,
        ),
      );
    } catch (_) {}
  }
}
