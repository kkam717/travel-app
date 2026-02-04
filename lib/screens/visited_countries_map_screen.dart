import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/theme.dart';
import '../core/profile_cache.dart';
import '../core/web_tile_provider.dart';
import '../data/countries.dart';
import '../l10n/app_strings.dart';
import '../services/countries_geojson_service.dart';
import '../services/supabase_service.dart';

/// CRS that disables world wrap (no horizontal looping).
class Epsg3857NoWrap extends Epsg3857 {
  const Epsg3857NoWrap();
  @override
  bool get replicatesWorldLongitude => false;
}

class VisitedCountriesMapScreen extends StatefulWidget {
  final List<String> visitedCountryCodes;
  final bool canEdit;

  const VisitedCountriesMapScreen({super.key, required this.visitedCountryCodes, this.canEdit = false});

  @override
  State<VisitedCountriesMapScreen> createState() => _VisitedCountriesMapScreenState();
}

class _VisitedCountriesMapScreenState extends State<VisitedCountriesMapScreen> {
  List<String> _selectedCodes = [];
  List<Polygon> _polygons = [];
  List<Polyline> _countryBorders = [];
  bool _loading = true;
  String? _error;
  final _mapController = MapController();

  @override
  void initState() {
    super.initState();
    _selectedCodes = List.from(widget.visitedCountryCodes);
    _loadPolygons();
  }

  Future<void> _loadPolygons() async {
    try {
      final bordersFuture = CountriesGeoJsonService.getAllCountryBorderPolylines();
      final polygonsFuture = _selectedCodes.isEmpty
          ? Future.value(<Polygon>[])
          : CountriesGeoJsonService.getPolygonsForCountries(_selectedCodes.toSet());

      final results = await Future.wait([bordersFuture, polygonsFuture]);
      final borders = results[0] as List<Polyline>;
      final polygons = results[1] as List<Polygon>;

      if (mounted) {
        setState(() {
          _countryBorders = borders;
          _polygons = polygons;
          _loading = false;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _countryBorders = [];
          _polygons = [];
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
                      Text(AppStrings.t(context, 'edit_visited_countries'), style: Theme.of(ctx).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                      const Spacer(),
                      TextButton(onPressed: () => Navigator.pop(ctx), child: Text(AppStrings.t(context, 'cancel'))),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: () async {
                          final list = selected.toList()..sort();
                          await SupabaseService.updateProfile(userId, {'visited_countries': list});
                          if (!ctx.mounted) return;
                          Navigator.pop(ctx);
                          if (!mounted) return;
                          ProfileCache.updateVisitedCountries(userId, list);
                          setState(() {
                            _selectedCodes = list;
                            _loadPolygons();
                          });
                          final messenger = ScaffoldMessenger.maybeOf(context);
                          messenger?.showSnackBar(SnackBar(content: Text(AppStrings.t(context, 'countries_updated'))));
                        },
                        child: Text(AppStrings.t(context, 'save')),
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

  /// No labels: Carto light_nolabels (day) / dark_nolabels (night) removes all map text.
  /// On web, use WebTileProvider to bypass CORS. On iOS simulator, disable tile cache to avoid native crash.
  /// tileBounds restricts tiles to single world (-180..180) so underlying map doesn't spill.
  TileLayer _buildTileLayer(Brightness brightness) {
    final style = brightness == Brightness.dark ? 'dark_nolabels' : 'light_nolabels';
    final TileProvider tileProvider = kIsWeb
        ? WebTileProvider()
        : NetworkTileProvider(cachingProvider: const DisabledMapCachingProvider());
    return TileLayer(
      urlTemplate: 'https://a.basemaps.cartocdn.com/rastertiles/$style/{z}/{x}/{y}.png',
      userAgentPackageName: 'com.footprint.travel',
      maxNativeZoom: 20,
      tileProvider: tileProvider,
      tileBounds: LatLngBounds(
        const LatLng(-85, -180),
        const LatLng(85, 180),
      ),
    );
  }

  void _fitWorld() {
    try {
      _mapController.fitCamera(
        CameraFit.bounds(
          bounds: LatLngBounds(
            const LatLng(-85, -180),
            const LatLng(85, 180),
          ),
          padding: const EdgeInsets.all(50),
        ),
      );
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppStrings.t(context, 'countries_visited')),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        actions: [
          if (widget.canEdit)
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              onPressed: _showEditCountries,
              tooltip: AppStrings.t(context, 'edit_countries'),
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
            Text(AppStrings.t(context, 'loading_map'), style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
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
                AppStrings.t(context, 'could_not_load_map'),
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
    final brightness = Theme.of(context).brightness;
    final theme = Theme.of(context);
    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: const LatLng(20, 0),
            initialZoom: 2,
            initialRotation: 0,
            crs: const Epsg3857NoWrap(),
            cameraConstraint: const CameraConstraint.containLatitude(),
            onMapReady: () {
              try { _mapController.rotate(0); } catch (_) {}
              if (_polygons.isNotEmpty) _fitWorld();
              // Zoom wiggle forces tile redraw (flutter_map #1813 – grey until touch)
              Future.delayed(const Duration(milliseconds: 200), () async {
                if (!mounted) return;
                try {
                  final c = _mapController.camera;
                  _mapController.move(c.center, c.zoom + 0.02);
                  await Future.delayed(const Duration(milliseconds: 80));
                  if (!mounted) return;
                  _mapController.move(c.center, c.zoom);
                  _mapController.rotate(0);
                } catch (_) {}
              });
            },
            interactionOptions: const InteractionOptions(flags: InteractiveFlag.all),
          ),
          children: [
            _buildTileLayer(brightness),
            PolylineLayer(
              polylines: _countryBorders,
              drawInSingleWorld: true,
            ),
            PolygonLayer(
              polygons: _polygons,
              drawInSingleWorld: true,
              simplificationTolerance: 0,
            ),
            Align(
              alignment: Alignment.bottomRight,
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 120),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.bottomRight,
                    child: Text(
                      '© CARTO | OSM',
                      style: TextStyle(fontSize: 8, color: brightness == Brightness.dark ? Colors.grey.shade400 : Colors.grey.shade600),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        Positioned(
          top: 12,
          right: 12,
          child: Material(
            color: theme.colorScheme.surface.withValues(alpha: 0.9),
            shape: const CircleBorder(),
            clipBehavior: Clip.antiAlias,
            elevation: 1,
            child: IconButton(
              icon: const Icon(Icons.explore),
              tooltip: 'Reset to north',
              onPressed: () {
                try {
                  _mapController.rotate(0);
                } catch (_) {}
              },
            ),
          ),
        ),
      ],
    );
  }
}
