import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/theme.dart';
import '../core/analytics.dart';
import '../core/constants.dart';
import '../data/countries.dart' show countries, destinationToCountryCodes, travelModes;
import '../l10n/app_strings.dart';
import '../services/supabase_service.dart';
import '../widgets/places_field.dart';
import '../widgets/itinerary_map.dart';
import '../widgets/itinerary_timeline.dart' show TransportType, TimelineConnector, transportTypeFromString, transportTypeToString;
import '../models/itinerary.dart' show ItineraryStop, TransportTransition;

const List<String> _seasons = ['Spring', 'Summer', 'Fall', 'Winter'];
const List<String> _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

String _venueCategoryLabel(BuildContext context, String? cat) {
  switch (cat) {
    case 'hotel': return AppStrings.t(context, 'hotel');
    case 'guide': return AppStrings.t(context, 'guide');
    case 'bar': return AppStrings.t(context, 'drinks');
    case 'restaurant': return AppStrings.t(context, 'restaurant');
    default: return AppStrings.t(context, 'restaurant');
  }
}

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

  // Transport between destinations (transition index -> TransportType)
  final Map<int, TransportType> _transportBetweenDestinations = {};
  // Optional description per transport (transition index -> description)
  final Map<int, String> _transportDescriptions = {};

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
      _selectedCountries.clear();
      _selectedCountries.addAll(destinationToCountryCodes(it.destination));
      _selectedMode = it.mode ?? modeStandard;
      _visibility = it.visibility;

      // Restore trip duration (Step 1)
      _daysCountOverride = it.daysCount;
      _daysOverrideController.text = '${it.daysCount}';
      // Infer Dates vs Month/Season: use stored value, or infer from duration_year/season
      if (it.useDates != null) {
        _useDates = it.useDates!;
      } else if (it.durationYear != null || it.durationSeason != null) {
        _useDates = false;
      }
      if (_useDates) {
        _startDate = it.startDate;
        _endDate = it.endDate;
        if (_startDate == null && _endDate == null && it.createdAt != null) {
          _startDate = it.createdAt;
          _endDate = it.createdAt!.add(Duration(days: it.daysCount - 1));
        }
        // Pre-fill year/month from dates so they appear when switching to Month/Season
        if (_startDate != null) {
          _selectedYear = _startDate!.year;
          _selectedMonth = _startDate!.month;
        }
      } else {
        _selectedYear = it.durationYear ?? it.createdAt?.year ?? DateTime.now().year;
        _selectedMonth = it.durationMonth ?? it.createdAt?.month;
        _selectedSeason = it.durationSeason;
      }

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
              ..externalUrl = s.externalUrl
              ..days = {s.day};
            destByKey[key] = currentDest;
          } else {
            currentDest.days!.add(s.day);
          }
        } else if (s.isVenue && currentDest != null) {
          currentDest.venuesByDay[s.day] ??= [];
          currentDest.venuesByDay[s.day]!.add(_VenueEntry()
            ..name = s.name
            ..lat = s.lat
            ..lng = s.lng
            ..externalUrl = s.externalUrl
            ..category = s.category ?? 'restaurant');
        }
      }
      _destinations.addAll(destByKey.values);
      _destinations.sort((a, b) {
        final aMin = a.days?.isNotEmpty == true ? a.days!.reduce((x, y) => x < y ? x : y) : 1;
        final bMin = b.days?.isNotEmpty == true ? b.days!.reduce((x, y) => x < y ? x : y) : 1;
        return aMin.compareTo(bMin);
      });

      _transportBetweenDestinations.clear();
      _transportDescriptions.clear();
      final trans = it.transportTransitions;
      if (trans != null) {
        for (var i = 0; i < trans.length; i++) {
          _transportBetweenDestinations[i] = transportTypeFromString(trans[i].type);
          final d = trans[i].description;
          if (d != null && d.trim().isNotEmpty) _transportDescriptions[i] = d;
        }
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppStrings.t(context, 'could_not_load_itinerary'))));
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

  void _addVenue(int destIndex, String category, int day) {
    setState(() {
      final d = _destinations[destIndex];
      d.venuesByDay[day] ??= [];
      d.venuesByDay[day]!.add(_VenueEntry()..category = category);
    });
  }

  void _removeVenue(int destIndex, int day, int venueIndex) {
    setState(() => _destinations[destIndex].venuesByDay[day]?.removeAt(venueIndex));
  }

  bool get _hasUnsavedData {
    if (_titleController.text.trim().isNotEmpty || _selectedCountries.isNotEmpty) return true;
    if (_destinations.any((d) => d.name.isNotEmpty)) return true;
    for (final d in _destinations) {
      for (final list in d.venuesByDay.values) {
        if (list.any((v) => v.name.isNotEmpty)) return true;
      }
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
        title: Text(AppStrings.t(context, 'discard_changes')),
        content: Text(AppStrings.t(context, 'unsaved_data_confirm')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(AppStrings.t(context, 'cancel'))),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(AppStrings.t(context, 'discard'))),
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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppStrings.t(context, 'add_at_least_one_country'))));
      }
      return;
    }
    if (_currentPage == 0 && _useDates && (_startDate == null || _endDate == null)) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppStrings.t(context, 'select_start_end_dates'))));
      return;
    }
    if (_currentPage == 0 && !_useDates && _daysCountOverride < 1) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppStrings.t(context, 'enter_number_of_days'))));
      return;
    }
    if (_currentPage == 1 && _destinations.every((d) => d.name.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppStrings.t(context, 'add_at_least_one_destination'))));
      return;
    }
    if (_currentPage == 2) {
      final invalid = _destinations.where((d) => d.name.isNotEmpty && (d.days == null || d.days!.isEmpty));
      if (invalid.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppStrings.t(context, 'select_day_per_destination'))));
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

    // Chronological order: each (destination, day) in position - enables loops (e.g. airport Day 1 & Day 7)
    for (final pair in _chronologicalDestDayPairs) {
      final d = pair.d;
      final day = pair.day;
      if (day < 1 || day > _daysCount) continue;
      stopsData.add({
        'name': d.name,
        'category': 'location',
        'stop_type': 'location',
        'lat': d.lat,
        'lng': d.lng,
        'external_url': d.externalUrl,
        'day': day,
        'position': position++,
      });
      for (final v in d.venuesByDay[day] ?? []) {
        if (v.name.isNotEmpty) {
          final cat = v.category ?? 'restaurant';
          final dbCat = cat == 'guide' ? 'experience' : cat;
          stopsData.add({
            'name': v.name,
            'category': dbCat,
            'stop_type': 'venue',
            'lat': v.lat,
            'lng': v.lng,
            'external_url': v.externalUrl,
            'day': day,
            'position': position++,
          });
        }
      }
    }

    setState(() => _isLoading = true);
    try {
      if (_isEditMode) {
        final id = widget.itineraryId!;
        final updateData = <String, dynamic>{
          'title': _titleController.text.trim(),
          'destination': destination,
          'days_count': _daysCount,
          'mode': (_selectedMode ?? modeStandard).toLowerCase(),
          'visibility': _visibility,
        };
        updateData['use_dates'] = _useDates;
        if (_useDates) {
          updateData['start_date'] = _startDate?.toIso8601String().split('T').first;
          updateData['end_date'] = _endDate?.toIso8601String().split('T').first;
          updateData['duration_year'] = null;
          updateData['duration_month'] = null;
          updateData['duration_season'] = null;
        } else {
          updateData['start_date'] = null;
          updateData['end_date'] = null;
          updateData['duration_year'] = _selectedYear;
          updateData['duration_month'] = _selectedMonth;
          updateData['duration_season'] = _selectedSeason;
        }
        final pairs = _chronologicalDestDayPairs;
        if (pairs.length >= 2) {
          updateData['transport_transitions'] = List.generate(pairs.length - 1, (i) {
            final t = _transportBetweenDestinations[i] ?? TransportType.unknown;
            final d = _transportDescriptions[i]?.trim();
            return {'type': transportTypeToString(t), if (d != null && d.isNotEmpty) 'description': d};
          });
        }
        await SupabaseService.updateItinerary(id, updateData);
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
          useDates: _useDates,
          startDate: _useDates ? _startDate : null,
          endDate: _useDates ? _endDate : null,
          durationYear: _useDates ? null : _selectedYear,
          durationMonth: _useDates ? null : _selectedMonth,
          durationSeason: _useDates ? null : _selectedSeason,
          transportTransitions: _chronologicalDestDayPairs.length >= 2
              ? List.generate(_chronologicalDestDayPairs.length - 1, (i) {
                  final t = _transportBetweenDestinations[i] ?? TransportType.unknown;
                  final d = _transportDescriptions[i]?.trim();
                  return TransportTransition(type: transportTypeToString(t), description: d != null && d.isNotEmpty ? d : null);
                })
              : null,
        );
        Analytics.logEvent('itinerary_created', {'id': it.id});
        if (mounted) context.go('/itinerary/${it.id}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppStrings.t(context, 'could_not_save'))));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _pageTitle(BuildContext context) {
    final keys = ['new_trip', 'add_destinations', 'assign_days', 'trip_map', 'add_transport', 'add_details', 'review_trip'];
    return _isEditMode && _currentPage == 0 ? AppStrings.t(context, 'edit_trip') : AppStrings.t(context, keys[_currentPage.clamp(0, 6)]);
  }

  String _localizedMode(BuildContext context, String m) {
    switch (m.toLowerCase()) {
      case 'budget': return AppStrings.t(context, 'budget');
      case 'standard': return AppStrings.t(context, 'standard');
      case 'luxury': return AppStrings.t(context, 'luxury');
      default: return m;
    }
  }

  List<ItineraryStop> get _stopsForMap {
    final stops = <ItineraryStop>[];
    // Chronological order for map polyline - enables loops (e.g. airport Day 1 & Day 7)
    for (final pair in _chronologicalDestDayPairs) {
      final d = pair.d;
      final day = pair.day;
      stops.add(ItineraryStop(
        id: 'temp_${d.name}_$day',
        itineraryId: '',
        position: 0,
        day: day,
        name: d.name,
        category: 'location',
        stopType: 'location',
        lat: d.lat,
        lng: d.lng,
        externalUrl: d.externalUrl,
      ));
      for (final v in d.venuesByDay[day] ?? []) {
        if (v.name.isNotEmpty && v.lat != null && v.lng != null) {
          stops.add(ItineraryStop(
            id: 'temp_${v.name}_${d.name}_$day',
            itineraryId: '',
            position: 0,
            day: day,
            name: v.name,
            category: v.category ?? 'restaurant',
            stopType: 'venue',
            lat: v.lat,
            lng: v.lng,
            externalUrl: v.externalUrl,
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
              title: Text(AppStrings.t(context, 'discard_changes')),
              content: Text(AppStrings.t(context, 'unsaved_data_confirm')),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(AppStrings.t(context, 'cancel'))),
                FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(AppStrings.t(context, 'discard'))),
              ],
            ),
          );
          if (leave == true && context.mounted) {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/home');
            }
          }
        } else {
          if (context.mounted) {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/home');
            }
          }
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_pageTitle(context)),
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
                    Text(AppStrings.t(context, 'loading'), style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
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
                  _buildStepTransport(),
                  _buildStep5(),
                  _buildStep6(),
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
          Text(AppStrings.t(context, 'start_new_trip'), style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: AppTheme.spacingLg),
          TextFormField(
            controller: _titleController,
            decoration: InputDecoration(
              labelText: AppStrings.t(context, 'trip_name'),
              hintText: AppStrings.t(context, 'trip_name_hint'),
              prefixIcon: const Icon(Icons.title_outlined),
            ),
            validator: (v) => v == null || v.isEmpty ? AppStrings.t(context, 'enter_trip_name') : null,
          ),
          const SizedBox(height: AppTheme.spacingLg),
          Text(AppStrings.t(context, 'countries_visited'), style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
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
            decoration: InputDecoration(hintText: AppStrings.t(context, 'search_and_add_countries'), prefixIcon: const Icon(Icons.search_outlined)),
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
          Text(AppStrings.t(context, 'trip_duration'), style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: AppTheme.spacingSm),
          SegmentedButton<bool>(
            segments: [
              ButtonSegment(value: true, icon: const Icon(Icons.calendar_today, size: 18), label: Text(AppStrings.t(context, 'dates'))),
              ButtonSegment(value: false, icon: const Icon(Icons.wb_sunny_outlined, size: 18), label: Text(AppStrings.t(context, 'month_season'))),
            ],
            selected: {_useDates},
            onSelectionChanged: (s) => setState(() => _useDates = s.first),
          ),
          const SizedBox(height: AppTheme.spacingMd),
          if (_useDates) ...[
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(AppStrings.t(context, 'start_date'), style: Theme.of(context).textTheme.bodyMedium),
              subtitle: Text(_startDate != null ? '${_startDate!.month}/${_startDate!.day}/${_startDate!.year}' : AppStrings.t(context, 'tap_to_select')),
              trailing: const Icon(Icons.calendar_today),
              onTap: () async {
                final d = await showDatePicker(context: context, initialDate: _startDate ?? DateTime.now(), firstDate: DateTime(2020), lastDate: DateTime(2030));
                if (d != null && mounted) setState(() => _startDate = d);
              },
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(AppStrings.t(context, 'end_date'), style: Theme.of(context).textTheme.bodyMedium),
              subtitle: Text(_endDate != null ? '${_endDate!.month}/${_endDate!.day}/${_endDate!.year}' : AppStrings.t(context, 'tap_to_select')),
              trailing: const Icon(Icons.calendar_today),
              onTap: () async {
                final d = await showDatePicker(context: context, initialDate: _endDate ?? _startDate ?? DateTime.now(), firstDate: _startDate ?? DateTime(2020), lastDate: DateTime(2030));
                if (d != null && mounted) setState(() => _endDate = d);
              },
            ),
            if (_startDate != null && _endDate != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text('$_daysCount ${AppStrings.t(context, 'days')}', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w500)),
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
              Text(AppStrings.t(context, 'or_select_month'), style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
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
                    decoration: InputDecoration(labelText: AppStrings.t(context, 'year')),
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
                    decoration: InputDecoration(labelText: AppStrings.t(context, 'number_of_days')),
                    onChanged: (v) => setState(() => _daysCountOverride = int.tryParse(v) ?? 7),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: AppTheme.spacingLg),
          Text(AppStrings.t(context, 'travel_style'), style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: AppTheme.spacingSm),
          Wrap(
            spacing: AppTheme.spacingSm,
            runSpacing: AppTheme.spacingSm,
            children: travelModes.map((m) => FilterChip(
              label: Text(_localizedMode(context, m)),
              selected: _selectedMode == m.toLowerCase(),
              onSelected: (_) => setState(() => _selectedMode = m.toLowerCase()),
              selectedColor: Theme.of(context).colorScheme.primaryContainer,
              checkmarkColor: Theme.of(context).colorScheme.primary,
            )).toList(),
          ),
          const SizedBox(height: AppTheme.spacingLg),
          Text(AppStrings.t(context, 'visibility'), style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: AppTheme.spacingSm),
          SegmentedButton<String>(
            segments: [
              ButtonSegment(value: visibilityFriends, icon: const Icon(Icons.people_outline, size: 18), label: Text(AppStrings.t(context, 'followers_only'))),
              ButtonSegment(value: visibilityPublic, icon: const Icon(Icons.public, size: 18), label: Text(AppStrings.t(context, 'public'))),
            ],
            selected: {_visibility},
            onSelectionChanged: (s) => setState(() => _visibility = s.first),
          ),
          const SizedBox(height: AppTheme.spacingXl),
          FilledButton.icon(
            onPressed: _nextPage,
            icon: const Icon(Icons.arrow_forward, size: 20),
            label: Text(AppStrings.t(context, 'next_add_destinations')),
          ),
        ],
      ),
    );
  }

  Widget _buildStep2() {
    return ListView(
      padding: const EdgeInsets.all(AppTheme.spacingMd),
      children: [
        Text(AppStrings.t(context, 'add_destinations'), style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: AppTheme.spacingSm),
        Text(AppStrings.t(context, 'add_destinations_hint'), style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
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
                            ? PlacesField(
                                hint: AppStrings.t(context, 'search_city_or_location'),
                                countryCodes: _selectedCountries.isNotEmpty ? _selectedCountries : null,
                                onSelected: (name, lat, lng, locationUrl, _) {
                                  d.name = name;
                                  d.lat = lat;
                                  d.lng = lng;
                                  d.externalUrl = locationUrl;
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
                                  d.externalUrl = null;
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
          label: Text(AppStrings.t(context, 'add_destination')),
          style: OutlinedButton.styleFrom(minimumSize: const Size(double.infinity, 48)),
        ),
        const SizedBox(height: AppTheme.spacingLg),
        FilledButton.icon(
          onPressed: _nextPage,
          icon: const Icon(Icons.arrow_forward, size: 20),
          label: Text(AppStrings.t(context, 'next_assign_days')),
        ),
      ],
    );
  }

  Widget _buildStep3() {
    return ListView(
      padding: const EdgeInsets.all(AppTheme.spacingMd),
      children: [
        Text(AppStrings.t(context, 'assign_days_title'), style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: AppTheme.spacingSm),
        Text(AppStrings.t(context, 'assign_days_hint'), style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
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
                        label: Text('${AppStrings.t(context, 'day')} $day'),
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
                      child: Text('${AppStrings.t(context, 'selected')}: ${_formatDays(d.days)}', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
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
          label: Text(AppStrings.t(context, 'next_view_map')),
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
                            Text(AppStrings.t(context, 'add_destinations_for_map'), style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant), textAlign: TextAlign.center),
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
              Text(AppStrings.t(context, 'destinations'), style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
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
                label: Text(AppStrings.t(context, 'next_add_transport')),
                style: FilledButton.styleFrom(minimumSize: const Size(double.infinity, 48)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStepTransport() {
    final pairs = _chronologicalDestDayPairs;
    // Only show transport between different places (same place = no transport segment)
    final segments = <int, ({_DestinationEntry from, _DestinationEntry to, int dayFrom, int dayTo})>{};
    for (var i = 0; i < pairs.length - 1; i++) {
      final from = pairs[i];
      final to = pairs[i + 1];
      if (from.d != to.d) segments[i] = (from: from.d, to: to.d, dayFrom: from.day, dayTo: to.day);
    }
    final segmentIndices = segments.keys.toList()..sort();

    return ListView(
      padding: const EdgeInsets.all(AppTheme.spacingMd),
      children: [
        Text(AppStrings.t(context, 'add_transport_title'), style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: AppTheme.spacingSm),
        Text(AppStrings.t(context, 'add_transport_how'), style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
        const SizedBox(height: AppTheme.spacingLg),
        if (segmentIndices.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppTheme.spacingLg),
            child: Text(
              pairs.length >= 2
                  ? AppStrings.t(context, 'same_place_no_transport')
                  : AppStrings.t(context, 'add_2_destinations_transport'),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          )
        else
          ...segmentIndices.map((origIdx) {
          final seg = segments[origIdx]!;
          final current = _transportBetweenDestinations[origIdx] ?? TransportType.unknown;
          return Card(
            margin: const EdgeInsets.only(bottom: AppTheme.spacingMd),
            child: Padding(
              padding: const EdgeInsets.all(AppTheme.spacingMd),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.place, size: 20, color: Theme.of(context).colorScheme.primary),
                      const SizedBox(width: 8),
                      Expanded(child: Text('${seg.from.name} (Day ${seg.dayFrom})', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600))),
                      Icon(Icons.arrow_downward, size: 20, color: Theme.of(context).colorScheme.outline),
                      const SizedBox(width: 8),
                      Icon(Icons.place, size: 20, color: Theme.of(context).colorScheme.primary),
                      const SizedBox(width: 8),
                      Expanded(child: Text('${seg.to.name} (Day ${seg.dayTo})', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600))),
                    ],
                  ),
                  const SizedBox(height: AppTheme.spacingMd),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilterChip(
                        label: Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.flight_rounded, size: 18, color: current == TransportType.plane ? Theme.of(context).colorScheme.onPrimaryContainer : Theme.of(context).colorScheme.onSurfaceVariant), const SizedBox(width: 6), Text(AppStrings.t(context, 'plane'))]),
                        selected: current == TransportType.plane,
                        onSelected: (_) => setState(() => _transportBetweenDestinations[origIdx] = TransportType.plane),
                        selectedColor: Theme.of(context).colorScheme.primaryContainer,
                        checkmarkColor: Theme.of(context).colorScheme.primary,
                      ),
                      FilterChip(
                        label: Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.train_rounded, size: 18, color: current == TransportType.train ? Theme.of(context).colorScheme.onPrimaryContainer : Theme.of(context).colorScheme.onSurfaceVariant), const SizedBox(width: 6), Text(AppStrings.t(context, 'train'))]),
                        selected: current == TransportType.train,
                        onSelected: (_) => setState(() => _transportBetweenDestinations[origIdx] = TransportType.train),
                        selectedColor: Theme.of(context).colorScheme.primaryContainer,
                        checkmarkColor: Theme.of(context).colorScheme.primary,
                      ),
                      FilterChip(
                        label: Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.directions_car_rounded, size: 18, color: current == TransportType.car ? Theme.of(context).colorScheme.onPrimaryContainer : Theme.of(context).colorScheme.onSurfaceVariant), const SizedBox(width: 6), Text(AppStrings.t(context, 'car'))]),
                        selected: current == TransportType.car,
                        onSelected: (_) => setState(() => _transportBetweenDestinations[origIdx] = TransportType.car),
                        selectedColor: Theme.of(context).colorScheme.primaryContainer,
                        checkmarkColor: Theme.of(context).colorScheme.primary,
                      ),
                      FilterChip(
                        label: Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.directions_bus_rounded, size: 18, color: current == TransportType.bus ? Theme.of(context).colorScheme.onPrimaryContainer : Theme.of(context).colorScheme.onSurfaceVariant), const SizedBox(width: 6), Text(AppStrings.t(context, 'bus'))]),
                        selected: current == TransportType.bus,
                        onSelected: (_) => setState(() => _transportBetweenDestinations[origIdx] = TransportType.bus),
                        selectedColor: Theme.of(context).colorScheme.primaryContainer,
                        checkmarkColor: Theme.of(context).colorScheme.primary,
                      ),
                      FilterChip(
                        label: Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.directions_boat_rounded, size: 18, color: current == TransportType.boat ? Theme.of(context).colorScheme.onPrimaryContainer : Theme.of(context).colorScheme.onSurfaceVariant), const SizedBox(width: 6), Text(AppStrings.t(context, 'boat'))]),
                        selected: current == TransportType.boat,
                        onSelected: (_) => setState(() => _transportBetweenDestinations[origIdx] = TransportType.boat),
                        selectedColor: Theme.of(context).colorScheme.primaryContainer,
                        checkmarkColor: Theme.of(context).colorScheme.primary,
                      ),
                      FilterChip(
                        label: Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.directions_walk_rounded, size: 18, color: current == TransportType.walk ? Theme.of(context).colorScheme.onPrimaryContainer : Theme.of(context).colorScheme.onSurfaceVariant), const SizedBox(width: 6), Text(AppStrings.t(context, 'walk'))]),
                        selected: current == TransportType.walk,
                        onSelected: (_) => setState(() => _transportBetweenDestinations[origIdx] = TransportType.walk),
                        selectedColor: Theme.of(context).colorScheme.primaryContainer,
                        checkmarkColor: Theme.of(context).colorScheme.primary,
                      ),
                      FilterChip(
                        label: Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.help_outline_rounded, size: 18, color: current == TransportType.other ? Theme.of(context).colorScheme.onPrimaryContainer : Theme.of(context).colorScheme.onSurfaceVariant), const SizedBox(width: 6), Text(AppStrings.t(context, 'other'))]),
                        selected: current == TransportType.other,
                        onSelected: (_) => setState(() => _transportBetweenDestinations[origIdx] = TransportType.other),
                        selectedColor: Theme.of(context).colorScheme.primaryContainer,
                        checkmarkColor: Theme.of(context).colorScheme.primary,
                      ),
                      FilterChip(
                        label: Text(AppStrings.t(context, 'skip')),
                        selected: current == TransportType.unknown,
                        onSelected: (_) => setState(() => _transportBetweenDestinations.remove(origIdx)),
                        selectedColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppTheme.spacingMd),
                  TextFormField(
                    initialValue: _transportDescriptions[origIdx] ?? '',
                    onChanged: (v) => _transportDescriptions[origIdx] = v,
                    decoration: InputDecoration(
                      labelText: AppStrings.t(context, 'description_optional'),
                      hintText: AppStrings.t(context, 'transport_hint'),
                      border: const OutlineInputBorder(),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                    maxLines: 2,
                  ),
                ],
              ),
            ),
          );
        }),
        const SizedBox(height: AppTheme.spacingLg),
        FilledButton.icon(
          onPressed: _nextPage,
          icon: const Icon(Icons.arrow_forward, size: 20),
          label: Text(AppStrings.t(context, 'next_add_details')),
          style: FilledButton.styleFrom(minimumSize: const Size(double.infinity, 48)),
        ),
      ],
    );
  }

  List<_DestinationEntry> get _orderedDestinations {
    final list = _destinations.where((d) => d.name.isNotEmpty).toList();
    list.sort((a, b) {
      final aMin = a.days?.isNotEmpty == true ? a.days!.reduce((x, y) => x < y ? x : y) : 1;
      final bMin = b.days?.isNotEmpty == true ? b.days!.reduce((x, y) => x < y ? x : y) : 1;
      return aMin.compareTo(bMin);
    });
    return list;
  }

  /// Chronological (destination, day) pairs - each place appears once per day it's visited.
  /// Enables loops: e.g. airport on Day 1 and Day 7 appears twice in position.
  List<({_DestinationEntry d, int day})> get _chronologicalDestDayPairs {
    final pairs = <({_DestinationEntry d, int day})>[];
    for (final d in _destinations.where((x) => x.name.isNotEmpty)) {
      final days = (d.days ?? {1}).toList()..sort();
      if (days.isEmpty) pairs.add((d: d, day: 1));
      for (final day in days) {
        pairs.add((d: d, day: day));
      }
    }
    pairs.sort((a, b) => a.day.compareTo(b.day));
    return pairs;
  }

  Widget _buildStep5() {
    final pairs = _chronologicalDestDayPairs;
    return ListView(
      padding: const EdgeInsets.all(AppTheme.spacingMd),
      children: [
        Text(AppStrings.t(context, 'add_details_title'), style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: AppTheme.spacingXs),
        Text(AppStrings.t(context, 'add_details_subtitle'), style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
        const SizedBox(height: AppTheme.spacingLg),
        ...List.generate(pairs.length, (i) {
          final pair = pairs[i];
          final d = pair.d;
          final day = pair.day;
          final destIndex = _destinations.indexOf(d);
          final venues = d.venuesByDay[day] ?? [];
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            key: ValueKey('${d.name}_${day}_$i'),
            children: [
              _EditableLocationCard(
                destinationName: d.name,
                day: day,
                venues: venues,
                countryCodes: _selectedCountries,
                locationLatLng: d.lat != null && d.lng != null ? (d.lat!, d.lng!) : null,
                onAddVenue: (cat) => _addVenue(destIndex, cat, day),
                onRemoveVenue: (vi) => _removeVenue(destIndex, day, vi),
                onVenueSelected: (v, name, lat, lng, url) {
                  v.name = name;
                  v.lat = lat;
                  v.lng = lng;
                  v.externalUrl = url;
                  setState(() {});
                },
              ),
              if (i < pairs.length - 1 && pair.d != pairs[i + 1].d)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(width: 56),
                    const SizedBox(width: AppTheme.spacingMd),
                    Expanded(
                      child: Center(
                        child: TimelineConnector(
                          transport: _transportBetweenDestinations[i] ?? TransportType.unknown,
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          );
        }),
        if (pairs.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppTheme.spacingLg),
            child: Text(AppStrings.t(context, 'add_destinations_first'), style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ),
        const SizedBox(height: AppTheme.spacingLg),
        FilledButton.icon(
          onPressed: _nextPage,
          icon: const Icon(Icons.arrow_forward, size: 20),
          label: Text(AppStrings.t(context, 'next_review_trip')),
          style: FilledButton.styleFrom(minimumSize: const Size(double.infinity, 48)),
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
                          child: Center(child: Text(AppStrings.t(context, 'no_map_data'), style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant))),
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
              Text(AppStrings.t(context, 'all_destinations_details'), style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              ...(_chronologicalDestDayPairs.expand((pair) => [
                ListTile(
                  leading: Icon(Icons.place, color: Theme.of(context).colorScheme.primary),
                  title: Text('${pair.d.name} (Day ${pair.day})'),
                ),
                ...(pair.d.venuesByDay[pair.day] ?? []).where((v) => v.name.isNotEmpty).map((v) => Padding(
                    padding: const EdgeInsets.only(left: 40, bottom: 4),
                    child: Row(
                      children: [
                        Icon(_iconForCategory(v.category), size: 18, color: Theme.of(context).colorScheme.onSurfaceVariant),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(v.name, style: Theme.of(context).textTheme.bodyMedium, overflow: TextOverflow.ellipsis),
                        ),
                        const SizedBox(width: 4),
                        Text(_venueCategoryLabel(context, v.category), style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
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
                onPressed: () => _goToPage(5),
                child: Text(AppStrings.t(context, 'edit_details')),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: _isLoading ? null : _save,
                  icon: _isLoading
                      ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Theme.of(context).colorScheme.onPrimary))
                      : const Icon(Icons.save, size: 20),
                  label: Text(_isLoading ? AppStrings.t(context, 'saving') : AppStrings.t(context, 'save_trip')),
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
      case 'bar': return Icons.local_bar;
      default: return Icons.restaurant;
    }
  }

}

class _EditableLocationCard extends StatelessWidget {
  final String destinationName;
  final int day;
  final List<_VenueEntry> venues;
  final List<String> countryCodes;
  final (double, double)? locationLatLng;
  final void Function(String category) onAddVenue;
  final void Function(int venueIndex) onRemoveVenue;
  final void Function(_VenueEntry v, String name, double? lat, double? lng, String? url) onVenueSelected;

  const _EditableLocationCard({
    required this.destinationName,
    required this.day,
    required this.venues,
    required this.countryCodes,
    this.locationLatLng,
    required this.onAddVenue,
    required this.onRemoveVenue,
    required this.onVenueSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingMd),
        child: SingleChildScrollView(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 56,
                child: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${AppStrings.t(context, 'day')} $day',
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: AppTheme.spacingMd),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      destinationName,
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: AppTheme.spacingMd),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        FilledButton.tonal(
                          onPressed: () => onAddVenue('restaurant'),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.restaurant, size: 18), const SizedBox(width: 6), Text(AppStrings.t(context, 'restaurant'))]),
                        ),
                        FilledButton.tonal(
                          onPressed: () => onAddVenue('hotel'),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.hotel, size: 18), const SizedBox(width: 6), Text(AppStrings.t(context, 'hotel'))]),
                        ),
                        FilledButton.tonal(
                          onPressed: () => onAddVenue('guide'),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.tour, size: 18), const SizedBox(width: 6), Text(AppStrings.t(context, 'guide'))]),
                        ),
                        FilledButton.tonal(
                          onPressed: () => onAddVenue('bar'),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.local_bar, size: 18), const SizedBox(width: 6), Text(AppStrings.t(context, 'drinks'))]),
                        ),
                      ],
                    ),
                    if (venues.isNotEmpty) ...[
                      const SizedBox(height: AppTheme.spacingMd),
                      ...venues.asMap().entries.map((ve) {
                        final vi = ve.key;
                        final v = ve.value;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: v.name.isEmpty
                              ? Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: PlacesField(
                                        hint: '${AppStrings.t(context, 'search')} ${_venueCategoryLabel(context, v.category)}…',
                                        countryCodes: countryCodes,
                                        locationLatLng: locationLatLng,
                                        onSelected: (name, lat, lng, locationUrl, _) => onVenueSelected(v, name, lat, lng, locationUrl),
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.close, size: 20),
                                      onPressed: () => onRemoveVenue(vi),
                                    ),
                                  ],
                                )
                              : Chip(
                                  label: Text(v.name),
                                  deleteIcon: const Icon(Icons.close, size: 18),
                                  onDeleted: () => onRemoveVenue(vi),
                                ),
                        );
                      }),
                    ],
                    if (venues.isEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: AppTheme.spacingSm),
                        child: Text(AppStrings.t(context, 'no_places_added'), style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
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
}

class _DestinationEntry {
  String name = '';
  double? lat;
  double? lng;
  String? externalUrl;
  Set<int>? days; // specific days user was at this destination (non-contiguous)
  /// Venues per day: day number -> list of venues for that day.
  Map<int, List<_VenueEntry>> venuesByDay = {};
}

class _VenueEntry {
  String name = '';
  double? lat;
  double? lng;
  String? externalUrl;
  String? category;
}
