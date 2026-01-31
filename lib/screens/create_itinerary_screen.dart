import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/theme.dart';
import '../core/analytics.dart';
import '../core/constants.dart';
import '../data/countries.dart' show countries, destinationToCountryCodes, travelModes;
import '../services/supabase_service.dart';
import '../widgets/google_places_field.dart';
import '../widgets/itinerary_map.dart';
import '../models/itinerary.dart';

const List<String> _seasons = ['Spring', 'Summer', 'Fall', 'Winter'];
const List<String> _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

class CreateItineraryScreen extends StatefulWidget {
  final String? itineraryId;

  const CreateItineraryScreen({super.key, this.itineraryId});

  @override
  State<CreateItineraryScreen> createState() => _CreateItineraryScreenState();
}

class _CreateItineraryScreenState extends State<CreateItineraryScreen> {
  final _pageController = PageController();
  int _currentPage = 0;
  final _formKey = GlobalKey<FormState>();

  // Step 1: Start New Trip
  final _titleController = TextEditingController();
  final List<String> _selectedCountries = [];
  String? _selectedMode;
  String _visibility = visibilityFriends;
  bool _showCountrySuggestions = false;
  String _countryQuery = '';

  // Duration: either dates or month/season
  bool _useDates = true;
  DateTime? _startDate;
  DateTime? _endDate;
  String? _selectedSeason;
  int? _selectedMonth;
  int _selectedYear = DateTime.now().year;
  int _daysCountOverride = 7; // when using month/season
  final _daysOverrideController = TextEditingController(text: '7');

  // Step 2 & 3: Destinations with day ranges
  final List<_DestinationEntry> _destinations = [];

  bool _isLoading = false;
  bool _isLoadingData = false;

  bool get _isEditMode => widget.itineraryId != null;
  int get _daysCount {
    if (_useDates && _startDate != null && _endDate != null) {
      return _endDate!.difference(_startDate!).inDays + 1;
    }
    return int.tryParse(_daysOverrideController.text) ?? _daysCountOverride;
  }

  @override
  void initState() {
    super.initState();
    if (_isEditMode) _loadForEdit();
  }

  Future<void> _loadForEdit() async {
    final id = widget.itineraryId!;
    if (!mounted) return;
    setState(() => _isLoadingData = true);
    try {
      final it = await SupabaseService.getItinerary(id, checkAccess: true);
      if (it == null || !mounted) return;
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId != null && it.authorId != userId) {
        if (mounted) context.go('/home');
        return;
      }
      _titleController.text = it.title;
      _selectedCountries.addAll(destinationToCountryCodes(it.destination));
      _selectedMode = it.mode ?? modeStandard;
      _visibility = it.visibility;

      _destinations.clear();
      // Build destinations by walking stops in order: venues belong to the destination
      // whose location stop they follow (save order: locs per day, then venues per dest)
      final destByKey = <String, _DestinationEntry>{};
      _DestinationEntry? currentDest;
      for (final s in it.stops) {
        if (s.isLocation) {
          final key = '${s.name}|${s.lat ?? 0}|${s.lng ?? 0}';
          currentDest = destByKey[key];
          if (currentDest == null) {
            currentDest = _DestinationEntry()
              ..name = s.name
              ..lat = s.lat
              ..lng = s.lng
              ..placeId = s.googlePlaceId ?? s.placeId
              ..days = {s.day}
              ..venues = [];
            destByKey[key] = currentDest;
          } else {
            currentDest.days!.add(s.day);
          }
        } else if (s.isVenue && currentDest != null) {
          currentDest.venues!.add(_VenueEntry()
            ..name = s.name
            ..lat = s.lat
            ..lng = s.lng
            ..placeId = s.googlePlaceId ?? s.placeId
            ..category = s.category ?? 'restaurant');
        }
      }
      _destinations.addAll(destByKey.values);
      _destinations.sort((a, b) {
        final aMin = a.days?.isNotEmpty == true ? a.days!.reduce((x, y) => x < y ? x : y) : 1;
        final bMin = b.days?.isNotEmpty == true ? b.days!.reduce((x, y) => x < y ? x : y) : 1;
        return aMin.compareTo(bMin);
      });

      if (_destinations.isEmpty && it.daysCount > 0) {
        _daysCountOverride = it.daysCount;
        _daysOverrideController.text = '${it.daysCount}';
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not load itinerary. Please try again.')));
    } finally {
      if (mounted) setState(() => _isLoadingData = false);
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _titleController.dispose();
    _daysOverrideController.dispose();
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
        _countryQuery = '';
        _showCountrySuggestions = false;
      });
    }
  }

  void _removeCountry(String code) {
    setState(() => _selectedCountries.remove(code));
  }

  void _addDestination() {
    setState(() => _destinations.add(_DestinationEntry()));
  }

  void _removeDestination(int index) {
    setState(() => _destinations.removeAt(index));
  }

  void _addVenue(int destIndex, String category) {
    setState(() {
      final d = _destinations[destIndex];
      d.venues ??= [];
      d.venues!.add(_VenueEntry()..category = category);
    });
  }

  void _removeVenue(int destIndex, int venueIndex) {
    setState(() => _destinations[destIndex].venues!.removeAt(venueIndex));
  }

  bool get _hasUnsavedData {
    if (_titleController.text.trim().isNotEmpty || _selectedCountries.isNotEmpty) return true;
    if (_destinations.any((d) => d.name.isNotEmpty)) return true;
    for (final d in _destinations) {
      if (d.venues != null && d.venues!.any((v) => v.name.isNotEmpty)) return true;
    }
    return false;
  }

  Future<void> _handleBack() async {
    if (!_hasUnsavedData) {
      _goToPage(_currentPage - 1);
      return;
    }
    final leave = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: Icon(Icons.warning_amber_rounded, size: 48, color: Theme.of(ctx).colorScheme.primary),
        title: const Text('Discard changes?'),
        content: const Text('You have unsaved data. Are you sure you want to go back?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Discard')),
        ],
      ),
    );
    if (leave == true && mounted) _goToPage(_currentPage - 1);
  }

  void _goToPage(int page) {
    setState(() {
      _currentPage = page.clamp(0, 6);
      _pageController.animateToPage(_currentPage, duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    });
  }

  void _nextPage() {
    if (_currentPage == 0 && (_formKey.currentState?.validate() != true || _selectedCountries.isEmpty)) {
      if (_selectedCountries.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Add at least one country')));
      }
      return;
    }
    if (_currentPage == 0 && _useDates && (_startDate == null || _endDate == null)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Select start and end dates')));
      return;
    }
    if (_currentPage == 0 && !_useDates && _daysCountOverride < 1) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter number of days')));
      return;
    }
    if (_currentPage == 1 && _destinations.every((d) => d.name.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Add at least one destination')));
      return;
    }
    if (_currentPage == 2) {
      final invalid = _destinations.where((d) => d.name.isNotEmpty && (d.days == null || d.days!.isEmpty));
      if (invalid.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Select at least one day for each destination')));
        return;
      }
    }
    _goToPage(_currentPage + 1);
  }

  Future<void> _save() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    final destination = _selectedCountries.map((c) => countries[c] ?? c).join(', ');
    final stopsData = <Map<String, dynamic>>[];
    var position = 0;

    for (final d in _destinations.where((x) => x.name.isNotEmpty)) {
      final days = (d.days ?? {1}).where((day) => day >= 1 && day <= _daysCount).toList()..sort();
      if (days.isEmpty) continue;
      for (final day in days) {
        stopsData.add({
          'name': d.name,
          'category': 'location',
          'stop_type': 'location',
          'lat': d.lat,
          'lng': d.lng,
          'google_place_id': d.placeId,
          'day': day,
          'position': position++,
        });
      }
      final anchorDay = days.first;
      for (final v in d.venues ?? []) {
        if (v.name.isNotEmpty) {
          // DB category constraint: 'guide' not in schema yet; map to 'experience'
          final cat = v.category ?? 'restaurant';
          final dbCat = cat == 'guide' ? 'experience' : cat;
          stopsData.add({
            'name': v.name,
            'category': dbCat,
            'stop_type': 'venue',
            'lat': v.lat,
            'lng': v.lng,
            'google_place_id': v.placeId,
            'day': anchorDay,
            'position': position++,
          });
        }
      }
    }

    setState(() => _isLoading = true);
    try {
      if (_isEditMode) {
        final id = widget.itineraryId!;
        await SupabaseService.updateItinerary(id, {
          'title': _titleController.text.trim(),
          'destination': destination,
          'days_count': _daysCount,
          'mode': (_selectedMode ?? modeStandard).toLowerCase(),
          'visibility': _visibility,
        });
        await SupabaseService.updateItineraryStops(id, stopsData);
        Analytics.logEvent('itinerary_updated', {'id': id});
        if (mounted) context.go('/itinerary/$id');
      } else {
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
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not save trip. Please try again.')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _pageTitle() {
    final titles = ['New Trip', 'Add Destinations', 'Assign Days', 'Trip Map', 'Add Details', 'Review Trip', 'Save Trip'];
    return _isEditMode && _currentPage == 0 ? 'Edit Trip' : titles[_currentPage.clamp(0, 6)];
  }

  List<ItineraryStop> get _stopsForMap {
    final stops = <ItineraryStop>[];
    for (final d in _destinations.where((x) => x.name.isNotEmpty)) {
      final days = d.days ?? {1};
      final firstDay = days.isNotEmpty ? days.reduce((a, b) => a < b ? a : b) : 1;
      stops.add(ItineraryStop(
        id: 'temp_${d.name}_$firstDay',
        itineraryId: '',
        position: 0,
        day: firstDay,
        name: d.name,
        category: 'location',
        stopType: 'location',
        lat: d.lat,
        lng: d.lng,
        googlePlaceId: d.placeId,
      ));
      for (final v in d.venues ?? []) {
        if (v.name.isNotEmpty && v.lat != null && v.lng != null) {
          stops.add(ItineraryStop(
            id: 'temp_${v.name}_${d.name}',
            itineraryId: '',
            position: 0,
            day: firstDay,
            name: v.name,
            category: v.category ?? 'restaurant',
            stopType: 'venue',
            lat: v.lat,
            lng: v.lng,
            googlePlaceId: v.placeId,
          ));
        }
      }
    }
    return stops;
  }

  String _formatDays(Set<int>? days) {
    if (days == null || days.isEmpty) return '—';
    final sorted = days.toList()..sort();
    return sorted.map((d) => d.toString()).join(', ');
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
              ? IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => _handleBack())
              : null,
        ),
        body: _isLoadingData
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(width: 40, height: 40, child: CircularProgressIndicator(strokeWidth: 2, color: Theme.of(context).colorScheme.primary)),
                    const SizedBox(height: AppTheme.spacingLg),
                    Text('Loading…', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                  ],
                ),
              )
            : PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _buildStep1(),
                  _buildStep2(),
                  _buildStep3(),
                  _buildStep4(),
                  _buildStep5(),
                  _buildStep6(),
                  _buildStep7(),
                ],
              ),
      ),
    );
  }

  Widget _buildStep1() {
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(AppTheme.spacingMd),
        children: [
          Text('Start a New Trip', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: AppTheme.spacingLg),
          TextFormField(
            controller: _titleController,
            decoration: const InputDecoration(
              labelText: 'Trip name',
              hintText: 'e.g. Summer in Asia',
              prefixIcon: Icon(Icons.title_outlined),
            ),
            validator: (v) => v == null || v.isEmpty ? 'Enter trip name' : null,
          ),
          const SizedBox(height: AppTheme.spacingLg),
          Text('Countries visited', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: AppTheme.spacingSm),
          if (_selectedCountries.isNotEmpty)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _selectedCountries.map((code) => Chip(
                label: Text(countries[code] ?? code),
                deleteIcon: const Icon(Icons.close, size: 18),
                onDeleted: () => _removeCountry(code),
              )).toList(),
            ),
          const SizedBox(height: 8),
          TextField(
            decoration: const InputDecoration(hintText: 'Search and add countries…', prefixIcon: Icon(Icons.search_outlined)),
            onChanged: (v) => setState(() {
              _countryQuery = v;
              _showCountrySuggestions = v.isNotEmpty;
            }),
            onTap: () => setState(() => _showCountrySuggestions = _countryQuery.isNotEmpty),
          ),
          if (_showCountrySuggestions && _filteredCountries.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(top: AppTheme.spacingXs),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [BoxShadow(color: Theme.of(context).colorScheme.shadow.withValues(alpha: 0.08), blurRadius: 12, offset: const Offset(0, 4))],
              ),
              constraints: const BoxConstraints(maxHeight: 200),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _filteredCountries.length,
                itemBuilder: (_, i) {
                  final e = _filteredCountries[i];
                  final added = _selectedCountries.contains(e.key);
                  return ListTile(
                    leading: Icon(added ? Icons.check_circle : Icons.add_circle_outline, size: 22, color: added ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.onSurfaceVariant),
                    title: Text(e.value),
                    onTap: added ? null : () => _addCountry(e.key),
                  );
                },
              ),
            ),
          const SizedBox(height: AppTheme.spacingLg),
          Text('Trip duration', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: AppTheme.spacingSm),
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: true, icon: Icon(Icons.calendar_today, size: 18), label: Text('Dates')),
              ButtonSegment(value: false, icon: Icon(Icons.wb_sunny_outlined, size: 18), label: Text('Month/Season')),
            ],
            selected: {_useDates},
            onSelectionChanged: (s) => setState(() => _useDates = s.first),
          ),
          const SizedBox(height: AppTheme.spacingMd),
          if (_useDates) ...[
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('Start date', style: Theme.of(context).textTheme.bodyMedium),
              subtitle: Text(_startDate != null ? '${_startDate!.month}/${_startDate!.day}/${_startDate!.year}' : 'Tap to select'),
              trailing: const Icon(Icons.calendar_today),
              onTap: () async {
                final d = await showDatePicker(context: context, initialDate: _startDate ?? DateTime.now(), firstDate: DateTime(2020), lastDate: DateTime(2030));
                if (d != null && mounted) setState(() => _startDate = d);
              },
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('End date', style: Theme.of(context).textTheme.bodyMedium),
              subtitle: Text(_endDate != null ? '${_endDate!.month}/${_endDate!.day}/${_endDate!.year}' : 'Tap to select'),
              trailing: const Icon(Icons.calendar_today),
              onTap: () async {
                final d = await showDatePicker(context: context, initialDate: _endDate ?? _startDate ?? DateTime.now(), firstDate: _startDate ?? DateTime(2020), lastDate: DateTime(2030));
                if (d != null && mounted) setState(() => _endDate = d);
              },
            ),
            if (_startDate != null && _endDate != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text('$_daysCount days', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w500)),
              ),
          ] else ...[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _seasons.map((s) => FilterChip(
                label: Text(s),
                selected: _selectedSeason == s,
                onSelected: (_) => setState(() {
                  _selectedSeason = _selectedSeason == s ? null : s;
                  _selectedMonth = null;
                }),
              )).toList(),
            ),
            if (_selectedSeason == null) ...[
              const SizedBox(height: 8),
              Text('Or select month', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
              const SizedBox(height: 4),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: List.generate(12, (i) => FilterChip(
                  label: Text(_months[i]),
                  selected: _selectedMonth == i + 1,
                  onSelected: (_) => setState(() {
                    _selectedMonth = _selectedMonth == i + 1 ? null : i + 1;
                    _selectedSeason = null;
                  }),
                )),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: InputDecorator(
                    decoration: const InputDecoration(labelText: 'Year'),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<int>(
                        value: _selectedYear,
                        isExpanded: true,
                        items: List.generate(6, (i) => DateTime.now().year - 2 + i).map((y) => DropdownMenuItem(value: y, child: Text('$y'))).toList(),
                        onChanged: (v) => setState(() => _selectedYear = v ?? DateTime.now().year),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: _daysOverrideController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Number of days'),
                    onChanged: (v) => setState(() => _daysCountOverride = int.tryParse(v) ?? 7),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: AppTheme.spacingLg),
          Text('Travel style', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: AppTheme.spacingSm),
          Wrap(
            spacing: AppTheme.spacingSm,
            runSpacing: AppTheme.spacingSm,
            children: travelModes.map((m) => FilterChip(
              label: Text(m),
              selected: _selectedMode == m.toLowerCase(),
              onSelected: (_) => setState(() => _selectedMode = m.toLowerCase()),
              selectedColor: Theme.of(context).colorScheme.primaryContainer,
              checkmarkColor: Theme.of(context).colorScheme.primary,
            )).toList(),
          ),
          const SizedBox(height: AppTheme.spacingLg),
          Text('Visibility', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: AppTheme.spacingSm),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: visibilityFriends, icon: Icon(Icons.people_outline, size: 18), label: Text('Followers Only')),
              ButtonSegment(value: visibilityPublic, icon: Icon(Icons.public, size: 18), label: Text('Public')),
            ],
            selected: {_visibility},
            onSelectionChanged: (s) => setState(() => _visibility = s.first),
          ),
          const SizedBox(height: AppTheme.spacingXl),
          FilledButton.icon(
            onPressed: _nextPage,
            icon: const Icon(Icons.arrow_forward, size: 20),
            label: const Text('Next: Add Destinations'),
          ),
        ],
      ),
    );
  }

  Widget _buildStep2() {
    return ListView(
      padding: const EdgeInsets.all(AppTheme.spacingMd),
      children: [
        Text('Add Destinations', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: AppTheme.spacingSm),
        Text('Add each place you visited (city or location). e.g. Tokyo, Singapore, Bali.', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
        const SizedBox(height: AppTheme.spacingLg),
        ...List.generate(_destinations.length, (i) {
          final d = _destinations[i];
          return Card(
            margin: const EdgeInsets.only(bottom: AppTheme.spacingMd),
            child: Padding(
              padding: const EdgeInsets.all(AppTheme.spacingMd),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: d.name.isEmpty
                            ? GooglePlacesField(
                                hint: 'Search city or location…',
                                countryCodes: _selectedCountries,
                                placeType: '(cities)',
                                onSelected: (name, lat, lng, placeId) {
                                  d.name = name;
                                  d.lat = lat;
                                  d.lng = lng;
                                  d.placeId = placeId;
                                  setState(() {});
                                },
                              )
                            : Chip(
                                label: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.place, size: 18, color: Theme.of(context).colorScheme.primary),
                                    const SizedBox(width: 6),
                                    Text(d.name),
                                  ],
                                ),
                                deleteIcon: const Icon(Icons.close, size: 18),
                                onDeleted: () {
                                  d.name = '';
                                  d.lat = null;
                                  d.lng = null;
                                  d.placeId = null;
                                  setState(() {});
                                },
                              ),
                      ),
                      IconButton(icon: const Icon(Icons.close), onPressed: () => _removeDestination(i)),
                    ],
                  ),
                ],
              ),
            ),
          );
        }),
        OutlinedButton.icon(
          onPressed: _addDestination,
          icon: const Icon(Icons.add),
          label: const Text('Add destination'),
          style: OutlinedButton.styleFrom(minimumSize: const Size(double.infinity, 48)),
        ),
        const SizedBox(height: AppTheme.spacingLg),
        FilledButton.icon(
          onPressed: _nextPage,
          icon: const Icon(Icons.arrow_forward, size: 20),
          label: const Text('Next: Assign Days'),
        ),
      ],
    );
  }

  Widget _buildStep3() {
    return ListView(
      padding: const EdgeInsets.all(AppTheme.spacingMd),
      children: [
        Text('Assign Days to Each Destination', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: AppTheme.spacingSm),
        Text('Select which day(s) you were at each destination. Tap days to toggle. You can select any combination—they don\'t need to be consecutive.', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
        const SizedBox(height: AppTheme.spacingLg),
        ...(_destinations.where((d) => d.name.isNotEmpty).map((d) {
          d.days ??= {};
          return Card(
            margin: const EdgeInsets.only(bottom: AppTheme.spacingMd),
            child: Padding(
              padding: const EdgeInsets.all(AppTheme.spacingMd),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(d.name, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: List.generate(_daysCount, (i) {
                      final day = i + 1;
                      final selected = d.days!.contains(day);
                      return FilterChip(
                        label: Text('Day $day'),
                        selected: selected,
                        onSelected: (_) {
                          setState(() {
                            if (selected) {
                              d.days!.remove(day);
                            } else {
                              d.days!.add(day);
                            }
                          });
                        },
                        selectedColor: Theme.of(context).colorScheme.primaryContainer,
                        checkmarkColor: Theme.of(context).colorScheme.primary,
                      );
                    }),
                  ),
                  if (d.days!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text('Selected: ${_formatDays(d.days)}', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                    ),
                ],
              ),
            ),
          );
        })),
        const SizedBox(height: AppTheme.spacingLg),
        FilledButton.icon(
          onPressed: _nextPage,
          icon: const Icon(Icons.arrow_forward, size: 20),
          label: const Text('Next: View Map'),
        ),
      ],
    );
  }

  Widget _buildStep4() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          flex: 1,
          child: LayoutBuilder(
            builder: (context, constraints) {
              // ItineraryMap: header ~44 + map + hint ~28 + padding 32 = mapHeight + 104
              final mapHeight = (constraints.maxHeight - 104).clamp(120.0, 400.0);
              return Padding(
                padding: const EdgeInsets.all(AppTheme.spacingMd),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: _stopsForMap.any((s) => s.lat != null && s.lng != null)
                      ? ItineraryMap(
                          stops: _stopsForMap,
                          destination: _selectedCountries.map((c) => countries[c]).join(', '),
                          height: mapHeight,
                        )
                  : Container(
                      height: mapHeight,
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.map_outlined, size: 48, color: Theme.of(context).colorScheme.onSurfaceVariant),
                            const SizedBox(height: 12),
                            Text('Add destinations with locations to see the map', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant), textAlign: TextAlign.center),
                          ],
                        ),
                      ),
                    ),
                ),
              );
            },
          ),
        ),
        Container(
          padding: const EdgeInsets.all(AppTheme.spacingMd),
          decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Destinations', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              ...(_destinations.where((d) => d.name.isNotEmpty).map((d) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    Icon(Icons.place, size: 18, color: Theme.of(context).colorScheme.primary),
                    const SizedBox(width: 8),
                    Text('${d.name} (Days ${_formatDays(d.days)})', style: Theme.of(context).textTheme.bodyMedium),
                  ],
                ),
              ))),
              const SizedBox(height: AppTheme.spacingMd),
              FilledButton.icon(
                onPressed: _nextPage,
                icon: const Icon(Icons.arrow_forward, size: 20),
                label: const Text('Next: Add Details'),
                style: FilledButton.styleFrom(minimumSize: const Size(double.infinity, 48)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  int? _selectedDestForDetails;

  Widget _buildStep5() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(AppTheme.spacingMd),
          child: Text('Add Details to Each Destination', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingMd),
          child: Text('Tap a destination below to add restaurants, hotels, and guides.', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
        ),
        const SizedBox(height: AppTheme.spacingMd),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingMd),
            children: _destinations.asMap().entries.where((e) => e.value.name.isNotEmpty).map((entry) {
              final i = entry.key;
              final d = entry.value;
              final isSelected = _selectedDestForDetails == i;
              return Card(
                margin: const EdgeInsets.only(bottom: AppTheme.spacingSm),
                color: isSelected ? Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3) : null,
                child: InkWell(
                  onTap: () => setState(() => _selectedDestForDetails = _selectedDestForDetails == i ? null : i),
                  borderRadius: BorderRadius.circular(20),
                  child: Padding(
                    padding: const EdgeInsets.all(AppTheme.spacingMd),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.place, size: 22, color: Theme.of(context).colorScheme.primary),
                            const SizedBox(width: 8),
                            Text(d.name, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                          ],
                        ),
                        if (isSelected) ...[
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              FilledButton.tonal(
                                onPressed: () => _addVenue(i, 'restaurant'),
                                child: const Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.restaurant, size: 18), SizedBox(width: 6), Text('Restaurant')]),
                              ),
                              FilledButton.tonal(
                                onPressed: () => _addVenue(i, 'hotel'),
                                child: const Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.hotel, size: 18), SizedBox(width: 6), Text('Hotel')]),
                              ),
                              FilledButton.tonal(
                                onPressed: () => _addVenue(i, 'guide'),
                                child: const Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.tour, size: 18), SizedBox(width: 6), Text('Guide')]),
                              ),
                            ],
                          ),
                          if (d.venues != null && d.venues!.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            ...d.venues!.asMap().entries.map((ve) {
                              final vi = ve.key;
                              final v = ve.value;
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: v.name.isEmpty
                                    ? Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Expanded(
                                            child: GooglePlacesField(
                                              hint: 'Search ${v.category}…',
                                              countryCodes: _selectedCountries,
                                              locationLatLng: d.lat != null && d.lng != null ? (d.lat!, d.lng!) : null,
                                              onSelected: (name, lat, lng, placeId) {
                                                v.name = name;
                                                v.lat = lat;
                                                v.lng = lng;
                                                v.placeId = placeId;
                                                setState(() {});
                                              },
                                            ),
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.close, size: 20),
                                            onPressed: () => _removeVenue(i, vi),
                                          ),
                                        ],
                                      )
                                    : Chip(
                                        label: Text(v.name),
                                        deleteIcon: const Icon(Icons.close, size: 18),
                                        onDeleted: () => _removeVenue(i, vi),
                                      ),
                              );
                            }),
                          ],
                        ],
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(AppTheme.spacingMd),
          child: FilledButton.icon(
            onPressed: _nextPage,
            icon: const Icon(Icons.arrow_forward, size: 20),
            label: const Text('Next: Review Trip'),
            style: FilledButton.styleFrom(minimumSize: const Size(double.infinity, 48)),
          ),
        ),
      ],
    );
  }

  Widget _buildStep6() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          flex: 1,
          child: LayoutBuilder(
            builder: (context, constraints) {
              // ItineraryMap: header ~44 + map + hint ~28 + padding 32 = mapHeight + 104
              final mapHeight = (constraints.maxHeight - 104).clamp(120.0, 400.0);
              return Padding(
                padding: const EdgeInsets.all(AppTheme.spacingMd),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: _stopsForMap.isNotEmpty
                      ? ItineraryMap(stops: _stopsForMap, destination: _selectedCountries.map((c) => countries[c]).join(', '), height: mapHeight)
                      : Container(
                          height: mapHeight,
                          color: Theme.of(context).colorScheme.surfaceContainerHighest,
                          child: Center(child: Text('No map data', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant))),
                        ),
                ),
              );
            },
          ),
        ),
        Expanded(
          flex: 1,
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingMd),
            children: [
              Text('All destinations & details', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              ...(_destinations.where((d) => d.name.isNotEmpty).expand((d) => [
                ListTile(
                  leading: Icon(Icons.place, color: Theme.of(context).colorScheme.primary),
                  title: Text('${d.name} (Days ${_formatDays(d.days)})'),
                ),
                if (d.venues != null)
                  ...d.venues!.where((v) => v.name.isNotEmpty).map((v) => Padding(
                    padding: const EdgeInsets.only(left: 40, bottom: 4),
                    child: Row(
                      children: [
                        Icon(_iconForCategory(v.category), size: 18, color: Theme.of(context).colorScheme.onSurfaceVariant),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(v.name, style: Theme.of(context).textTheme.bodyMedium, overflow: TextOverflow.ellipsis),
                        ),
                        const SizedBox(width: 4),
                        Text('(${v.category ?? 'restaurant'})', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                      ],
                    ),
                  )),
              ])),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(AppTheme.spacingMd),
          child: Row(
            children: [
              OutlinedButton(
                onPressed: () => _goToPage(4),
                child: const Text('Edit details'),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: _nextPage,
                  icon: const Icon(Icons.save, size: 20),
                  label: const Text('Save Trip'),
                  style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  IconData _iconForCategory(String? cat) {
    switch (cat) {
      case 'hotel': return Icons.hotel;
      case 'guide': return Icons.tour;
      default: return Icons.restaurant;
    }
  }

  Widget _buildStep7() {
    return Padding(
      padding: const EdgeInsets.all(AppTheme.spacingMd),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.5),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.check_circle_outline, size: 80, color: Theme.of(context).colorScheme.primary),
          ),
          const SizedBox(height: AppTheme.spacingLg),
          Text('Ready to save', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('Your trip will be added to your profile and ready to view or share.', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant), textAlign: TextAlign.center),
          const SizedBox(height: AppTheme.spacingXl),
          FilledButton.icon(
            onPressed: _isLoading ? null : _save,
            icon: _isLoading
                ? SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Theme.of(context).colorScheme.onPrimary))
                : const Icon(Icons.save, size: 22),
            label: Text(_isLoading ? 'Saving…' : 'Save Trip'),
            style: FilledButton.styleFrom(minimumSize: const Size(double.infinity, 52)),
          ),
        ],
      ),
    );
  }
}

class _DestinationEntry {
  String name = '';
  double? lat;
  double? lng;
  String? placeId;
  Set<int>? days; // specific days user was at this destination (non-contiguous)
  List<_VenueEntry>? venues;
}

class _VenueEntry {
  String name = '';
  double? lat;
  double? lng;
  String? placeId;
  String? category;
}
