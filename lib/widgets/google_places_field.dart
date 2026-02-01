import 'dart:async';
import 'package:flutter/material.dart';
import '../services/google_places_service.dart';

class GooglePlacesField extends StatefulWidget {
  final String hint;
  final void Function(String name, double? lat, double? lng, String? placeId) onSelected;
  final String? placeType;
  final List<String>? countryCodes;
  final (double, double)? locationLatLng; // Bias venue search toward this point (day's city)

  const GooglePlacesField({
    super.key,
    required this.hint,
    required this.onSelected,
    this.placeType,
    this.countryCodes,
    this.locationLatLng,
  });

  @override
  State<GooglePlacesField> createState() => _GooglePlacesFieldState();
}

class _GooglePlacesFieldState extends State<GooglePlacesField> {
  final _controller = TextEditingController();
  List<PlacePrediction> _predictions = [];
  bool _isLoading = false;
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _search(String query) {
    _debounce?.cancel();
    if (query.trim().length < 2) {
      setState(() {
        _predictions = [];
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 400), () async {
      setState(() => _isLoading = true);
      try {
        final results = await GooglePlacesService.autocomplete(
          query,
          countryCodes: widget.countryCodes,
          placeType: widget.placeType,
          locationLatLng: widget.locationLatLng,
        );
        if (mounted) {
          setState(() {
            _predictions = results;
            _isLoading = false;
          });
        }
      } catch (_) {
        if (mounted) setState(() => _isLoading = false);
      }
    });
  }

  Future<void> _selectPrediction(PlacePrediction p) async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final details = await GooglePlacesService.getDetails(p.placeId);
      if (!mounted) return;
      widget.onSelected(
        details?.name ?? p.mainText,
        details?.lat,
        details?.lng,
        p.placeId,
      );
      if (!mounted) return;
      _controller.clear();
      setState(() {
        _predictions = [];
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      widget.onSelected(p.mainText, null, null, p.placeId);
      if (!mounted) return;
      _controller.clear();
      setState(() {
        _predictions = [];
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _controller,
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
