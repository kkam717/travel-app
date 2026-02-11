import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../core/web_tile_provider.dart';
import '../services/countries_geojson_service.dart';

/// Hero section: "Places visited" world map (Carto/OSM style) with rounded clip and shadow.
/// Overlays: top-right map control (compass), bottom-left avatar with white ring + "+" button.
/// QR and Settings are not drawn here; the parent places them over the hero.
const double kProfileHeroMapHeight = 220.0;
const double kProfileHeroMapRadius = 24.0;

class ProfileHeroMap extends StatefulWidget {
  final List<String> visitedCountryCodes;
  final String? photoUrl;
  final bool isUploadingPhoto;
  final VoidCallback? onAvatarTap;
  final VoidCallback? onMapControlTap;
  /// When the user taps the map, called with the map's global rect (for expand animation).
  final void Function(Rect? sourceRect)? onMapTap;
  final VoidCallback? onQrTap;
  final VoidCallback? onSettingsTap;
  /// Optional leading (e.g. back button) for view-profile / author screens.
  final Widget? leadingWidget;
  /// Optional trailing (e.g. follow pill); when set, replaces the default QR/Settings/Map row.
  final Widget? trailingWidget;

  const ProfileHeroMap({
    super.key,
    required this.visitedCountryCodes,
    this.photoUrl,
    this.isUploadingPhoto = false,
    this.onAvatarTap,
    this.onMapControlTap,
    this.onMapTap,
    this.onQrTap,
    this.onSettingsTap,
    this.leadingWidget,
    this.trailingWidget,
  });

  @override
  State<ProfileHeroMap> createState() => _ProfileHeroMapState();
}

class _ProfileHeroMapState extends State<ProfileHeroMap> {
  final MapController _mapController = MapController();
  final GlobalKey _mapContainerKey = GlobalKey();

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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final topInset = MediaQuery.of(context).padding.top;
    const avatarSize = 72.0;
    const avatarRingWidth = 3.0;
    const addButtonSize = 28.0;

    return SizedBox(
      height: kProfileHeroMapHeight,
      width: double.infinity,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Map hero: rounded rect + shadow; tap opens full countries map with expand animation
          Positioned.fill(
            child: GestureDetector(
              key: _mapContainerKey,
              onTap: () {
                Rect? rect;
                final box = _mapContainerKey.currentContext?.findRenderObject() as RenderBox?;
                if (box != null && box.hasSize) {
                  rect = Rect.fromLTWH(0, 0, box.size.width, box.size.height);
                  rect = rect.shift(box.localToGlobal(Offset.zero));
                }
                widget.onMapTap?.call(rect);
              },
              behavior: HitTestBehavior.opaque,
              child: FutureBuilder<List<dynamic>>(
              future: Future.wait([
                widget.visitedCountryCodes.isEmpty
                    ? Future.value(<(String, Polygon)>[])
                    : CountriesGeoJsonService.getPolygonsWithCountryCodes(widget.visitedCountryCodes.toSet()),
                CountriesGeoJsonService.getAllCountryBorderPolylines(),
              ]),
              builder: (context, snapshot) {
                List<Polygon> polygons = [];
                List<Polyline> borders = [];
                if (snapshot.hasData) {
                  final withCodes = snapshot.data![0] as List<(String, Polygon)>;
                  final teal = theme.colorScheme.primary.withValues(alpha: 0.35);
                  final borderTeal = theme.colorScheme.primary.withValues(alpha: 0.6);
                  polygons = withCodes.map((e) => Polygon(
                    points: e.$2.points,
                    holePointsList: e.$2.holePointsList,
                    color: teal,
                    borderColor: borderTeal,
                    borderStrokeWidth: 1,
                  )).toList();
                  borders = snapshot.data![1] as List<Polyline>;
                }
                final brightness = theme.brightness;
                return Container(
                  decoration: BoxDecoration(
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(kProfileHeroMapRadius),
                      bottomRight: Radius.circular(kProfileHeroMapRadius),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: theme.colorScheme.shadow.withValues(alpha: 0.08),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(kProfileHeroMapRadius),
                      bottomRight: Radius.circular(kProfileHeroMapRadius),
                    ),
                    child: IgnorePointer(
                      child: FlutterMap(
                      mapController: _mapController,
                      options: MapOptions(
                        initialCenter: const LatLng(20, 0),
                        initialZoom: 1,
                        initialRotation: 0,
                        interactionOptions: const InteractionOptions(
                          flags: InteractiveFlag.none,
                        ),
                      ),
                      children: [
                        _buildTileLayer(brightness),
                        PolylineLayer(
                          polylines: borders,
                          drawInSingleWorld: true,
                        ),
                        PolygonLayer(
                          polygons: polygons,
                          drawInSingleWorld: true,
                          simplificationTolerance: 0,
                        ),
                      ],
                    ),
                  ),
                  ),
                );
              },
            ),
            ),
          ),
          if (widget.leadingWidget != null)
            Positioned(
              top: topInset + 8,
              left: 12,
              child: widget.leadingWidget!,
            ),
          // Top-right: custom trailing or QR, Settings (compass removed; same pill style for icons)
          Positioned(
            top: topInset + 8,
            right: 12,
            child: widget.trailingWidget ?? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.onQrTap != null)
                  _TopIconButton(
                    icon: Icons.qr_code_2_outlined,
                    onPressed: widget.onQrTap!,
                    theme: theme,
                  ),
                if (widget.onQrTap != null && widget.onSettingsTap != null) const SizedBox(width: 8),
                if (widget.onSettingsTap != null)
                  _TopIconButton(
                    icon: Icons.settings_outlined,
                    onPressed: widget.onSettingsTap!,
                    theme: theme,
                  ),
              ],
            ),
          ),
          // Bottom-left: avatar with white ring + "+" button
          Positioned(
            left: 16,
            bottom: -avatarSize * 0.35,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: theme.colorScheme.surface,
                      width: avatarRingWidth,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: theme.colorScheme.shadow.withValues(alpha: 0.1),
                        blurRadius: 12,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: CircleAvatar(
                    radius: avatarSize / 2,
                    backgroundColor: theme.colorScheme.surfaceContainerHighest,
                    backgroundImage: widget.photoUrl != null && widget.photoUrl!.isNotEmpty
                        ? NetworkImage(widget.photoUrl!)
                        : null,
                    child: widget.photoUrl == null || widget.photoUrl!.isEmpty
                        ? Icon(Icons.person_outline, size: avatarSize * 0.5, color: theme.colorScheme.onSurfaceVariant)
                        : null,
                  ),
                ),
                if (widget.onAvatarTap != null)
                  Positioned(
                    right: -4,
                    bottom: -4,
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: theme.colorScheme.surfaceContainerHighest,
                        boxShadow: [
                          BoxShadow(
                            color: theme.colorScheme.shadow.withValues(alpha: 0.1),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        shape: const CircleBorder(),
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                        onTap: widget.isUploadingPhoto ? null : widget.onAvatarTap,
                        customBorder: const CircleBorder(),
                        child: SizedBox(
                          width: addButtonSize,
                          height: addButtonSize,
                          child: widget.isUploadingPhoto
                              ? Padding(
                                  padding: const EdgeInsets.all(6),
                                  child: SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: theme.colorScheme.primary,
                                    ),
                                  ),
                                )
                              : Icon(Icons.add, size: 18, color: theme.colorScheme.onSurface),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TopIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final ThemeData theme;

  const _TopIconButton({required this.icon, required this.onPressed, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: theme.colorScheme.surface.withValues(alpha: 0.92),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.shadow.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: IconButton(
          icon: Icon(icon, size: 22, color: theme.colorScheme.onSurface),
          onPressed: onPressed,
          padding: const EdgeInsets.all(10),
          constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
        ),
      ),
    );
  }
}
