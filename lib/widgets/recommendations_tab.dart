import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../core/web_tile_provider.dart';
import '../models/recommendation.dart';
import '../data/country_names_localized.dart';
import '../l10n/app_strings.dart';
import 'country_filter_chips.dart';

/// Profile tab: list or map of the user's 5-star recommended places.
class RecommendationsTab extends StatefulWidget {
  final List<Recommendation> recommendations;

  const RecommendationsTab({
    super.key,
    required this.recommendations,
  });

  @override
  State<RecommendationsTab> createState() => _RecommendationsTabState();
}

class _RecommendationsTabState extends State<RecommendationsTab> {
  String? _selectedCountryCode;
  bool _showMap = false;

  /// Country code → number of recommendations.
  Map<String, int> _countryCodeCounts() {
    final counts = <String, int>{};
    for (final rec in widget.recommendations) {
      final code = rec.countryCode;
      if (code != null && code.isNotEmpty) {
        counts[code] = (counts[code] ?? 0) + 1;
      }
    }
    return counts;
  }

  List<Recommendation> _filtered() {
    if (_selectedCountryCode == null) return widget.recommendations;
    return widget.recommendations
        .where((r) => r.countryCode == _selectedCountryCode)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final recs = widget.recommendations;

    // ── Empty state ──────────────────────────────────────────────────────
    if (recs.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.star_outline_rounded,
                  size: 64, color: theme.colorScheme.outline),
              const SizedBox(height: 16),
              Text(
                AppStrings.t(context, 'no_recommendations_yet'),
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                AppStrings.t(context, 'recommendations_hint'),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    // ── Populated state ──────────────────────────────────────────────────
    final countryCounts = _countryCodeCounts();
    final filtered = _filtered();

    return CustomScrollView(
      key: const PageStorageKey('recommendations'),
      slivers: [
        // Country chips + List / Map toggle
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: _CountryChipsWithCounts(
                    countryCounts: countryCounts,
                    selectedCode: _selectedCountryCode,
                    onSelected: (code) =>
                        setState(() => _selectedCountryCode = code),
                  ),
                ),
                const SizedBox(width: 8),
                _ListMapToggle(
                  showMap: _showMap,
                  onToggle: (v) => setState(() => _showMap = v),
                ),
              ],
            ),
          ),
        ),

        // Content — list or map
        if (_showMap)
          SliverFillRemaining(
            child: _RecommendationsMapView(recommendations: filtered),
          )
        else ...[
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) =>
                  _RecommendationCard(recommendation: filtered[index]),
              childCount: filtered.length,
            ),
          ),
          // Bottom padding so content isn't hidden behind bottom nav
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Country chips with counts  (e.g. 🇫🇷 France (12))
// ─────────────────────────────────────────────────────────────────────────────

class _CountryChipsWithCounts extends StatelessWidget {
  final Map<String, int> countryCounts;
  final String? selectedCode;
  final ValueChanged<String?> onSelected;

  const _CountryChipsWithCounts({
    required this.countryCounts,
    this.selectedCode,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final codes = countryCounts.keys.toList()..sort();
    if (codes.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 32,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.zero,
        itemCount: codes.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final code = codes[i];
          final name = getCountryName(context, code);
          final count = countryCounts[code] ?? 0;
          final isSelected = selectedCode == code;
          final bg = isSelected
              ? cs.primary
              : cs.surfaceContainerHighest;
          final fg = isSelected ? cs.onPrimary : cs.onSurface;

          return GestureDetector(
            onTap: () => onSelected(isSelected ? null : code),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: bg,
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: cs.shadow.withValues(alpha: 0.12),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ]
                    : null,
              ),
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    CountryFilterChips.flagEmoji(code),
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontSize: 13,
                      height: 1.0,
                      color: fg,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${name.length > 10 ? '${name.substring(0, 10)}…' : name} ($count)',
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                      color: fg,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// List / Map toggle
// ─────────────────────────────────────────────────────────────────────────────

class _ListMapToggle extends StatelessWidget {
  final bool showMap;
  final ValueChanged<bool> onToggle;

  const _ListMapToggle({required this.showMap, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    Widget chip(String label, bool active, VoidCallback onTap) {
      return GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: active ? cs.primary : cs.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w600,
              fontSize: 12,
              color: active ? cs.onPrimary : cs.onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: cs.surfaceContainerHighest,
      ),
      padding: const EdgeInsets.all(2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          chip(AppStrings.t(context, 'list_view'), !showMap,
              () => onToggle(false)),
          const SizedBox(width: 2),
          chip(AppStrings.t(context, 'map_view'), showMap,
              () => onToggle(true)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Single recommendation card (Task A + B)
// ─────────────────────────────────────────────────────────────────────────────

class _RecommendationCard extends StatelessWidget {
  final Recommendation recommendation;

  const _RecommendationCard({required this.recommendation});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rec = recommendation;
    final categoryLabel = _localizedCategory(context, rec.displayCategory);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Container(
        decoration: BoxDecoration(
          color: theme.brightness == Brightness.light
              ? Colors.white
              : theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: theme.colorScheme.shadow.withValues(alpha: 0.06),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // ── Thumbnail ──────────────────────────────────────────
              _RecThumbnail(
                imageUrl: rec.imageUrl,
                category: rec.displayCategory,
                name: rec.name,
              ),
              const SizedBox(width: 14),
              // ── Info ────────────────────────────────────────────────
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Name
                    Text(
                      rec.name,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    // Category · City
                    Text(
                      rec.city != null
                          ? '$categoryLabel · ${rec.city}'
                          : categoryLabel,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    // Star rating
                    Row(
                      children: [
                        Icon(Icons.star_rounded,
                            size: 16, color: Colors.amber.shade700),
                        const SizedBox(width: 4),
                        Text(
                          rec.rating.toStringAsFixed(1),
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _localizedCategory(BuildContext context, String category) {
    switch (category) {
      case 'Eat':
        return AppStrings.t(context, 'eat');
      case 'Drink':
        return AppStrings.t(context, 'drink');
      case 'Stay':
        return AppStrings.t(context, 'stay');
      default:
        return AppStrings.t(context, 'guide');
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Recommendation thumbnail (72×72, rounded, image or category fallback)
// ─────────────────────────────────────────────────────────────────────────────

class _RecThumbnail extends StatelessWidget {
  final String? imageUrl;
  final String category;
  final String name;

  static const double size = 72;
  static const double radius = 14;

  const _RecThumbnail({
    this.imageUrl,
    required this.category,
    required this.name,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        color: _categoryColor(theme, category),
      ),
      clipBehavior: Clip.antiAlias,
      child: imageUrl != null && imageUrl!.isNotEmpty
          ? Image.network(
              imageUrl!,
              fit: BoxFit.cover,
              width: size,
              height: size,
              frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
                if (wasSynchronouslyLoaded || frame != null) return child;
                return _fallback(theme);
              },
              errorBuilder: (_, __, ___) => _fallback(theme),
            )
          : _fallback(theme),
    );
  }

  Widget _fallback(ThemeData theme) {
    return Center(
      child: Icon(
        _categoryIcon(category),
        size: 30,
        color: _categoryIconColor(theme, category),
      ),
    );
  }

  static Color _categoryColor(ThemeData theme, String category) {
    final isDark = theme.brightness == Brightness.dark;
    switch (category) {
      case 'Eat':
        return isDark ? const Color(0xFF2D2520) : const Color(0xFFFFF3E0);
      case 'Drink':
        return isDark ? const Color(0xFF1E2530) : const Color(0xFFE3F2FD);
      case 'Stay':
        return isDark ? const Color(0xFF252028) : const Color(0xFFF3E5F5);
      default:
        return isDark ? const Color(0xFF202528) : const Color(0xFFE0F2F1);
    }
  }

  static Color _categoryIconColor(ThemeData theme, String category) {
    switch (category) {
      case 'Eat':
        return Colors.orange.shade700;
      case 'Drink':
        return Colors.blue.shade600;
      case 'Stay':
        return Colors.purple.shade400;
      default:
        return theme.colorScheme.primary;
    }
  }

  static IconData _categoryIcon(String category) {
    switch (category) {
      case 'Eat':
        return Icons.restaurant_outlined;
      case 'Drink':
        return Icons.local_bar_outlined;
      case 'Stay':
        return Icons.hotel_outlined;
      default:
        return Icons.explore_outlined;
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Recommendations Map View (Task C)
// ─────────────────────────────────────────────────────────────────────────────

class _RecommendationsMapView extends StatefulWidget {
  final List<Recommendation> recommendations;

  const _RecommendationsMapView({required this.recommendations});

  @override
  State<_RecommendationsMapView> createState() =>
      _RecommendationsMapViewState();
}

class _RecommendationsMapViewState extends State<_RecommendationsMapView> {
  final MapController _mapController = MapController();
  Recommendation? _selected;

  List<Recommendation> get _mappable =>
      widget.recommendations.where((r) => r.lat != null && r.lng != null).toList();

  /// Compute a bounding box for the markers, with some padding.
  LatLngBounds? _bounds(List<Recommendation> recs) {
    if (recs.isEmpty) return null;
    double minLat = 90, maxLat = -90, minLng = 180, maxLng = -180;
    for (final r in recs) {
      if (r.lat! < minLat) minLat = r.lat!;
      if (r.lat! > maxLat) maxLat = r.lat!;
      if (r.lng! < minLng) minLng = r.lng!;
      if (r.lng! > maxLng) maxLng = r.lng!;
    }
    // Add small padding so markers aren't right at the edge
    const pad = 0.5;
    return LatLngBounds(
      LatLng(minLat - pad, minLng - pad),
      LatLng(maxLat + pad, maxLng + pad),
    );
  }

  TileLayer _buildTileLayer(Brightness brightness) {
    final style =
        brightness == Brightness.dark ? 'dark_all' : 'light_all';
    final isRetina = MediaQuery.of(context).devicePixelRatio > 1.0;
    final TileProvider tileProvider = kIsWeb
        ? WebTileProvider()
        : NetworkTileProvider(
            cachingProvider: const DisabledMapCachingProvider());
    return TileLayer(
      urlTemplate:
          'https://a.basemaps.cartocdn.com/rastertiles/$style/{z}/{x}/{y}{r}.png',
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mappable = _mappable;

    // ── Empty: no coordinates ────────────────────────────────────────────
    if (mappable.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.location_off_outlined,
                  size: 64, color: theme.colorScheme.outline),
              const SizedBox(height: 16),
              Text(
                AppStrings.t(context, 'no_mappable_recommendations'),
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                AppStrings.t(context, 'add_places_with_locations'),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    // ── Map with markers ─────────────────────────────────────────────────
    final bounds = _bounds(mappable);
    final initialCenter = bounds != null
        ? LatLng(
            (bounds.south + bounds.north) / 2,
            (bounds.west + bounds.east) / 2,
          )
        : LatLng(mappable.first.lat!, mappable.first.lng!);

    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: initialCenter,
            initialZoom: mappable.length == 1 ? 12 : 4,
            onTap: (_, __) {
              if (_selected != null) setState(() => _selected = null);
            },
            onMapReady: () {
              if (bounds != null && mappable.length > 1) {
                _mapController.fitCamera(
                  CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(48)),
                );
              }
            },
          ),
          children: [
            _buildTileLayer(theme.brightness),
            MarkerLayer(
              markers: mappable.map((rec) {
                final isSelected = _selected?.stopId == rec.stopId;
                return Marker(
                  point: LatLng(rec.lat!, rec.lng!),
                  width: isSelected ? 44 : 36,
                  height: isSelected ? 44 : 36,
                  child: GestureDetector(
                    onTap: () => setState(() => _selected = rec),
                    child: _MapPin(
                      category: rec.displayCategory,
                      isSelected: isSelected,
                      theme: theme,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),

        // ── Selected marker preview card ─────────────────────────────────
        if (_selected != null)
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: _MapPreviewCard(
              recommendation: _selected!,
              onClose: () => setState(() => _selected = null),
            ),
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Map pin marker
// ─────────────────────────────────────────────────────────────────────────────

class _MapPin extends StatelessWidget {
  final String category;
  final bool isSelected;
  final ThemeData theme;

  const _MapPin({
    required this.category,
    required this.isSelected,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final color = isSelected
        ? theme.colorScheme.primary
        : theme.colorScheme.primary.withValues(alpha: 0.85);
    final iconSize = isSelected ? 20.0 : 16.0;

    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        border: Border.all(
          color: Colors.white,
          width: isSelected ? 3 : 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: Icon(
          _RecThumbnail._categoryIcon(category),
          size: iconSize,
          color: Colors.white,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Bottom card preview when a marker is tapped
// ─────────────────────────────────────────────────────────────────────────────

class _MapPreviewCard extends StatelessWidget {
  final Recommendation recommendation;
  final VoidCallback onClose;

  const _MapPreviewCard({
    required this.recommendation,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rec = recommendation;

    final categoryLabel = _localizedCat(context, rec.displayCategory);

    return Material(
      elevation: 8,
      shadowColor: Colors.black.withValues(alpha: 0.18),
      borderRadius: BorderRadius.circular(20),
      color: theme.brightness == Brightness.light
          ? Colors.white
          : theme.colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            // Thumbnail
            _RecThumbnail(
              imageUrl: rec.imageUrl,
              category: rec.displayCategory,
              name: rec.name,
            ),
            const SizedBox(width: 12),
            // Info
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    rec.name,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    rec.city != null
                        ? '$categoryLabel · ${rec.city}'
                        : categoryLabel,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.star_rounded,
                          size: 14, color: Colors.amber.shade700),
                      const SizedBox(width: 3),
                      Text(
                        rec.rating.toStringAsFixed(1),
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onSurface,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Close button
            IconButton(
              onPressed: onClose,
              icon: Icon(Icons.close_rounded,
                  size: 20, color: theme.colorScheme.onSurfaceVariant),
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              padding: EdgeInsets.zero,
            ),
          ],
        ),
      ),
    );
  }

  String _localizedCat(BuildContext context, String category) {
    switch (category) {
      case 'Eat':
        return AppStrings.t(context, 'eat');
      case 'Drink':
        return AppStrings.t(context, 'drink');
      case 'Stay':
        return AppStrings.t(context, 'stay');
      default:
        return AppStrings.t(context, 'guide');
    }
  }
}
