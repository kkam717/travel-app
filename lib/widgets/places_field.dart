import 'dart:async';
import 'package:flutter/material.dart';
import '../services/places_service.dart';

/// Place search field using Photon (OSM). Replaces GooglePlacesField.
/// [onSelected] receives (name, lat, lng, url, countryCode). [countryCode] is from the API when available.
class PlacesField extends StatefulWidget {
  final String hint;
  final void Function(String name, double? lat, double? lng, String? locationUrl, String? countryCode) onSelected;
  final String? placeType;
  final List<String>? countryCodes;
  final (double, double)? locationLatLng;
  /// Optional bbox "left,bottom,right,top" to restrict suggestions to a region (e.g. city).
  final String? bbox;
  /// UI language code for autofill suggestions (e.g. from Localizations.localeOf(context).languageCode).
  final String? lang;

  const PlacesField({
    super.key,
    required this.hint,
    required this.onSelected,
    this.placeType,
    this.countryCodes,
    this.locationLatLng,
    this.bbox,
    this.lang,
  });

  @override
  State<PlacesField> createState() => _PlacesFieldState();
}

class _PlacesFieldState extends State<PlacesField> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  List<PlacePrediction> _predictions = [];
  bool _isLoading = false;
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _search(String query) {
    _debounce?.cancel();
    if (query.trim().length < 2) {
      setState(() => _predictions = []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 400), () async {
      setState(() => _isLoading = true);
      try {
        final results = await PlacesService.search(
          query,
          countryCodes: widget.countryCodes,
          placeType: widget.placeType,
          locationLatLng: widget.locationLatLng,
          bbox: widget.bbox,
          lang: widget.lang,
        );
        if (mounted) {
          setState(() {
            _predictions = results;
            _isLoading = false;
          });
          if (results.isNotEmpty) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && _predictions.isNotEmpty) {
                Scrollable.ensureVisible(context, alignment: 0.0, duration: const Duration(milliseconds: 200), curve: Curves.easeInOut);
                Future.delayed(const Duration(milliseconds: 220), () {
                  if (mounted) _focusNode.requestFocus();
                });
              }
            });
          }
        }
      } catch (_) {
        if (mounted) setState(() => _isLoading = false);
      }
    });
  }

  void _selectPrediction(PlacePrediction p) {
    if (!mounted) return;
    final locationUrl = p.osmUrl ??
        (p.lat != null && p.lng != null
            ? 'https://www.openstreetmap.org/?mlat=${p.lat}&mlon=${p.lng}#map=17/${p.lat}/${p.lng}'
            : null);
    widget.onSelected(p.mainText, p.lat, p.lng, locationUrl, p.countryCode);
    _controller.clear();
    setState(() => _predictions = []);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _controller,
          focusNode: _focusNode,
          decoration: InputDecoration(
            hintText: widget.hint,
            prefixIcon: const Icon(Icons.search_outlined),
            suffixIcon: _isLoading
                ? Padding(
                    padding: const EdgeInsets.all(12),
                    child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Theme.of(context).colorScheme.primary)),
                  )
                : null,
          ),
          onChanged: _search,
        ),
        if (_predictions.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [BoxShadow(color: Theme.of(context).colorScheme.shadow.withValues(alpha: 0.08), blurRadius: 12, offset: const Offset(0, 4))],
            ),
            constraints: const BoxConstraints(maxHeight: 220),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _predictions.length,
              itemBuilder: (_, i) {
                final p = _predictions[i];
                return ListTile(
                  leading: Icon(Icons.place_outlined, size: 22, color: Theme.of(context).colorScheme.primary),
                  title: Text(p.mainText, style: Theme.of(context).textTheme.bodyMedium),
                  subtitle: p.secondaryText != null ? Text(p.secondaryText!, style: Theme.of(context).textTheme.bodySmall) : null,
                  onTap: () => _selectPrediction(p),
                );
              },
            ),
          ),
      ],
    );
  }
}
