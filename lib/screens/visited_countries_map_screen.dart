import 'dart:async';
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
    final initialSelected = (profile?.visitedCountries ?? _selectedCodes).toSet().toList();
    if (!mounted) return;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _EditCountriesSheetContent(
        initialSelected: initialSelected,
        onSave: (list) async {
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
        onCancel: () => Navigator.pop(ctx),
      ),
    );
  }

  /// No labels: Carto light_nolabels (day) / dark_nolabels (night) removes all map text.
  /// On web, use WebTileProvider to bypass CORS. On iOS simulator, disable tile cache to avoid native crash.
  /// tileBounds restricts tiles to single world (-180..180) so underlying map doesn't spill.
  TileLayer _buildTileLayer(Brightness brightness) {
    final style = brightness == Brightness.dark ? 'dark_nolabels' : 'light_nolabels';
    final isRetina = MediaQuery.of(context).devicePixelRatio > 1.0;
    final TileProvider tileProvider = kIsWeb
        ? WebTileProvider()
        : NetworkTileProvider(cachingProvider: const DisabledMapCachingProvider());
    return TileLayer(
      urlTemplate: 'https://a.basemaps.cartocdn.com/rastertiles/$style/{z}/{x}/{y}{r}.png',
      userAgentPackageName: 'com.footprint.travel',
      maxNativeZoom: 20,
      tileProvider: tileProvider,
      retinaMode: isRetina,
      tileDimension: isRetina ? 512 : 256,
      zoomOffset: isRetina ? -1.0 : 0.0,
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

/// Sheet content for editing visited countries using API search (countries only).
class _EditCountriesSheetContent extends StatefulWidget {
  final List<String> initialSelected;
  final void Function(List<String>) onSave;
  final VoidCallback onCancel;

  const _EditCountriesSheetContent({
    required this.initialSelected,
    required this.onSave,
    required this.onCancel,
  });

  @override
  State<_EditCountriesSheetContent> createState() => _EditCountriesSheetContentState();
}

class _EditCountriesSheetContentState extends State<_EditCountriesSheetContent> {
  late Set<String> _selected;
  final _searchController = TextEditingController();
  String _searchQuery = '';
  List<MapEntry<String, String>> _countryList = [];
  Map<String, String> _countryNameByCode = {};
  List<MapEntry<String, String>> _filteredResults = [];
  bool _loading = true;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _selected = widget.initialSelected.toSet();
    _loadCountryList();
  }

  Future<void> _loadCountryList() async {
    try {
      final list = await CountriesGeoJsonService.getCountryListFromGeoJson();
      if (!mounted) return;
      setState(() {
        _countryList = list;
        _countryNameByCode = Map.fromEntries(list);
        _loading = false;
        _filteredResults = _applyFilter(_searchQuery, list);
      });
    } catch (e) {
      if (mounted) setState(() {
        _loading = false;
        _loadError = e.toString();
        _countryList = [];
        _filteredResults = [];
      });
    }
  }

  List<MapEntry<String, String>> _applyFilter(String query, List<MapEntry<String, String>> list) {
    final q = query.trim().toLowerCase();
    if (q.length < 2) return [];
    return list.where((e) => e.value.toLowerCase().contains(q)).toList();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String v) {
    setState(() {
      _searchQuery = v;
      _filteredResults = _applyFilter(v, _countryList);
    });
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      expand: false,
      builder: (_, scrollController) => Padding(
        padding: EdgeInsets.fromLTRB(AppTheme.spacingMd, AppTheme.spacingMd, AppTheme.spacingMd, MediaQuery.viewPaddingOf(context).bottom + AppTheme.spacingMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text(AppStrings.t(context, 'edit_visited_countries'), style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                const Spacer(),
                TextButton(onPressed: widget.onCancel, child: Text(AppStrings.t(context, 'cancel'))),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: () {
                    final list = _selected.toList()..sort();
                    widget.onSave(list);
                  },
                  child: Text(AppStrings.t(context, 'save')),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: AppStrings.t(context, 'search_and_add_countries'),
                prefixIcon: const Icon(Icons.search_outlined, size: 20),
                suffixIcon: _loading
                    ? Padding(
                        padding: const EdgeInsets.all(10),
                        child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Theme.of(context).colorScheme.primary)),
                      )
                    : null,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                isDense: true,
              ),
              onChanged: _onSearchChanged,
            ),
            if (_selected.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: _selected.map((code) {
                  final name = _countryNameByCode[code] ?? countries[code] ?? code;
                  return Chip(
                    label: Text(name),
                    deleteIcon: Icon(Icons.close, size: 18, color: Theme.of(context).colorScheme.onSurfaceVariant),
                    onDeleted: () => setState(() => _selected.remove(code)),
                  );
                }).toList(),
              ),
            ],
            const SizedBox(height: 12),
            Expanded(
              child: _loading
                  ? Center(child: CircularProgressIndicator(color: Theme.of(context).colorScheme.primary))
                  : _loadError != null
                      ? Center(child: Text(_loadError!, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.error)))
                      : _searchQuery.trim().length < 2
                          ? Center(
                              child: Text(
                                AppStrings.t(context, 'search_and_add_countries'),
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                              ),
                            )
                          : ListView.builder(
                              controller: scrollController,
                              itemCount: _filteredResults.length,
                              itemBuilder: (_, i) {
                                final entry = _filteredResults[i];
                                final code = entry.key;
                                final name = entry.value;
                                final added = _selected.contains(code);
                                return ListTile(
                                  leading: Icon(added ? Icons.check_circle : Icons.add_circle_outline, size: 22, color: added ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.onSurfaceVariant),
                                  title: Text(name, style: Theme.of(context).textTheme.bodyMedium),
                                  onTap: added ? null : () => setState(() => _selected.add(code)),
                                );
                              },
                            ),
            ),
          ],
        ),
      ),
    );
  }
}
