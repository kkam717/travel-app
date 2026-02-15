import 'dart:async';
import 'dart:ui';
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
import '../models/itinerary.dart';
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
  List<(String, Polygon)> _polygonsWithCodes = [];
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
          ? Future.value(<(String, Polygon)>[])
          : CountriesGeoJsonService.getPolygonsWithCountryCodes(_selectedCodes.toSet());

      final results = await Future.wait([bordersFuture, polygonsFuture]);
      final borders = results[0] as List<Polyline>;
      final withCodes = results[1] as List<(String, Polygon)>;

      if (mounted) {
        setState(() {
          _countryBorders = borders;
          _polygonsWithCodes = withCodes;
          _polygons = withCodes.map((e) => e.$2).toList();
          _loading = false;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _countryBorders = [];
          _polygonsWithCodes = [];
          _polygons = [];
          _loading = false;
          _error = e.toString();
        });
      }
    }
  }

  void _onMapTap(LatLng point) {
    String? tappedCode;
    for (final entry in _polygonsWithCodes) {
      final code = entry.$1;
      final polygon = entry.$2;
      if (CountriesGeoJsonService.pointInPolygon(point, polygon.points)) {
        tappedCode = code;
        break;
      }
    }
    if (tappedCode == null) return;
    _showItinerariesForCountry(tappedCode);
  }

  Future<void> _showItinerariesForCountry(String countryCode) async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;
    final countryName = countries[countryCode] ?? countryCode;
    List<Itinerary> all;
    try {
      all = await SupabaseService.getUserItineraries(userId, publicOnly: false);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppStrings.t(context, 'could_not_load_map') ?? 'Could not load')),
      );
      return;
    }
    final forCountry = all.where((it) {
      final dest = (it.destination).trim().toLowerCase();
      final name = countryName.toLowerCase();
      if (dest == name) return true;
      return dest.split(',').map((s) => s.trim()).any((s) => s == name || s.contains(name) || name.contains(s));
    }).toList();
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      builder: (ctx) => _CountryItinerariesSheet(
        countryName: countryName,
        itineraries: forCountry,
        onTapItinerary: (it) {
          Navigator.pop(ctx);
          context.push('/itinerary/${it.id}');
        },
      ),
    );
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

  /// Carto basemap: light_nolabels (day) / dark_nolabels (night).
  /// On web, use WebTileProvider to bypass CORS. tileBounds restricts to single world.
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

  /// Frosted-glass floating button used for back, edit, and compass controls.
  Widget _buildGlassButton({
    required IconData icon,
    required VoidCallback onPressed,
    String? tooltip,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return ClipOval(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Material(
          color: isDark
              ? Colors.black.withValues(alpha: 0.45)
              : Colors.white.withValues(alpha: 0.75),
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onPressed,
            child: Tooltip(
              message: tooltip ?? '',
              child: SizedBox(
                width: 44,
                height: 44,
                child: Icon(
                  icon,
                  size: 20,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Frosted-glass pill showing visited-country count.
  Widget _buildCountPill(ThemeData theme) {
    if (_selectedCodes.isEmpty) return const SizedBox.shrink();
    final isDark = theme.brightness == Brightness.dark;
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.black.withValues(alpha: 0.45)
                : Colors.white.withValues(alpha: 0.75),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.black.withValues(alpha: 0.06),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${_selectedCodes.length}',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                AppStrings.t(context, 'countries_visited_short'),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final topPadding = MediaQuery.of(context).padding.top;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      body: Stack(
        children: [
          // Full-bleed map
          Positioned.fill(
            child: _buildMapContent(context),
          ),

          // Loading / error overlays
          if (_loading)
            Positioned.fill(
              child: Container(
                color: theme.scaffoldBackgroundColor,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 40,
                        height: 40,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: AppTheme.spacingLg),
                      Text(
                        AppStrings.t(context, 'loading_map'),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          if (_error != null && !_loading)
            Positioned.fill(
              child: Container(
                color: theme.scaffoldBackgroundColor,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.map_outlined, size: 48, color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4)),
                        const SizedBox(height: 16),
                        Text(
                          AppStrings.t(context, 'could_not_load_map'),
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

          // Top-left: back button
          Positioned(
            top: topPadding + 12,
            left: 16,
            child: _buildGlassButton(
              icon: Icons.arrow_back_rounded,
              onPressed: () => context.pop(),
            ),
          ),

          // Top-right: action buttons (compass + edit)
          Positioned(
            top: topPadding + 12,
            right: 16,
            child: Column(
              children: [
                _buildGlassButton(
                  icon: Icons.explore_outlined,
                  tooltip: AppStrings.t(context, 'reset_north'),
                  onPressed: () {
                    try { _mapController.rotate(0); } catch (_) {}
                  },
                ),
                if (widget.canEdit) ...[
                  const SizedBox(height: 10),
                  _buildGlassButton(
                    icon: Icons.edit_outlined,
                    tooltip: AppStrings.t(context, 'edit_countries'),
                    onPressed: _showEditCountries,
                  ),
                ],
              ],
            ),
          ),

          // Bottom: count pill + attribution
          Positioned(
            left: 16,
            right: 16,
            bottom: bottomPadding + 16,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _buildCountPill(theme),
                const Spacer(),
                Text(
                  '© CARTO | OSM',
                  style: TextStyle(
                    fontSize: 9,
                    color: theme.brightness == Brightness.dark
                        ? Colors.grey.shade500
                        : Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMapContent(BuildContext context) {
    if (_loading || _error != null) {
      // Return an empty container; overlays handle loading/error display
      return const SizedBox.expand();
    }
    final brightness = Theme.of(context).brightness;
    final theme = Theme.of(context);
    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: const LatLng(20, 0),
        initialZoom: 2,
        initialRotation: 0,
        crs: const Epsg3857NoWrap(),
        cameraConstraint: const CameraConstraint.containLatitude(),
        onTap: (_, point) => _onMapTap(point),
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
          polygons: _polygons.map((p) => Polygon(
            points: p.points,
            holePointsList: p.holePointsList,
            color: theme.colorScheme.primary.withValues(alpha: 0.35),
            borderColor: theme.colorScheme.primary.withValues(alpha: 0.6),
            borderStrokeWidth: 1,
          )).toList(),
          drawInSingleWorld: true,
          simplificationTolerance: 0,
        ),
      ],
    );
  }
}

/// Bottom sheet listing saved itineraries for a country; each row opens the itinerary.
class _CountryItinerariesSheet extends StatelessWidget {
  final String countryName;
  final List<Itinerary> itineraries;
  final void Function(Itinerary it) onTapItinerary;

  const _CountryItinerariesSheet({
    required this.countryName,
    required this.itineraries,
    required this.onTapItinerary,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppTheme.spacingMd,
        AppTheme.spacingMd,
        AppTheme.spacingMd,
        MediaQuery.viewPaddingOf(context).bottom + AppTheme.spacingMd,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Itineraries in $countryName',
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          if (itineraries.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Text(
                'No saved itineraries for this country.',
                style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            )
          else
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 320),
              child: ListView.builder(
                itemCount: itineraries.length,
                itemBuilder: (_, i) {
                  final it = itineraries[i];
                  return ListTile(
                    title: Text(it.title),
                    subtitle: Text('${it.destination} · ${it.daysCount} days'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => onTapItinerary(it),
                  );
                },
              ),
            ),
        ],
      ),
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
