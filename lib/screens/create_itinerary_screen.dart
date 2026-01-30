import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/theme.dart';
import '../core/analytics.dart';
import '../core/constants.dart';
import '../data/countries.dart';
import '../services/supabase_service.dart';
import '../widgets/google_places_field.dart';

class CreateItineraryScreen extends StatefulWidget {
  const CreateItineraryScreen({super.key});

  @override
  State<CreateItineraryScreen> createState() => _CreateItineraryScreenState();
}

class _CreateItineraryScreenState extends State<CreateItineraryScreen> {
  final _pageController = PageController();
  int _currentPage = 0;
  final _formKey = GlobalKey<FormState>();

  // Page 1
  final _titleController = TextEditingController();
  final _destinationController = TextEditingController();
  final _daysController = TextEditingController(text: '7');
  final List<String> _selectedCountries = [];
  String? _selectedMode;
  String _visibility = visibilityPrivate;
  bool _showCountrySuggestions = false;
  String _countryQuery = '';

  // Page 2: day-level locations (cities, towns, villages) - multiple per day
  final Map<int, List<_LocationEntry>> _locationsByDay = {};

  // Page 3: venues per day (restaurants, bars, hotels)
  final Map<int, List<_PlaceEntry>> _venuesByDay = {};
  bool _isLoading = false;

  int get _daysCount => int.tryParse(_daysController.text) ?? 7;

  @override
  void dispose() {
    _pageController.dispose();
    _titleController.dispose();
    _destinationController.dispose();
    _daysController.dispose();
    super.dispose();
  }

  List<MapEntry<String, String>> get _filteredCountries {
    if (_countryQuery.isEmpty) return countries.entries.take(20).toList();
    final q = _countryQuery.toLowerCase();
    return countries.entries
        .where((e) => e.value.toLowerCase().contains(q) || e.key.toLowerCase().contains(q))
        .take(20)
        .toList();
  }

  void _addCountry(String code) {
    if (!_selectedCountries.contains(code)) {
      setState(() {
        _selectedCountries.add(code);
        _destinationController.clear();
        _countryQuery = '';
        _showCountrySuggestions = false;
      });
    }
  }

  void _removeCountry(String code) {
    setState(() => _selectedCountries.remove(code));
  }

  List<_LocationEntry> _locationsForDay(int day) {
    return _locationsByDay.putIfAbsent(day, () => []);
  }

  void _addLocation(int day) {
    setState(() => _locationsForDay(day).add(_LocationEntry()));
  }

  void _removeLocation(int day, int index) {
    setState(() => _locationsForDay(day).removeAt(index));
  }

  List<_PlaceEntry> _venuesForDay(int day) {
    return _venuesByDay.putIfAbsent(day, () => []);
  }

  void _addVenue(int day) {
    setState(() => _venuesForDay(day).add(_PlaceEntry()));
  }

  void _removeVenue(int day, int index) {
    setState(() => _venuesForDay(day).removeAt(index));
  }

  bool get _hasUnsavedData {
    if (_titleController.text.trim().isNotEmpty || _selectedCountries.isNotEmpty) return true;
    for (final locs in _locationsByDay.values) {
      if (locs.any((l) => l.name.isNotEmpty)) return true;
    }
    for (final venues in _venuesByDay.values) {
      if (venues.any((v) => v.name.isNotEmpty)) return true;
    }
    return false;
  }

  Future<void> _handleBack() async {
    if (!_hasUnsavedData) {
      setState(() {
        _currentPage--;
        _pageController.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
      });
      return;
    }
    final leave = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Discard changes?'),
        content: const Text('You have unsaved data. Are you sure you want to go back?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Discard')),
        ],
      ),
    );
    if (leave == true && mounted) {
      setState(() {
        _currentPage--;
        _pageController.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
      });
    }
  }

  void _goToPage2() {
    if (_formKey.currentState?.validate() != true) return;
    if (_selectedCountries.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Add at least one destination country')));
      return;
    }
    setState(() {
      _currentPage = 1;
      _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    });
  }

  void _goToPage3() {
    setState(() {
      _currentPage = 2;
      _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    });
  }

  Future<void> _save() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    final destination = _selectedCountries.map((c) => countries[c] ?? c).join(', ');
    final stopsData = <Map<String, dynamic>>[];
    var position = 0;
    for (var day = 1; day <= _daysCount; day++) {
      // Day locations first (cities/towns per day)
      for (final loc in _locationsForDay(day)) {
        if (loc.name.isNotEmpty) {
          stopsData.add({
            'name': loc.name,
            'category': 'location',
            'stop_type': 'location',
            'lat': loc.lat,
            'lng': loc.lng,
            'place_id': loc.placeId,
            'day': day,
            'position': position++,
          });
        }
      }
      // Then venues for that day
      for (final p in _venuesForDay(day)) {
        if (p.name.isNotEmpty) {
          stopsData.add({
            'name': p.name,
            'category': p.category,
            'stop_type': 'venue',
            'lat': p.lat,
            'lng': p.lng,
            'place_id': p.placeId,
            'day': day,
            'position': position++,
          });
        }
      }
    }

    setState(() => _isLoading = true);
    try {
      final it = await SupabaseService.createItinerary(
        authorId: userId,
        title: _titleController.text.trim(),
        destination: destination,
        daysCount: _daysCount,
        styleTags: [],
        mode: _selectedMode ?? modeStandard,
        visibility: _visibility,
        forkedFromId: null,
        stopsData: stopsData,
      );
      Analytics.logEvent('itinerary_created', {'id': it.id});
      if (mounted) context.go('/itinerary/${it.id}');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not save itinerary. Please try again.')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _pageTitle() {
    switch (_currentPage) {
      case 0:
        return 'Create trip';
      case 1:
        return 'Add locations';
      case 2:
        return 'Add places';
      default:
        return 'Create trip';
    }
  }

  @override
  Widget build(BuildContext context) {
    Analytics.logScreenView('create_itinerary');
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        if (_currentPage > 0) {
          await _handleBack();
        } else if (_hasUnsavedData) {
          final leave = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Discard changes?'),
              content: const Text('You have unsaved data. Are you sure you want to leave?'),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Discard')),
              ],
            ),
          );
          if (leave == true && context.mounted) context.go('/home');
        } else {
          if (context.mounted) context.go('/home');
        }
      },
      child: Scaffold(
      appBar: AppBar(
        title: Text(_pageTitle()),
        leading: _currentPage > 0
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => _handleBack(),
              )
            : null,
      ),
      body: PageView(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          _buildPage1(),
          _buildPage2(),
          _buildPage3(),
        ],
      ),
    ),
    );
  }

  Widget _buildPage1() {
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(AppTheme.spacingMd),
        children: [
          TextFormField(
            controller: _titleController,
            decoration: const InputDecoration(labelText: 'Trip title'),
            validator: (v) => v == null || v.isEmpty ? 'Enter title' : null,
          ),
          const SizedBox(height: 16),
          Text('Destination (countries)', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          if (_selectedCountries.isNotEmpty)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _selectedCountries.map((code) {
                return Chip(
                  label: Text(countries[code] ?? code),
                  deleteIcon: const Icon(Icons.close, size: 18),
                  onDeleted: () => _removeCountry(code),
                );
              }).toList(),
            ),
          const SizedBox(height: 8),
          TextField(
            controller: _destinationController,
            decoration: const InputDecoration(
              hintText: 'Search and add countries...',
              prefixIcon: Icon(Icons.search),
            ),
            onChanged: (v) => setState(() {
              _countryQuery = v;
              _showCountrySuggestions = v.isNotEmpty;
            }),
            onTap: () => setState(() => _showCountrySuggestions = _destinationController.text.isNotEmpty),
          ),
          if (_showCountrySuggestions && _filteredCountries.isNotEmpty)
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
                itemCount: _filteredCountries.length,
                itemBuilder: (_, i) {
                  final e = _filteredCountries[i];
                  final alreadyAdded = _selectedCountries.contains(e.key);
                  return ListTile(
                    title: Text(e.value),
                    trailing: alreadyAdded ? const Icon(Icons.check, color: Colors.green) : null,
                    onTap: alreadyAdded ? null : () => _addCountry(e.key),
                  );
                },
              ),
            ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _daysController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Number of days'),
            validator: (v) {
              if (v == null || v.isEmpty) return 'Enter days';
              if (int.tryParse(v) == null || int.parse(v) < 1) return 'Enter valid number';
              return null;
            },
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
            segments: const [
              ButtonSegment(value: visibilityPrivate, label: Text('Private')),
              ButtonSegment(value: visibilityPublic, label: Text('Public')),
            ],
            selected: {_visibility},
            onSelectionChanged: (s) => setState(() => _visibility = s.first),
          ),
          const SizedBox(height: 32),
          FilledButton(
            onPressed: _goToPage2,
            child: const Text('Next'),
          ),
        ],
      ),
    );
  }

  Widget _buildPage2() {
    return ListView(
      padding: const EdgeInsets.all(AppTheme.spacingMd),
      children: [
        Text(
          'Add cities, towns, or villages for each day. You can add multiple locations per day.',
          style: TextStyle(color: Colors.grey[700], fontSize: 14),
        ),
        const SizedBox(height: 24),
        ...List.generate(_daysCount, (i) {
          final day = i + 1;
          final locations = _locationsForDay(day);
          return Card(
            margin: const EdgeInsets.only(bottom: AppTheme.spacingMd),
            child: Padding(
              padding: const EdgeInsets.all(AppTheme.spacingMd),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text('Day $day', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                      const Spacer(),
                      TextButton.icon(
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Add location'),
                        onPressed: () => _addLocation(day),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ...List.generate(locations.length, (j) {
                    final loc = locations[j];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: loc.name.isEmpty
                          ? GooglePlacesField(
                              hint: 'Search city, town, village...',
                              countryCodes: _selectedCountries,
                              placeType: '(cities)',
                              onSelected: (name, lat, lng, placeId) {
                                loc.name = name;
                                loc.lat = lat;
                                loc.lng = lng;
                                loc.placeId = placeId;
                                setState(() {});
                              },
                            )
                          : Row(
                              children: [
                                Expanded(
                                  child: Chip(
                                    label: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.location_city, size: 18, color: Theme.of(context).colorScheme.primary),
                                        const SizedBox(width: 6),
                                        Text(loc.name),
                                      ],
                                    ),
                                    deleteIcon: const Icon(Icons.close, size: 18),
                                    onDeleted: () {
                                      loc.name = '';
                                      loc.lat = null;
                                      loc.lng = null;
                                      loc.placeId = null;
                                      setState(() {});
                                    },
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.close, size: 20),
                                  onPressed: () => _removeLocation(day, j),
                                ),
                              ],
                            ),
                    );
                  }),
                  if (locations.isEmpty)
                    Text('No locations yet', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                ],
              ),
            ),
          );
        }),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: _goToPage3,
          child: const Text('Next'),
        ),
      ],
    );
  }

  Widget _buildPage3() {
    return ListView(
      padding: const EdgeInsets.all(AppTheme.spacingMd),
      children: [
        Text(
          'Add restaurants, bars, hotels, and other places you went to each day.',
          style: TextStyle(color: Colors.grey[700], fontSize: 14),
        ),
        const SizedBox(height: 24),
        ...List.generate(_daysCount, (i) {
          final day = i + 1;
          final locations = _locationsForDay(day);
          final locsWithCoords = locations.where((l) => l.lat != null && l.lng != null).toList();
          final locationLatLng = locsWithCoords.isNotEmpty ? (locsWithCoords.first.lat!, locsWithCoords.first.lng!) : null;
          final venues = _venuesForDay(day);
          return Card(
            margin: const EdgeInsets.only(bottom: AppTheme.spacingMd),
            child: Padding(
              padding: const EdgeInsets.all(AppTheme.spacingMd),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text('Day $day', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                      if (locations.any((l) => l.name.isNotEmpty)) ...[
                        const SizedBox(width: 8),
                        Flexible(
                          child: Wrap(
                            spacing: 4,
                            runSpacing: 4,
                            children: locations.where((l) => l.name.isNotEmpty).map((l) => Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.grey[200],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.location_on, size: 14, color: Colors.grey[700]),
                                  const SizedBox(width: 4),
                                  Text(l.name, style: TextStyle(fontSize: 12, color: Colors.grey[700])),
                                ],
                              ),
                            )).toList(),
                          ),
                        ),
                      ],
                      const Spacer(),
                      TextButton.icon(
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Add place'),
                        onPressed: () => _addVenue(day),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ...List.generate(venues.length, (j) => _PlaceTile(
                        entry: venues[j],
                        countryCodes: _selectedCountries,
                        locationLatLng: locationLatLng,
                        onRemove: () => _removeVenue(day, j),
                        onChanged: () => setState(() {}),
                      )),
                  if (venues.isEmpty)
                    Text('No places yet', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                ],
              ),
            ),
          );
        }),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: _isLoading ? null : _save,
          child: _isLoading
              ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Save Itinerary'),
        ),
      ],
    );
  }
}

class _LocationEntry {
  String name = '';
  double? lat;
  double? lng;
  String? placeId;
}

class _PlaceEntry {
  String name = '';
  String? category;
  double? lat;
  double? lng;
  String? placeId;
}

class _PlaceTile extends StatelessWidget {
  final _PlaceEntry entry;
  final List<String> countryCodes;
  final (double, double)? locationLatLng;
  final VoidCallback onRemove;
  final VoidCallback onChanged;

  const _PlaceTile({
    required this.entry,
    required this.countryCodes,
    this.locationLatLng,
    required this.onRemove,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: entry.name.isEmpty
                ? GooglePlacesField(
                    hint: 'Search bar, restaurant, hotel...',
                    countryCodes: countryCodes,
                    locationLatLng: locationLatLng,
                    onSelected: (name, lat, lng, placeId) {
                      entry.name = name;
                      entry.lat = lat;
                      entry.lng = lng;
                      entry.placeId = placeId;
                      onChanged();
                    },
                  )
                : Chip(
                    label: Text(entry.name),
                    deleteIcon: const Icon(Icons.close, size: 18),
                    onDeleted: () {
                      entry.name = '';
                      entry.lat = null;
                      entry.lng = null;
                      entry.placeId = null;
                      onChanged();
                    },
                  ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 20),
            onPressed: onRemove,
          ),
        ],
      ),
    );
  }
}
