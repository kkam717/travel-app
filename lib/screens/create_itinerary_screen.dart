import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/theme.dart';
import '../core/analytics.dart';
import '../models/itinerary.dart';
import '../data/countries.dart';
import '../services/supabase_service.dart';
import 'place_autocomplete_field.dart';

class CreateItineraryScreen extends StatefulWidget {
  const CreateItineraryScreen({super.key});

  @override
  State<CreateItineraryScreen> createState() => _CreateItineraryScreenState();
}

class _CreateItineraryScreenState extends State<CreateItineraryScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _destinationController = TextEditingController();
  final _daysController = TextEditingController(text: '7');
  List<String> _selectedStyles = [];
  String? _selectedMode;
  String _visibility = 'private';
  List<_StopEntry> _stops = [];
  bool _isLoading = false;
  String? _forkedFromId;

  @override
  void dispose() {
    _titleController.dispose();
    _destinationController.dispose();
    _daysController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;
    setState(() => _isLoading = true);
    try {
      final days = int.tryParse(_daysController.text) ?? 7;
      final stopsData = _stops.map((s) => {
        'name': s.name,
        'category': s.category,
        'external_url': s.externalUrl?.isEmpty == true ? null : s.externalUrl,
        'lat': s.lat,
        'lng': s.lng,
        'place_id': s.placeId,
      }).toList();

      final it = await SupabaseService.createItinerary(
        authorId: userId,
        title: _titleController.text.trim(),
        destination: _destinationController.text.trim(),
        daysCount: days,
        styleTags: _selectedStyles,
        mode: _selectedMode ?? 'standard',
        visibility: _visibility,
        forkedFromId: _forkedFromId,
        stopsData: stopsData,
      );
      Analytics.logEvent('itinerary_created', {'id': it.id});
      if (mounted) context.go('/itinerary/${it.id}');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    Analytics.logScreenView('create_itinerary');
    return Scaffold(
      appBar: AppBar(title: const Text('Create itinerary')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(AppTheme.spacingMd),
          children: [
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: 'Title'),
              validator: (v) => v == null || v.isEmpty ? 'Enter title' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _destinationController,
              decoration: const InputDecoration(labelText: 'Destination (city/country)'),
              validator: (v) => v == null || v.isEmpty ? 'Enter destination' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _daysController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Days'),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Enter days';
                if (int.tryParse(v) == null || int.parse(v) < 1) return 'Enter valid number';
                return null;
              },
            ),
            const SizedBox(height: 16),
            Text('Travel styles', style: Theme.of(context).textTheme.titleSmall),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: travelStyles.map((s) {
                final selected = _selectedStyles.contains(s);
                return FilterChip(
                  label: Text(s),
                  selected: selected,
                  onSelected: (_) => setState(() {
                    if (selected) _selectedStyles.remove(s);
                    else _selectedStyles.add(s);
                  }),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            Text('Mode', style: Theme.of(context).textTheme.titleSmall),
            Wrap(
              spacing: 8,
              children: travelModes.map((m) {
                final selected = _selectedMode == m;
                return ChoiceChip(
                  label: Text(m),
                  selected: selected,
                  onSelected: (_) => setState(() => _selectedMode = m),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            Text('Visibility', style: Theme.of(context).textTheme.titleSmall),
            SegmentedButton<String>(
              segments: const [ButtonSegment(value: 'private', label: Text('Private')), ButtonSegment(value: 'public', label: Text('Public'))],
              selected: {_visibility},
              onSelectionChanged: (s) => setState(() => _visibility = s.first),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Stops', style: Theme.of(context).textTheme.titleMedium),
                TextButton.icon(
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add stop'),
                  onPressed: () => setState(() => _stops.add(_StopEntry())),
                ),
              ],
            ),
            ...List.generate(_stops.length, (i) => _StopTile(
                  entry: _stops[i],
                  index: i,
                  onRemove: () => setState(() => _stops.removeAt(i)),
                  onChanged: () => setState(() {}),
                )),
            const SizedBox(height: 32),
            FilledButton(
              onPressed: _isLoading ? null : _save,
              child: _isLoading ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Save itinerary'),
            ),
          ],
        ),
      ),
    );
  }
}

class _StopEntry {
  String name = '';
  String? category;
  String? externalUrl;
  double? lat;
  double? lng;
  String? placeId;
}

class _StopTile extends StatelessWidget {
  final _StopEntry entry;
  final int index;
  final VoidCallback onRemove;
  final VoidCallback onChanged;

  const _StopTile({required this.entry, required this.index, required this.onRemove, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Stop ${index + 1}', style: Theme.of(context).textTheme.titleSmall),
                const Spacer(),
                IconButton(icon: const Icon(Icons.close, size: 20), onPressed: onRemove),
              ],
            ),
            const SizedBox(height: 8),
            PlaceAutocompleteField(
              hint: 'Place name',
              onSelected: (place) {
                entry.name = place.name;
                entry.lat = place.lat;
                entry.lng = place.lng;
                entry.placeId = place.id;
                onChanged();
              },
              onCustomEntry: (name) {
                entry.name = name;
                entry.lat = null;
                entry.lng = null;
                entry.placeId = null;
                onChanged();
              },
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: entry.category,
              decoration: const InputDecoration(labelText: 'Category'),
              items: stopCategories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
              onChanged: (v) {
                entry.category = v;
                onChanged();
              },
            ),
            const SizedBox(height: 8),
            TextFormField(
              initialValue: entry.externalUrl,
              decoration: const InputDecoration(labelText: 'External link (optional)'),
              onChanged: (v) => entry.externalUrl = v,
            ),
          ],
        ),
      ),
    );
  }
}
