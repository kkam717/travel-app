import 'package:flutter/painting.dart';
import 'package:flutter_map/flutter_map.dart';

/// Tile provider that uses [NetworkImage] for tile loading.
///
/// On web, the default [NetworkTileProvider] uses HTTP requests which are
/// subject to CORS. [NetworkImage] uses img tags which bypass CORS for
/// display. Use this provider on web when tile servers block cross-origin
/// requests.
class WebTileProvider extends TileProvider {
  WebTileProvider({super.headers});

  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) {
    final url = getTileUrl(coordinates, options);
    return NetworkImage(url);
  }
}
