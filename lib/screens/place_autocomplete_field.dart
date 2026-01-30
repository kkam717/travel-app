import 'dart:async';
import 'package:flutter/material.dart';
import '../models/itinerary.dart';
import '../services/supabase_service.dart';

class PlaceAutocompleteField extends StatefulWidget {
  final String hint;
  final void Function(Place place) onSelected;
  final void Function(String name) onCustomEntry;

  const PlaceAutocompleteField({
    super.key,
    required this.hint,
    required this.onSelected,
    required this.onCustomEntry,
  });

  @override
  State<PlaceAutocompleteField> createState() => _PlaceAutocompleteFieldState();
}

class _PlaceAutocompleteFieldState extends State<PlaceAutocompleteField> {
  final _controller = TextEditingController();
  List<Place> _suggestions = [];
  bool _isLoading = false;
  bool _showSuggestions = false;
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _search(String query) {
    _debounce?.cancel();
    if (query.length < 3) {
      setState(() {
        _suggestions = [];
        _showSuggestions = false;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 300), () async {
      setState(() => _isLoading = true);
      try {
        final results = await SupabaseService.searchPlaces(query);
        if (mounted) {
          setState(() {
            _suggestions = results;
            _showSuggestions = true;
            _isLoading = false;
          });
        }
      } catch (e) {
        if (mounted) setState(() => _isLoading = false);
      }
    });
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
            suffixIcon: _isLoading ? const Padding(padding: EdgeInsets.all(12), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))) : null,
          ),
          onChanged: _search,
          onTap: () {
            if (_controller.text.length >= 3) setState(() => _showSuggestions = true);
          },
        ),
        if (_showSuggestions && _suggestions.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 8, offset: const Offset(0, 2))],
            ),
            constraints: const BoxConstraints(maxHeight: 200),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _suggestions.length + 1,
              itemBuilder: (_, i) {
                if (i == _suggestions.length) {
                  return ListTile(
                    leading: const Icon(Icons.add),
                    title: Text('Use "${_controller.text}" as custom entry'),
                    onTap: () async {
                      try {
                        final place = await SupabaseService.insertPlace(name: _controller.text);
                        if (place != null) {
                          widget.onSelected(place);
                        } else {
                          widget.onCustomEntry(_controller.text);
                        }
                      } catch (e) {
                        widget.onCustomEntry(_controller.text);
                      }
                      setState(() => _showSuggestions = false);
                    },
                  );
                }
                final p = _suggestions[i];
                return ListTile(
                  title: Text(p.name),
                  subtitle: p.city != null || p.country != null ? Text([p.city, p.country].whereType<String>().join(', ')) : null,
                  onTap: () {
                    widget.onSelected(p);
                    _controller.text = p.name;
                    setState(() => _showSuggestions = false);
                  },
                );
              },
            ),
          ),
      ],
    );
  }
}
