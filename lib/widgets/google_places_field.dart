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
    setState(() => _isLoading = true);
    try {
      final details = await GooglePlacesService.getDetails(p.placeId);
      if (mounted) {
        widget.onSelected(
          details?.name ?? p.mainText,
          details?.lat,
          details?.lng,
          p.placeId,
        );
        _controller.clear();
        setState(() {
          _predictions = [];
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        widget.onSelected(p.mainText, null, null, p.placeId);
        _controller.clear();
        setState(() {
          _predictions = [];
          _isLoading = false;
        });
      }
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
            suffixIcon: _isLoading
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                  )
                : null,
          ),
          onChanged: _search,
        ),
        if (_predictions.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 8, offset: const Offset(0, 2))],
            ),
            constraints: const BoxConstraints(maxHeight: 220),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _predictions.length,
              itemBuilder: (_, i) {
                final p = _predictions[i];
                return ListTile(
                  leading: const Icon(Icons.place, size: 20, color: Colors.grey),
                  title: Text(p.mainText),
                  subtitle: p.secondaryText != null ? Text(p.secondaryText!, style: const TextStyle(fontSize: 12)) : null,
                  onTap: () => _selectPrediction(p),
                );
              },
            ),
          ),
      ],
    );
  }
}
