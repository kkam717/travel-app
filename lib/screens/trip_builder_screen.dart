// Trip Builder – single-screen create/edit itinerary.
// DATA MAPPING (no schema change): same payload as CreateItineraryScreen._save()
// - title -> title; days_count -> daysCount; countries -> destination (country names joined ", ")
// - mode, visibility, use_dates, start_date, end_date, duration_year/month/season -> unchanged
// - stopsData: chronological (location stop per day per city, then venue stops) day, position, stop_type, category, lat, lng
// - transport_transitions: length == chronologicalPairs.length - 1, type + optional description

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/theme.dart';
import '../core/constants.dart';
import '../core/analytics.dart';
import '../core/trip_builder_helpers.dart' show allocateDaysAcrossCities, autoBalanceDays, buildChronologicalPairsFromAllocations, CityDayPair, inferTransportTransitions;
import '../data/countries.dart' show countries, destinationToCountryCodes, travelStyles;
import '../l10n/app_strings.dart';
import '../models/itinerary.dart' show ItineraryStop, TransportTransition;
import '../services/places_service.dart';
import '../services/supabase_service.dart';
import '../widgets/places_field.dart';
import '../widgets/itinerary_map.dart';
import '../widgets/itinerary_timeline.dart' show TransportType, transportTypeFromString;

const int _kDefaultDays = 7;

String _formatDayRange(List<int> days) {
  if (days.isEmpty) return '';
  if (days.length == 1) return '${days.first}';
  var consecutive = true;
  for (var i = 1; i < days.length; i++) {
    if (days[i] != days[i - 1] + 1) {
      consecutive = false;
      break;
    }
  }
  return consecutive ? '${days.first}–${days.last}' : days.join(', ');
}

class _CityEntry {
  String name = '';
  double? lat;
  double? lng;
  String? externalUrl;
  int dayCount = 1;
}

class _VenueEntry {
  String name = '';
  double? lat;
  double? lng;
  String? externalUrl;
  String category = 'restaurant';
  int? rating; // 1–5 stars, optional
}

class TripBuilderScreen extends StatefulWidget {
  final String? itineraryId;
  final bool deleteOnDiscard;

  const TripBuilderScreen({super.key, this.itineraryId, this.deleteOnDiscard = false});

  @override
  State<TripBuilderScreen> createState() => _TripBuilderScreenState();
}

class _TripBuilderScreenState extends State<TripBuilderScreen> {
  final _titleController = TextEditingController();
  final _countryQueryController = TextEditingController();
  final _countryFieldKey = GlobalKey();
  final _countryFieldFocusNode = FocusNode();
  OverlayEntry? _countryOverlayEntry;
  int _daysCount = _kDefaultDays;
  String _mode = modeStandard;
  String _visibility = visibilityFriends; // only Public/Followers shown in UI; private used only when saving as draft
  List<String> _selectedCountries = [];
  String _countryQuery = '';
  bool _showCountrySuggestions = false;
  List<PlacePrediction> _countrySearchResults = [];
  bool _countrySearchLoading = false;
  Timer? _countrySearchDebounce;
  bool _useDates = false;
  DateTime? _startDate;
  DateTime? _endDate;
  int? _durationYear;
  int? _durationMonth;
  String? _durationSeason;
  final List<_CityEntry> _cities = [];
  List<int> _allocations = []; // day count per city index; length == _cities.length
  final Map<int, ({TransportType type, String? description})> _transportOverrides = {};
  // key: '${cityIndex}_$day' -> list of venue entries
  final Map<String, List<_VenueEntry>> _venuesByCityDay = {};
  bool _isLoading = false;
  bool _isLoadingData = false;
  final MapController _tripBuilderMapController = MapController();
  final DraggableScrollableController _sheetController = DraggableScrollableController();
  List<String> _selectedStyleTags = [];
  bool _costPerPersonEnabled = false;
  int _costPerPerson = 0; // USD, 0–10000+ (slider max 10000; text field can set higher)
  final TextEditingController _costPerPersonController = TextEditingController();
  /// Country code inferred from last added destination (API response). Not persisted.
  String? _lastAddedCountryCode;
  /// Runtime-only classic picks pool (up to 10). Not cached or persisted.
  List<PlacePrediction> _classicPicksSuggestions = [];
  /// Country codes we last fetched for (sorted list for comparison).
  List<String>? _classicPicksFetchedForCountryCodes;

  /// Per-day cost bounds by mode (Budget / Standard / Luxury). Trip total = per-day × trip length.
  static const int _costPerDayStandardMin = 30;
  static const int _costPerDayStandardMax = 300;
  static const int _costPerDayBudgetMax = 200;
  static const int _costPerDayLuxuryMin = 100;
  static const int _costPerDayLuxuryMax = 1000;

  /// Cost range depends on travel mode and trip length (day-by-day min/max).
  int get _costMin {
    final days = _daysCount.clamp(1, 365);
    switch (_mode) {
      case modeBudget: return 0;
      case modeLuxury: return _costPerDayLuxuryMin * days;
      default: return _costPerDayStandardMin * days; // standard
    }
  }
  int get _costSliderMax {
    final days = _daysCount.clamp(1, 365);
    switch (_mode) {
      case modeBudget: return _costPerDayBudgetMax * days;
      case modeLuxury: return _costPerDayLuxuryMax * days;
      default: return _costPerDayStandardMax * days; // standard
    }
  }
  int get _costMax {
    final days = _daysCount.clamp(1, 365);
    switch (_mode) {
      case modeBudget: return _costPerDayBudgetMax * days;
      case modeLuxury: return _costPerDayLuxuryMax * days;
      default: return _costPerDayStandardMax * days; // standard
    }
  }

  bool get _isEditMode => widget.itineraryId != null;

  /// When publishing: use selected visibility (public or friends). Draft saves use private without showing it.
  String get _effectivePublishVisibility => _visibility;

  /// Country results from API (only entries with a country code; deduped by code).
  List<PlacePrediction> get _countryResultsForOverlay {
    final seen = <String>{};
    return _countrySearchResults
        .where((p) => p.countryCode != null && p.countryCode!.isNotEmpty && seen.add(p.countryCode!.toUpperCase()))
        .toList();
  }

  Future<void> _searchCountries(String query) async {
    if (query.trim().length < 2) {
      if (mounted) setState(() { _countrySearchResults = []; _countrySearchLoading = false; });
      return;
    }
    if (!mounted) return;
    setState(() => _countrySearchLoading = true);
    try {
      final lang = Localizations.localeOf(context).languageCode;
      final results = await PlacesService.search(
        query.trim(),
        placeType: 'country',
        lang: lang,
      );
      if (!mounted) return;
      setState(() {
        _countrySearchResults = results;
        _countrySearchLoading = false;
      });
      _showCountryOverlay();
    } catch (_) {
      if (mounted) setState(() { _countrySearchResults = []; _countrySearchLoading = false; });
    }
  }

  void _addCountry(String code) {
    if (!_selectedCountries.contains(code)) {
      _removeCountryOverlay();
      setState(() {
        _selectedCountries.add(code);
        _countryQuery = '';
        _showCountrySuggestions = false;
        _countryQueryController.text = '';
        _classicPicksFetchedForCountryCodes = null;
      });
    }
  }

  void _removeCountryOverlay() {
    _countryOverlayEntry?.remove();
    _countryOverlayEntry = null;
  }

  void _showCountryOverlay() {
    _removeCountryOverlay();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final list = _countryResultsForOverlay;
      if (!mounted || !_showCountrySuggestions || list.isEmpty) return;
      final box = _countryFieldKey.currentContext?.findRenderObject() as RenderBox?;
      if (box == null) return;
      final overlay = Overlay.of(context);
      final pos = box.localToGlobal(Offset.zero);
      final size = box.size;
      final theme = Theme.of(context);
      _countryOverlayEntry = OverlayEntry(
        builder: (ctx) => Positioned(
          left: pos.dx,
          top: pos.dy + size.height + 4,
          width: size.width,
          child: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(12),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 220),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: list.length,
                itemBuilder: (_, i) {
                  final p = list[i];
                  final code = p.countryCode!;
                  final added = _selectedCountries.contains(code);
                  return ListTile(
                    dense: true,
                    leading: Icon(added ? Icons.check_circle : Icons.add_circle_outline, size: 20, color: added ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant),
                    title: Text(p.mainText, style: theme.textTheme.bodyMedium),
                    onTap: added ? null : () => _addCountry(code),
                  );
                },
              ),
            ),
          ),
        ),
      );
      overlay.insert(_countryOverlayEntry!);
    });
  }

  void _removeCountry(String code) {
    setState(() {
      _selectedCountries.remove(code);
      _classicPicksFetchedForCountryCodes = null;
    });
  }

  @override
  void initState() {
    super.initState();
    _countryFieldFocusNode.addListener(_onCountryFieldFocusChange);
    if (_isEditMode) _loadForEdit();
  }

  void _onCountryFieldFocusChange() {
    if (!_countryFieldFocusNode.hasFocus && mounted) {
      _removeCountryOverlay();
      setState(() => _showCountrySuggestions = false);
    }
  }

  Future<void> _loadForEdit() async {
    final id = widget.itineraryId!;
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
      _daysCount = it.daysCount;
      _mode = (it.mode ?? modeStandard).toLowerCase();
      _visibility = it.visibility == visibilityPrivate ? visibilityFriends : it.visibility;
      _selectedCountries = destinationToCountryCodes(it.destination).toList();
      _classicPicksFetchedForCountryCodes = null;
      _selectedStyleTags = it.styleTags.map((s) {
        if (s.isEmpty) return s;
        final lower = s.toLowerCase();
        for (final t in travelStyles) {
          if (t.toLowerCase() == lower) return t;
        }
        return s.length > 1 ? '${s[0].toUpperCase()}${s.substring(1).toLowerCase()}' : s.toUpperCase();
      }).toList();
      _costPerPersonEnabled = it.costPerPerson != null;
      _costPerPerson = (it.costPerPerson ?? 0).clamp(0, 999999999);
      _costPerPersonController.text = _costPerPerson.toString();
      _useDates = it.useDates ?? false;
      _startDate = it.startDate;
      _endDate = it.endDate;
      _durationYear = it.durationYear;
      _durationMonth = it.durationMonth;
      _durationSeason = it.durationSeason;
      _venuesByCityDay.clear();
      _cities.clear();
      _allocations.clear();
      _transportOverrides.clear();
      // Rebuild cities + allocations from stops
      final locationStopsByDay = <int, ({String name, double? lat, double? lng, String? url})>{};
      final venueStopsByDay = <int, List<_VenueEntry>>{};
      for (final s in it.stops) {
        if (s.day < 1) continue;
        if (s.isLocation) {
          locationStopsByDay[s.day] = (name: s.name, lat: s.lat, lng: s.lng, url: s.externalUrl);
        } else if (s.isVenue) {
          venueStopsByDay[s.day] ??= [];
          venueStopsByDay[s.day]!.add(_VenueEntry()
            ..name = s.name
            ..lat = s.lat
            ..lng = s.lng
            ..externalUrl = s.externalUrl
            ..category = s.category == 'experience' ? 'guide' : (s.category ?? 'restaurant')
            ..rating = s.rating);
        }
      }
      final days = locationStopsByDay.keys.toList()..sort();
      String? prevName;
      for (final day in days) {
        final loc = locationStopsByDay[day];
        if (loc == null) continue;
        if (prevName != loc.name) {
          _cities.add(_CityEntry()
            ..name = loc.name
            ..lat = loc.lat
            ..lng = loc.lng
            ..externalUrl = loc.url
            ..dayCount = 1);
          prevName = loc.name;
        } else if (_cities.isNotEmpty) {
          _cities.last.dayCount += 1;
        }
        for (final v in venueStopsByDay[day] ?? []) {
          final ci = _cities.length - 1;
          if (ci >= 0) {
            final key = '${ci}_$day';
            _venuesByCityDay[key] ??= [];
            _venuesByCityDay[key]!.add(v);
          }
        }
      }
      if (_cities.isNotEmpty) {
        _allocations = _cities.map((c) => c.dayCount).toList();
        if (_allocations.length != _cities.length) _allocations = allocateDaysAcrossCities(_daysCount, _cities.length);
      }
      if (it.transportTransitions != null) {
        for (var i = 0; i < it.transportTransitions!.length; i++) {
          final t = it.transportTransitions![i];
          _transportOverrides[i] = (type: transportTypeFromString(t.type), description: t.description);
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
    _countrySearchDebounce?.cancel();
    _countryFieldFocusNode.removeListener(_onCountryFieldFocusChange);
    _countryFieldFocusNode.dispose();
    _removeCountryOverlay();
    _titleController.dispose();
    _countryQueryController.dispose();
    _costPerPersonController.dispose();
    super.dispose();
  }

  List<CityDayPair> get _chronologicalPairs => buildChronologicalPairsFromAllocations(_allocations);

  /// Active country codes for classic picks: all selected countries, or last-added destination's country. Not persisted.
  List<String> get _activeCountryCodesForSuggestions {
    if (_selectedCountries.isNotEmpty) return List.from(_selectedCountries);
    if (_lastAddedCountryCode != null && _lastAddedCountryCode!.isNotEmpty) {
      return [_lastAddedCountryCode!];
    }
    return [];
  }

  static bool _sameCountryCodes(List<String> a, List<String>? b) {
    if (b == null || a.length != b.length) return false;
    final sa = a.toSet();
    final sb = b.toSet();
    return sa.length == sb.length && sa.containsAll(sb);
  }

  Future<void> _loadClassicPicksSuggestions() async {
    final codes = _activeCountryCodesForSuggestions;
    if (codes.isEmpty) {
      if (mounted) setState(() {
        _classicPicksSuggestions = [];
        _classicPicksFetchedForCountryCodes = null;
      });
      return;
    }
    final sorted = List<String>.from(codes)..sort();
    if (_sameCountryCodes(sorted, _classicPicksFetchedForCountryCodes)) return;
    try {
      final results = await PlacesService.searchClassicCitiesByCountry(codes, maxRows: 10);
      if (!mounted) return;
      setState(() {
        _classicPicksSuggestions = results;
        _classicPicksFetchedForCountryCodes = sorted;
      });
    } catch (_) {
      if (mounted) setState(() {
        _classicPicksSuggestions = [];
        _classicPicksFetchedForCountryCodes = sorted;
      });
    }
  }

  void _addCity(String name, double? lat, double? lng, String? url, [String? countryCode]) {
    setState(() {
      _lastAddedCountryCode = countryCode;
      _cities.add(_CityEntry()..name = name..lat = lat..lng = lng..externalUrl = url..dayCount = 1);
      _allocations = allocateDaysAcrossCities(_daysCount, _cities.length);
      for (var i = 0; i < _cities.length; i++) {
        _cities[i].dayCount = _allocations[i];
      }
      // Keep full pool; next build will show next 6 not yet in _cities
    });
  }

  void _removeCity(int index) {
    setState(() {
      _cities.removeAt(index);
      if (_cities.isEmpty) {
        _allocations = [];
      } else {
        _allocations = allocateDaysAcrossCities(_daysCount, _cities.length);
        for (var i = 0; i < _cities.length; i++) {
          _cities[i].dayCount = _allocations[i];
        }
      }
      _transportOverrides.clear();
      final keysToRemove = _venuesByCityDay.keys.where((k) => k.startsWith('${index}_') || _cityDayKeyToIndices(k).$1 >= index).toList();
      for (final k in keysToRemove) {
        _venuesByCityDay.remove(k);
      }
      _renumberVenueKeysAfterRemove(index);
    });
  }

  (int, int) _cityDayKeyToIndices(String key) {
    final parts = key.split('_');
    if (parts.length >= 2) {
      final ci = int.tryParse(parts[0]);
      final day = int.tryParse(parts[1]);
      if (ci != null && day != null) return (ci, day);
    }
    return (-1, -1);
  }

  void _renumberVenueKeysAfterRemove(int removedIndex) {
    final newMap = <String, List<_VenueEntry>>{};
    for (final e in _venuesByCityDay.entries) {
      final (ci, day) = _cityDayKeyToIndices(e.key);
      if (ci < 0) continue;
      if (ci == removedIndex) continue;
      final newCi = ci > removedIndex ? ci - 1 : ci;
      newMap['${newCi}_$day'] = e.value;
    }
    _venuesByCityDay
      ..clear()
      ..addAll(newMap);
  }

  void _setCityDayCount(int index, int newCount) {
    final maxForOne = _daysCount - (_cities.length - 1).clamp(0, _daysCount);
    newCount = newCount.clamp(1, maxForOne.clamp(1, _daysCount));
    setState(() {
      final rest = _daysCount - newCount;
      if (rest < 0 || (_cities.length > 1 && rest < _cities.length - 1)) return;
      _allocations[index] = newCount;
      _cities[index].dayCount = newCount;
      if (_cities.length == 1) return;
      final restAlloc = autoBalanceDays(rest, _cities.length - 1);
      var j = 0;
      for (var i = 0; i < _cities.length; i++) {
        if (i == index) continue;
        _allocations[i] = restAlloc[j];
        _cities[i].dayCount = restAlloc[j];
        j++;
      }
    });
  }

  void _autoBalanceCities() {
    setState(() {
      _allocations = autoBalanceDays(_daysCount, _cities.length);
      for (var i = 0; i < _cities.length; i++) {
        _cities[i].dayCount = _allocations[i];
      }
    });
  }

  void _setTransport(int segmentIndex, TransportType type, String? description) {
    setState(() {
      _transportOverrides[segmentIndex] = (type: type, description: description);
    });
  }

  void _addVenue(int cityIndex, int day, String category, String name, double? lat, double? lng, String? url, [int? rating]) {
    setState(() {
      final key = '${cityIndex}_$day';
      _venuesByCityDay[key] ??= [];
      _venuesByCityDay[key]!.add(_VenueEntry()
        ..name = name
        ..lat = lat
        ..lng = lng
        ..externalUrl = url
        ..category = category
        ..rating = rating);
    });
  }

  void _removeVenue(String key, int venueIndex) {
    setState(() {
      _venuesByCityDay[key]?.removeAt(venueIndex);
      if (_venuesByCityDay[key]?.isEmpty == true) _venuesByCityDay.remove(key);
    });
  }

  void _removeVenueGroup(int cityIndex, String name, String category) {
    setState(() {
      for (var day = 1; day <= _daysCount; day++) {
        final key = '${cityIndex}_$day';
        final list = _venuesByCityDay[key];
        if (list == null) continue;
        list.removeWhere((v) => v.name == name && v.category == category);
        if (list.isEmpty) _venuesByCityDay.remove(key);
      }
    });
  }

  void _moveVenueDay(String key, int venueIndex, int newDay) {
    final (ci, oldDay) = _cityDayKeyToIndices(key);
    if (ci < 0) return;
    final list = _venuesByCityDay[key];
    if (list == null || venueIndex >= list.length) return;
    final v = list[venueIndex];
    setState(() {
      list.removeAt(venueIndex);
      if (list.isEmpty) _venuesByCityDay.remove(key);
      final newKey = '${ci}_$newDay';
      _venuesByCityDay[newKey] ??= [];
      _venuesByCityDay[newKey]!.add(v);
    });
  }

  bool get _publishReady {
    if (_cities.isEmpty) return false;
    final pairs = _chronologicalPairs;
    if (pairs.isEmpty) return false;
    final daysCovered = pairs.map((p) => p.day).toSet();
    for (var d = 1; d <= _daysCount; d++) {
      if (!daysCovered.contains(d)) return false;
    }
    return true;
  }

  List<String> get _publishMissing {
    final missing = <String>[];
    if (_cities.isEmpty) missing.add(AppStrings.t(context, 'add_at_least_one_destination'));
    final pairs = _chronologicalPairs;
    final daysCovered = pairs.isEmpty ? <int>{} : pairs.map((p) => p.day).toSet();
    for (var d = 1; d <= _daysCount; d++) {
      if (!daysCovered.contains(d)) {
        missing.add('${AppStrings.t(context, 'day')} $d');
        break;
      }
    }
    return missing;
  }

  Future<void> _save({bool publish = false}) async {
    if (publish && !_publishReady) {
      await _showPublishMissingSheet();
      return;
    }
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;
    final destination = _selectedCountries.isEmpty && _cities.isNotEmpty
        ? _inferCountriesFromCities()
        : _selectedCountries.map((c) => countries[c] ?? c).join(', ');
    final pairs = _chronologicalPairs;
    final stopsData = <Map<String, dynamic>>[];
    var position = 0;
    for (final pair in pairs) {
      final ci = pair.cityIndex;
      final day = pair.day;
      if (ci >= _cities.length || day < 1 || day > _daysCount) continue;
      final city = _cities[ci];
      stopsData.add({
        'name': city.name,
        'category': 'location',
        'stop_type': 'location',
        'lat': city.lat,
        'lng': city.lng,
        'external_url': city.externalUrl,
        'day': day,
        'position': position++,
      });
      final key = '${ci}_$day';
      for (final v in _venuesByCityDay[key] ?? []) {
        if (v.name.isEmpty) continue;
        final dbCat = v.category == 'guide' ? 'experience' : v.category;
        stopsData.add({
          'name': v.name,
          'category': dbCat,
          'stop_type': 'venue',
          'lat': v.lat,
          'lng': v.lng,
          'external_url': v.externalUrl,
          'day': day,
          'position': position++,
          if (v.rating != null && v.rating! >= 1 && v.rating! <= 5) 'rating': v.rating,
        });
      }
    }
    // Only save transport when user has explicitly set at least one segment (no inferred default).
    final transportTransitions = pairs.length >= 2 && _transportOverrides.isNotEmpty
        ? inferTransportTransitions(
            pairs,
            (i) => _cities[i].lat,
            (i) => _cities[i].lng,
            userOverrides: _transportOverrides.map((k, v) => MapEntry(k, (type: v.type, description: v.description))),
          )
        : null;
    setState(() => _isLoading = true);
    try {
      if (_isEditMode) {
        final id = widget.itineraryId!;
        final updateData = <String, dynamic>{
          'title': _titleController.text.trim(),
          'destination': destination,
          'days_count': _daysCount,
          'mode': _mode.toLowerCase(),
          // Save = planning only (private). Publish = selected visibility (public/friends); removes from planning
          'visibility': publish ? _effectivePublishVisibility : visibilityPrivate,
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
          updateData['duration_year'] = _durationYear;
          updateData['duration_month'] = _durationMonth;
          updateData['duration_season'] = _durationSeason;
        }
        if (transportTransitions != null && transportTransitions.isNotEmpty) {
          updateData['transport_transitions'] = transportTransitions.map((t) => t.toJson()).toList();
        }
        updateData['style_tags'] = _selectedStyleTags.map((s) => s.toLowerCase()).toList();
        updateData['cost_per_person'] = _costPerPersonEnabled ? _costPerPerson : null;
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
          styleTags: _selectedStyleTags.map((s) => s.toLowerCase()).toList(),
          mode: _mode,
          visibility: publish ? _effectivePublishVisibility : visibilityPrivate,
          forkedFromId: null,
          stopsData: stopsData,
          useDates: _useDates,
          startDate: _useDates ? _startDate : null,
          endDate: _useDates ? _endDate : null,
          durationYear: _useDates ? null : _durationYear,
          durationMonth: _useDates ? null : _durationMonth,
          durationSeason: _useDates ? null : _durationSeason,
          transportTransitions: transportTransitions,
          costPerPerson: _costPerPersonEnabled ? _costPerPerson : null,
        );
        Analytics.logEvent('itinerary_created', {'id': it.id});
        if (mounted) context.go('/itinerary/${it.id}');
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppStrings.t(context, 'could_not_save'))));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _inferCountriesFromCities() {
    final names = _cities.map((c) => c.name).where((n) => n.isNotEmpty).toList();
    return names.isNotEmpty ? names.join(', ') : '';
  }

  Future<void> _showPublishMissingSheet() async {
    final missing = _publishMissing;
    if (missing.isEmpty) return;
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacingLg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(AppStrings.t(context, 'add_details_title'), style: Theme.of(ctx).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Text(missing.join(', '), style: Theme.of(ctx).textTheme.bodyMedium),
              const SizedBox(height: AppTheme.spacingLg),
              SizedBox(
                width: double.infinity,
                child: FilledButton(onPressed: () => Navigator.pop(ctx), child: Text(AppStrings.t(context, 'close'))),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<TransportTransition> get _transportTransitionsForMap {
    final pairs = _chronologicalPairs;
    if (pairs.length < 2) return [];
    return inferTransportTransitions(
      pairs,
      (i) => _cities[i].lat,
      (i) => _cities[i].lng,
      userOverrides: _transportOverrides.map((k, v) => MapEntry(k, (type: v.type, description: v.description))),
    );
  }

  List<ItineraryStop> get _stopsForMap {
    final stops = <ItineraryStop>[];
    for (final pair in _chronologicalPairs) {
      final ci = pair.cityIndex;
      final day = pair.day;
      if (ci >= _cities.length) continue;
      final city = _cities[ci];
      stops.add(ItineraryStop(
        id: 'tb_${city.name}_$day',
        itineraryId: '',
        position: 0,
        day: day,
        name: city.name,
        category: 'location',
        stopType: 'location',
        lat: city.lat,
        lng: city.lng,
        externalUrl: city.externalUrl,
      ));
      final key = '${ci}_$day';
      for (final v in _venuesByCityDay[key] ?? []) {
        if (v.name.isNotEmpty && v.lat != null && v.lng != null) {
          stops.add(ItineraryStop(
            id: 'tb_${v.name}_$day',
            itineraryId: '',
            position: 0,
            day: day,
            name: v.name,
            category: v.category,
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

  @override
  Widget build(BuildContext context) {
    Analytics.logScreenView('trip_builder');
    final theme = Theme.of(context);
    final viewInsetsBottom = MediaQuery.viewInsetsOf(context).bottom;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
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
        if (leave == true && mounted) {
          if (context.canPop()) {
            context.pop();
          } else {
            context.go('/home');
          }
        }
      },
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        backgroundColor: theme.colorScheme.surface,
        appBar: _isLoadingData
            ? null
            : AppBar(
                leading: Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Material(
                    color: theme.colorScheme.surface.withValues(alpha: 0.9),
                    shape: const CircleBorder(),
                    clipBehavior: Clip.antiAlias,
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back),
                      onPressed: () async {
                        final leave = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: Text(AppStrings.t(ctx, 'discard_changes')),
                            content: Text(AppStrings.t(ctx, 'unsaved_data_confirm')),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(AppStrings.t(ctx, 'cancel'))),
                              FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(AppStrings.t(ctx, 'discard'))),
                            ],
                          ),
                        );
                        if (!mounted) return;
                        if (leave == true) {
                          if (widget.deleteOnDiscard && widget.itineraryId != null) {
                            await SupabaseService.deleteItinerary(widget.itineraryId!);
                          }
                          if (mounted) {
                            if (context.canPop()) context.pop();
                            else context.go('/home');
                          }
                        }
                      },
                    ),
                  ),
                ),
                title: Text(AppStrings.t(context, 'add_trip')),
                backgroundColor: Colors.transparent,
                foregroundColor: theme.colorScheme.onSurface,
                elevation: 0,
                scrolledUnderElevation: 0,
              ),
        extendBodyBehindAppBar: true,
        body: _isLoadingData
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(width: 40, height: 40, child: CircularProgressIndicator(strokeWidth: 2, color: theme.colorScheme.primary)),
                    const SizedBox(height: AppTheme.spacingLg),
                    Text(AppStrings.t(context, 'loading'), style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                  ],
                ),
              )
            : Stack(
                children: [
                  Positioned.fill(
                    child: _buildFullScreenMap(theme),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: MediaQuery.removeViewInsets(
                      context: context,
                      removeBottom: true,
                      child: SizedBox(
                        height: MediaQuery.sizeOf(context).height * 0.95,
                        child: DraggableScrollableSheet(
                          controller: _sheetController,
                          expand: false,
                          initialChildSize: 0.45,
                          minChildSize: 0.35,
                          maxChildSize: 0.95,
                          builder: (context, scrollController) {
                      return LayoutBuilder(
                        builder: (context, constraints) {
                          final minContentHeight = (constraints.maxHeight - 40).clamp(400.0, double.infinity);
                          return Container(
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surface,
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.1),
                                blurRadius: 10,
                                offset: const Offset(0, -2),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              Container(
                                margin: const EdgeInsets.symmetric(vertical: 12),
                                width: 40,
                                height: 4,
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.outline.withValues(alpha: 0.3),
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                              Expanded(
                                child: Container(
                                  color: theme.colorScheme.surface,
                                  child: ListView(
                                    controller: scrollController,
                                    padding: const EdgeInsets.fromLTRB(AppTheme.spacingMd, 0, AppTheme.spacingMd, AppTheme.spacingMd),
                                    children: [
                                      LayoutBuilder(
                                        builder: (context, constraints) {
                                          final minH = (minContentHeight - 100).clamp(320.0, double.infinity);
                                          return Container(
                                            constraints: BoxConstraints(minHeight: minH),
                                            color: theme.colorScheme.surface,
                                            child: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              crossAxisAlignment: CrossAxisAlignment.stretch,
                                              children: [
                                                TextField(
                                  controller: _titleController,
                                  decoration: InputDecoration(
                                    hintText: AppStrings.t(context, 'trip_name_hint'),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                          ConstrainedBox(
                                            constraints: const BoxConstraints(minHeight: 44),
                                            child: Wrap(
                                              spacing: 8,
                                              runSpacing: 8,
                                              children: [
                                                _ChipLabel(
                                                  label: '$_daysCount ${AppStrings.t(context, 'days')}',
                                                  onTap: () => _showDaysSheet(),
                                                ),
                                                _ChipLabel(label: _modeLabel(theme), onTap: () => _showModeSheet()),
                                                _ChipLabel(label: _visibilityLabel(theme), onTap: () => _showVisibilitySheet()),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(height: 12),
                                          ConstrainedBox(
                                            constraints: const BoxConstraints(minHeight: 48),
                                            child: _buildTravelStylesRow(theme),
                                          ),
                                          const SizedBox(height: 12),
                                          ConstrainedBox(
                                            constraints: const BoxConstraints(minHeight: 48),
                                            child: _buildCountriesRow(theme),
                                          ),
                                          const SizedBox(height: 8),
                                          ConstrainedBox(
                                            constraints: const BoxConstraints(minHeight: 48),
                                            child: Material(
                                              color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                                              borderRadius: BorderRadius.circular(12),
                                              child: InkWell(
                                                onTap: () => _showDatesSheet(),
                                                borderRadius: BorderRadius.circular(12),
                                                child: Padding(
                                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                                  child: Row(
                                                    children: [
                                                      Icon(Icons.calendar_today_outlined, size: 20, color: theme.colorScheme.onSurfaceVariant),
                                                      const SizedBox(width: 10),
                                                      Expanded(
                                                        child: Text(
                                                          _useDates && _startDate != null && _endDate != null
                                                              ? '${_startDate!.month}/${_startDate!.day} – ${_endDate!.month}/${_endDate!.day} (${_endDate!.difference(_startDate!).inDays + 1} ${AppStrings.t(context, 'days')})'
                                                              : AppStrings.t(context, 'add_dates_optional'),
                                                          style: theme.textTheme.bodyMedium,
                                                        ),
                                                      ),
                                                      Icon(Icons.chevron_right, color: theme.colorScheme.onSurfaceVariant),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                          if (_selectedCountries.isNotEmpty || _cities.isNotEmpty) ...[
                                            const SizedBox(height: 10),
                                            SizedBox(
                                              width: double.infinity,
                                              child: FilledButton.icon(
                                                onPressed: () => _showAddCitySheet(),
                                                icon: const Icon(Icons.add, size: 20),
                                                label: Text(AppStrings.t(context, 'add_destination')),
                                                style: FilledButton.styleFrom(
                                                  backgroundColor: theme.colorScheme.primary,
                                                  foregroundColor: theme.colorScheme.onPrimary,
                                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                                ),
                                              ),
                                            ),
                                          ],
                                          const SizedBox(height: AppTheme.spacingMd),
                                          ConstrainedBox(
                                            constraints: const BoxConstraints(minHeight: 40),
                                            child: _buildRouteStrip(theme),
                                          ),
                                          const SizedBox(height: AppTheme.spacingLg),
                                          ConstrainedBox(
                                            constraints: const BoxConstraints(minHeight: 80),
                                            child: _buildDetailsTimeline(theme),
                                          ),
                                          const SizedBox(height: AppTheme.spacingLg),
                                          ConstrainedBox(
                                            constraints: const BoxConstraints(minHeight: 40),
                                            child: _buildCostPerPersonRow(theme),
                                          ),
                                                ],
                                              ),
                                            );
                                          },
                                        ),
                                    const SizedBox(height: AppTheme.spacingMd),
                                    _buildBottomBar(theme),
                                    SizedBox(height: viewInsetsBottom),
                                  ],
                                ),
                              ),
                            ),
                            ],
                          ),
                        );
                        },
                      );
                    },
                  ),
                  ),
                  ),
                  ),
                  ListenableBuilder(
                    listenable: _sheetController,
                    builder: (context, _) {
                      final height = MediaQuery.sizeOf(context).height;
                      final fraction = _sheetController.isAttached
                          ? _sheetController.size
                          : 0.45;
                      final bottom = height * fraction + 8;
                      return Positioned(
                        left: 0,
                        right: 0,
                        bottom: bottom,
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: Padding(
                            padding: const EdgeInsets.only(right: 16),
                            child: Material(
                              color: theme.colorScheme.surface.withValues(alpha: 0.95),
                              shape: const CircleBorder(),
                              clipBehavior: Clip.antiAlias,
                              elevation: 2,
                              child: IconButton(
                                icon: const Icon(Icons.explore),
                                tooltip: 'Reset to north',
                                onPressed: () {
                                  try {
                                    _tripBuilderMapController.rotate(0);
                                  } catch (_) {}
                                },
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildStickyHeader(ThemeData theme) {
    return Material(
      color: theme.colorScheme.surface,
      elevation: 0,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, AppTheme.spacingMd, AppTheme.spacingSm),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  IconButton(icon: const Icon(Icons.arrow_back), onPressed: () async {
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
                    if (leave == true && mounted) {
                      if (widget.deleteOnDiscard && widget.itineraryId != null) {
                        await SupabaseService.deleteItinerary(widget.itineraryId!);
                      }
                      if (context.canPop()) {
                        context.pop();
                      } else {
                        context.go('/home');
                      }
                    }
                  }),
                  Expanded(child: Text(AppStrings.t(context, 'add_trip'), style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700))),
                ],
              ),
              TextField(
                controller: _titleController,
                decoration: InputDecoration(
                  hintText: AppStrings.t(context, 'trip_name_hint'),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _ChipLabel(
                    label: '$_daysCount ${AppStrings.t(context, 'days')}',
                    onTap: () => _showDaysSheet(),
                  ),
                  _ChipLabel(label: _modeLabel(theme), onTap: () => _showModeSheet()),
                  _ChipLabel(label: _visibilityLabel(theme), onTap: () => _showVisibilitySheet()),
                  _ChipLabel(
                    label: _selectedCountries.isEmpty
                        ? AppStrings.t(context, 'countries')
                        : _selectedCountries.length == 1
                            ? (countries[_selectedCountries.first] ?? _selectedCountries.first)
                            : _selectedCountries.length == 2
                                ? '${countries[_selectedCountries[0]] ?? _selectedCountries[0]}, ${countries[_selectedCountries[1]] ?? _selectedCountries[1]}'
                                : '${countries[_selectedCountries.first] ?? _selectedCountries.first} +${_selectedCountries.length - 1}',
                    onTap: () => _showCountriesSheet(),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Material(
                color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  onTap: () => _showDatesSheet(),
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        Icon(Icons.calendar_today_outlined, size: 20, color: theme.colorScheme.onSurfaceVariant),
                        const SizedBox(width: 10),
                        Text(
                            _useDates && _startDate != null && _endDate != null
                                ? '${_startDate!.month}/${_startDate!.day} – ${_endDate!.month}/${_endDate!.day} (${_endDate!.difference(_startDate!).inDays + 1} ${AppStrings.t(context, 'days')})'
                                : 'Add dates (optional)',
                            style: theme.textTheme.bodyMedium),
                        const Spacer(),
                        Icon(Icons.chevron_right, color: theme.colorScheme.onSurfaceVariant),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _modeLabel(ThemeData theme) {
    switch (_mode) {
      case modeBudget: return AppStrings.t(context, 'budget');
      case modeLuxury: return AppStrings.t(context, 'luxury');
      default: return AppStrings.t(context, 'standard');
    }
  }

  String _visibilityLabel(ThemeData theme) {
    return _visibility == visibilityPublic ? AppStrings.t(context, 'public') : AppStrings.t(context, 'followers_only');
  }

  static const _monthNames = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];
  String _monthLabel(int month, BuildContext ctx) {
    if (month < 1 || month > 12) return 'Month $month';
    return _monthNames[month - 1];
  }

  Widget _buildFullScreenMap(ThemeData theme) {
    final height = MediaQuery.sizeOf(context).height;
    return ItineraryMap(
      stops: _stopsForMap,
      destination: _selectedCountries.isNotEmpty ? _selectedCountries.map((c) => countries[c]).join(', ') : _cities.map((c) => c.name).join(', '),
      height: height,
      fullScreen: true,
      showWorldWhenEmpty: true,
      countryCodes: _selectedCountries.isEmpty ? null : _selectedCountries,
      mapController: _tripBuilderMapController,
      transportTransitions: _transportOverrides.isNotEmpty ? _transportTransitionsForMap : null,
    );
  }

  Widget _buildTravelStylesRow(ThemeData theme) {
    final count = _selectedStyleTags.length;
    final summary = count == 0
        ? AppStrings.t(context, 'tap_to_select')
        : count == 1
            ? _selectedStyleTags.first
            : '$count ${AppStrings.t(context, 'selected')}';
    return Material(
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: () => _showTravelStylesSheet(),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Icon(Icons.label_outline, size: 20, color: theme.colorScheme.onSurfaceVariant),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  summary,
                  style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ),
              Icon(Icons.chevron_right, color: theme.colorScheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showTravelStylesSheet() async {
    if (!mounted) return;
    List<String> selected = List.from(_selectedStyleTags);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (ctx, scrollController) => StatefulBuilder(
          builder: (ctx, setModalState) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.all(AppTheme.spacingMd),
                  child: Text(AppStrings.t(context, 'travel_styles'), style: Theme.of(ctx).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                ),
                Flexible(
                  child: SingleChildScrollView(
                    controller: scrollController,
                    padding: const EdgeInsets.fromLTRB(AppTheme.spacingMd, 0, AppTheme.spacingMd, AppTheme.spacingMd),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: travelStyles.map((style) {
                        final isSelected = selected.contains(style);
                        return FilterChip(
                          label: Text(style),
                          selected: isSelected,
                          onSelected: (_) {
                            setModalState(() {
                              if (isSelected) {
                                selected.remove(style);
                              } else {
                                selected.add(style);
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(AppTheme.spacingMd),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () {
                        setState(() => _selectedStyleTags = selected);
                        Navigator.pop(ctx);
                      },
                      child: Text(AppStrings.t(context, 'done')),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCostPerPersonRow(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                AppStrings.t(context, 'cost_per_person_optional'),
                style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
            Switch(
              value: _costPerPersonEnabled,
              onChanged: (v) {
                setState(() {
                  _costPerPersonEnabled = v;
                  if (!v) {
                    _costPerPerson = 0;
                  }
                  // when enabling, keep _costPerPerson as-is (often 0) so text input can type any value
                  _costPerPersonController.text = _costPerPerson.toString();
                });
              },
            ),
          ],
        ),
        if (_costPerPersonEnabled) ...[
          const SizedBox(height: 8),
          Slider(
            value: _costPerPerson.clamp(_costMin, _costSliderMax).toDouble(),
            min: _costMin.toDouble(),
            max: _costSliderMax.toDouble(),
            divisions: 20,
            label: _costPerPerson >= _costSliderMax ? '\$$_costSliderMax+' : '\$$_costPerPerson',
            onChanged: (v) {
              final n = v.round().clamp(_costMin, _costSliderMax);
              setState(() {
                _costPerPerson = n;
                _costPerPersonController.text = n.toString();
              });
            },
          ),
          Row(
            children: [
              Text(
                _costPerPerson >= _costSliderMax ? '\$$_costSliderMax+' : '\$$_costPerPerson',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 100,
                child: TextField(
                  controller: _costPerPersonController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    prefixText: '\$ ',
                    hintText: '0',
                    isDense: true,
                    border: const OutlineInputBorder(),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  ),
                  onChanged: (s) {
                    final n = int.tryParse(s.replaceAll(RegExp(r'[^\d]'), '')) ?? 0;
                    final value = n < 0 ? 0 : n;
                    if (value != _costPerPerson) setState(() => _costPerPerson = value);
                    if (n < 0 && _costPerPersonController.text != '0') {
                      _costPerPersonController.text = '0';
                    }
                  },
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildCountriesRow(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(AppStrings.t(context, 'countries_visited'), style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        if (_selectedCountries.isNotEmpty)
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: _selectedCountries.map((code) => Chip(
              label: Text(countries[code] ?? code),
              deleteIcon: Icon(Icons.close, size: 18, color: theme.colorScheme.onSurfaceVariant),
              onDeleted: () => _removeCountry(code),
            )).toList(),
          ),
        if (_selectedCountries.isNotEmpty) const SizedBox(height: 4),
        KeyedSubtree(
          key: _countryFieldKey,
          child: TextField(
            focusNode: _countryFieldFocusNode,
            controller: _countryQueryController,
            decoration: InputDecoration(
              hintText: AppStrings.t(context, 'search_and_add_countries'),
              prefixIcon: const Icon(Icons.search_outlined, size: 20),
              suffixIcon: _countrySearchLoading
                  ? Padding(
                      padding: const EdgeInsets.all(10),
                      child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Theme.of(context).colorScheme.primary)),
                    )
                  : null,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              isDense: true,
            ),
            onChanged: (v) {
              setState(() {
                _countryQuery = v;
                _showCountrySuggestions = v.isNotEmpty;
              });
              if (v.isNotEmpty) {
                _countrySearchDebounce?.cancel();
                _countrySearchDebounce = Timer(const Duration(milliseconds: 400), () => _searchCountries(v));
              } else {
                _removeCountryOverlay();
                setState(() {
                  _countrySearchResults = [];
                  _countrySearchLoading = false;
                });
              }
            },
            onTap: () {
              setState(() => _showCountrySuggestions = _countryQueryController.text.isNotEmpty);
              if (_countryQueryController.text.isNotEmpty) {
                if (_countryResultsForOverlay.isNotEmpty) _showCountryOverlay();
                else _searchCountries(_countryQueryController.text);
              } else _removeCountryOverlay();
            },
          ),
        ),
      ],
    );
  }

  Widget _buildMapSection(ThemeData theme) {
    final hasStops = _stopsForMap.any((s) => s.lat != null && s.lng != null);
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: SizedBox(
        height: 220,
        child: Stack(
          children: [
            hasStops
                ? ItineraryMap(
                    stops: _stopsForMap,
                    destination: _selectedCountries.isNotEmpty ? _selectedCountries.map((c) => countries[c]).join(', ') : _cities.map((c) => c.name).join(', '),
                    height: 220,
                    transportTransitions: _transportOverrides.isNotEmpty ? _transportTransitionsForMap : null,
                  )
                : Container(
                    color: theme.colorScheme.surfaceContainerHighest,
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.map_outlined, size: 48, color: theme.colorScheme.onSurfaceVariant),
                          const SizedBox(height: 8),
                          Text(AppStrings.t(context, 'add_destinations_for_map'), style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant), textAlign: TextAlign.center),
                        ],
                      ),
                    ),
                  ),
            Positioned(
              right: 12,
              bottom: 12,
              child: FilledButton.icon(
                onPressed: () => _showAddCitySheet(),
                icon: const Icon(Icons.add, size: 20),
                label: Text(AppStrings.t(context, 'add_destination')),
                style: FilledButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: theme.colorScheme.onPrimary,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// [alwaysShowSection] when true (e.g. in add-destination sheet), show "Classic picks" label and empty state when no suggestions.
  Widget _buildClassicPicksRow(ThemeData theme, {VoidCallback? onPickSelected, bool alwaysShowSection = false}) {
    final codes = _activeCountryCodesForSuggestions;
    if (codes.isEmpty && !alwaysShowSection) return const SizedBox.shrink();
    final sortedCodes = List<String>.from(codes)..sort();
    if (codes.isNotEmpty && !_sameCountryCodes(sortedCodes, _classicPicksFetchedForCountryCodes)) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadClassicPicksSuggestions());
    }
    final existingNames = _cities.map((c) => c.name).toSet();
    final toShow = _classicPicksSuggestions
        .where((p) => !existingNames.contains(p.mainText))
        .take(6)
        .toList();
    if (toShow.isEmpty && !alwaysShowSection) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(AppStrings.t(context, 'classic_picks'), style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant, fontWeight: FontWeight.w500)),
          const SizedBox(height: 6),
          if (toShow.isNotEmpty)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: toShow.map((p) {
                final url = p.osmUrl ?? (p.lat != null && p.lng != null ? 'https://www.openstreetmap.org/?mlat=${p.lat}&mlon=${p.lng}#map=17/${p.lat}/${p.lng}' : null);
                return Material(
                  color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(999),
                  child: InkWell(
                    onTap: () {
                      _addCity(p.mainText, p.lat, p.lng, url, p.countryCode);
                      onPickSelected?.call();
                    },
                    borderRadius: BorderRadius.circular(999),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.2), width: 1),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(p.mainText, style: theme.textTheme.labelLarge),
                    ),
                  ),
                );
              }).toList(),
            )
          else if (alwaysShowSection)
            Text(
              codes.isEmpty
                  ? AppStrings.t(context, 'add_at_least_one_country')
                  : 'No city suggestions for this country',
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
        ],
      ),
    );
  }

  Widget _buildRouteStrip(ThemeData theme) {
    if (_cities.isEmpty) return const SizedBox.shrink();
    final n = _cities.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 48,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: n * 2 - 1,
            separatorBuilder: (_, __) => const SizedBox(width: 6),
            itemBuilder: (context, index) {
              if (index.isOdd) {
                final segIdx = index ~/ 2;
                final override = _transportOverrides[segIdx];
                return _TransportChip(
                  type: override?.type ?? TransportType.unknown,
                  onTap: () => _showTransportSheet(segIdx),
                );
              }
              final ci = index ~/ 2;
              final city = _cities[ci];
              final dayCount = ci < _allocations.length ? _allocations[ci] : 1;
              return _CityChip(
                name: city.name.isEmpty ? '?' : city.name,
                dayCount: dayCount,
                onTap: () => _showCityMenuSheet(ci),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildDetailsTimeline(ThemeData theme) {
    final pairs = _chronologicalPairs;
    if (pairs.isEmpty) return const SizedBox.shrink();
    var dayStart = 1;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(AppStrings.t(context, 'add_details_title'), style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: AppTheme.spacingSm),
        ...List.generate(_cities.length, (ci) {
          final city = _cities[ci];
          final count = ci < _allocations.length ? _allocations[ci] : 1;
          final dayEnd = dayStart + count - 1;
          final dayRange = count == 1 ? '${AppStrings.t(context, 'day')} $dayStart' : '${AppStrings.t(context, 'days')} $dayStart–$dayEnd';
          final firstDay = dayStart;
          dayStart += count;
          return _DestinationSection(
            title: '${city.name} • $dayRange',
            cityIndex: ci,
            firstDay: firstDay,
            lastDay: dayEnd,
            venuesByDay: _venuesByCityDay,
            onAddHotel: () => _showAddVenueSheet(ci, firstDay, dayEnd, 'hotel'),
            onAddRestaurant: () => _showAddVenueSheet(ci, firstDay, dayEnd, 'restaurant'),
            onAddExperience: () => _showAddVenueSheet(ci, firstDay, dayEnd, 'guide'),
            onAddDrinks: () => _showAddVenueSheet(ci, firstDay, dayEnd, 'bar'),
            onAddCoffee: () => _showAddVenueSheet(ci, firstDay, dayEnd, 'coffee'),
            onRemoveVenue: _removeVenue,
            onRemoveVenueGroup: _removeVenueGroup,
            onMoveDay: _moveVenueDay,
            context: context,
            theme: theme,
          );
        }),
      ],
    );
  }

  Widget _buildBottomBar(ThemeData theme) {
    final bottomPadding = MediaQuery.paddingOf(context).bottom + 12;
    return Container(
      padding: EdgeInsets.fromLTRB(AppTheme.spacingMd, 12, AppTheme.spacingMd, bottomPadding),
      decoration: BoxDecoration(color: theme.colorScheme.surface, boxShadow: [BoxShadow(color: theme.colorScheme.shadow.withValues(alpha: 0.06), blurRadius: 12, offset: const Offset(0, -4))]),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: _isLoading ? null : () => _save(publish: false),
              child: Text(AppStrings.t(context, 'draft_save_btn')),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: FilledButton(
              onPressed: _isLoading ? null : () => _save(publish: true),
              style: FilledButton.styleFrom(backgroundColor: theme.colorScheme.primary),
                  child: _isLoading
                  ? SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: theme.colorScheme.onPrimary))
                  : Text(AppStrings.t(context, 'publish')),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showDaysSheet() async {
    int temp = _daysCount;
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.spacingLg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(AppStrings.t(context, 'number_of_days'), style: Theme.of(ctx).textTheme.titleMedium),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton.filled(onPressed: () => setModalState(() => temp = (temp - 1).clamp(1, 30)), icon: const Icon(Icons.remove)),
                    Padding(padding: const EdgeInsets.symmetric(horizontal: 24), child: Text('$temp', style: Theme.of(ctx).textTheme.headlineSmall)),
                    IconButton.filled(onPressed: () => setModalState(() => temp = (temp + 1).clamp(1, 30)), icon: const Icon(Icons.add)),
                  ],
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () {
                    setState(() {
                      _daysCount = temp;
                      if (_cities.isNotEmpty) {
                        _allocations = allocateDaysAcrossCities(_daysCount, _cities.length);
                        for (var i = 0; i < _cities.length; i++) {
                          _cities[i].dayCount = _allocations[i];
                        }
                      }
                    });
                    Navigator.pop(ctx);
                  },
                  child: Text(AppStrings.t(context, 'done')),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showModeSheet() async {
    final options = [modeBudget, modeStandard, modeLuxury];
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacingLg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(AppStrings.t(context, 'travel_style'), style: Theme.of(ctx).textTheme.titleMedium),
              const SizedBox(height: 12),
              ...options.map((m) => ListTile(
                title: Text(m == modeBudget ? AppStrings.t(context, 'budget') : m == modeLuxury ? AppStrings.t(context, 'luxury') : AppStrings.t(context, 'standard')),
                selected: _mode == m,
                onTap: () {
                  setState(() {
                    _mode = m;
                    if (_costPerPersonEnabled) {
                      _costPerPersonController.text = _costPerPerson.toString();
                    }
                  });
                  Navigator.pop(ctx);
                },
              )),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showVisibilitySheet() async {
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacingLg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(AppStrings.t(context, 'visibility'), style: Theme.of(ctx).textTheme.titleMedium),
              const SizedBox(height: 12),
              ListTile(title: Text(AppStrings.t(context, 'public')), selected: _visibility == visibilityPublic, onTap: () { setState(() => _visibility = visibilityPublic); Navigator.pop(ctx); }),
              ListTile(title: Text(AppStrings.t(context, 'followers_only')), selected: _visibility == visibilityFriends, onTap: () { setState(() => _visibility = visibilityFriends); Navigator.pop(ctx); }),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showCountriesSheet() async {
    final selected = List<String>.from(_selectedCountries);
    final entries = countries.entries.toList();
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (ctx, scrollController) => SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(AppTheme.spacingMd),
                child: Text(AppStrings.t(context, 'countries_visited'), style: Theme.of(ctx).textTheme.titleSmall),
              ),
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  itemCount: entries.length,
                  itemBuilder: (ctx, i) {
                    final e = entries[i];
                    final isSelected = selected.contains(e.key);
                    return ListTile(
                      title: Text(e.value),
                      trailing: isSelected ? Icon(Icons.check, color: Theme.of(ctx).colorScheme.primary) : null,
                      onTap: () {
                        if (isSelected) {
                          selected.remove(e.key);
                        } else {
                          selected.add(e.key);
                          Navigator.pop(ctx);
                        }
                        setState(() => _selectedCountries = List.from(selected));
                      },
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(AppTheme.spacingMd),
                child: FilledButton(onPressed: () => Navigator.pop(ctx), child: Text(AppStrings.t(context, 'done'))),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showDatesSheet() async {
    bool useDates = _useDates;
    DateTime? start = _startDate;
    DateTime? end = _endDate;
    int? year = _durationYear;
    int? month = _durationMonth;
    String? season = _durationSeason;
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppTheme.spacingLg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(AppStrings.t(context, 'trip_duration'), style: Theme.of(ctx).textTheme.titleMedium),
                const SizedBox(height: 12),
                SegmentedButton<bool>(
                  segments: [
                    ButtonSegment(value: true, label: Text(AppStrings.t(context, 'dates'))),
                    ButtonSegment(value: false, label: Text(AppStrings.t(context, 'month_season'))),
                  ],
                  selected: {useDates},
                  onSelectionChanged: (s) => setModalState(() => useDates = s.first),
                ),
                if (useDates) ...[
                  ListTile(
                    title: Text(AppStrings.t(context, 'start_date')),
                    subtitle: Text(start != null ? '${start!.month}/${start!.day}/${start!.year}' : AppStrings.t(context, 'tap_to_select')),
                    onTap: () async {
                      final d = await showDatePicker(context: ctx, initialDate: start ?? DateTime.now(), firstDate: DateTime(2020), lastDate: DateTime(2030));
                      if (d != null) setModalState(() => start = d);
                    },
                  ),
                  ListTile(
                    title: Text(AppStrings.t(context, 'end_date')),
                    subtitle: Text(end != null ? '${end!.month}/${end!.day}/${end!.year}' : AppStrings.t(context, 'tap_to_select')),
                    onTap: () async {
                      final d = await showDatePicker(context: ctx, initialDate: end ?? start ?? DateTime.now(), firstDate: start ?? DateTime(2020), lastDate: DateTime(2030));
                      if (d != null) setModalState(() => end = d);
                    },
                  ),
                  if (start != null && end != null && !end!.isBefore(start!))
                    Padding(
                      padding: const EdgeInsets.only(left: 16, top: 8),
                      child: Text(
                        '${AppStrings.t(context, 'duration')}: ${end!.difference(start!).inDays + 1} ${AppStrings.t(context, 'days')}',
                        style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(ctx).colorScheme.primary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                ] else ...[
                  ListTile(
                    title: Text(AppStrings.t(context, 'year')),
                    subtitle: Text(year != null ? year.toString() : AppStrings.t(context, 'tap_to_select')),
                    onTap: () async {
                      final now = DateTime.now();
                      const itemHeight = 56.0;
                      final currentYearIndex = 50;
                      final y = await showDialog<int>(
                        context: ctx,
                        builder: (c) => _YearPickerDialog(
                          now: now,
                          currentYearIndex: currentYearIndex,
                          itemHeight: itemHeight,
                          onSelected: (yVal) => Navigator.pop(c, yVal),
                        ),
                      );
                      if (y != null) setModalState(() => year = y);
                    },
                  ),
                  ListTile(
                    title: Text(AppStrings.t(context, 'month_season')),
                    subtitle: Text(
                      season != null
                          ? season!
                          : month != null
                              ? _monthLabel(month!, ctx)
                              : AppStrings.t(context, 'tap_to_select'),
                    ),
                    onTap: () async {
                      final picked = await showModalBottomSheet<String>(
                        context: ctx,
                        builder: (sheetCtx) => SafeArea(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(16),
                                child: Text(AppStrings.t(context, 'month_season'), style: Theme.of(sheetCtx).textTheme.titleMedium),
                              ),
                              ConstrainedBox(
                                constraints: const BoxConstraints(maxHeight: 320),
                                child: ListView(
                                  shrinkWrap: true,
                                  children: [
                                    ...List.generate(12, (i) {
                                      final m = i + 1;
                                      final label = _monthLabel(m, sheetCtx);
                                      return ListTile(
                                        title: Text(label),
                                        onTap: () => Navigator.pop(sheetCtx, 'month:$m'),
                                      );
                                    }),
                                    const Divider(height: 1),
                                    ListTile(title: Text('Spring'), onTap: () => Navigator.pop(sheetCtx, 'season:Spring')),
                                    ListTile(title: Text('Summer'), onTap: () => Navigator.pop(sheetCtx, 'season:Summer')),
                                    ListTile(title: Text('Fall'), onTap: () => Navigator.pop(sheetCtx, 'season:Fall')),
                                    ListTile(title: Text('Winter'), onTap: () => Navigator.pop(sheetCtx, 'season:Winter')),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                      if (picked != null && mounted) {
                        if (picked.startsWith('month:')) {
                          setModalState(() {
                            month = int.tryParse(picked.substring(6));
                            season = null;
                          });
                        } else if (picked.startsWith('season:')) {
                          setModalState(() {
                            season = picked.substring(7);
                            month = null;
                          });
                        }
                      }
                    },
                  ),
                ],
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () {
                    setState(() {
                      _useDates = useDates;
                      _startDate = start;
                      _endDate = end;
                      _durationYear = year;
                      _durationMonth = month;
                      _durationSeason = season;
                      if (useDates && start != null && end != null && !end!.isBefore(start!)) {
                        _daysCount = end!.difference(start!).inDays + 1;
                        if (_cities.isNotEmpty) {
                          _allocations = allocateDaysAcrossCities(_daysCount, _cities.length);
                          for (var i = 0; i < _cities.length; i++) {
                            _cities[i].dayCount = _allocations[i];
                          }
                        }
                      }
                    });
                    Navigator.pop(ctx);
                  },
                  child: Text(AppStrings.t(context, 'done')),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showAddCitySheet() async {
    if (!mounted) return;
    await _loadClassicPicksSuggestions();
    if (!mounted) return;
    final theme = Theme.of(context);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(AppTheme.spacingLg, AppTheme.spacingLg, AppTheme.spacingLg, MediaQuery.viewPaddingOf(ctx).bottom + AppTheme.spacingLg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(AppStrings.t(context, 'add_destination'), style: Theme.of(ctx).textTheme.titleMedium),
              const SizedBox(height: 12),
              PlacesField(
                hint: AppStrings.t(context, 'search_city_or_location'),
                countryCodes: _selectedCountries.isNotEmpty ? _selectedCountries : null,
                lang: Localizations.localeOf(ctx).languageCode,
                onSelected: (n, la, ln, u, countryCode) {
                  if (n.isNotEmpty) _addCity(n, la, ln, u, countryCode);
                  Navigator.pop(ctx);
                },
              ),
              _buildClassicPicksRow(theme, onPickSelected: () => Navigator.pop(ctx), alwaysShowSection: true),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showCityMenuSheet(int cityIndex) async {
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacingLg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ListTile(
                leading: const Icon(Icons.add),
                title: Text('+1 ${AppStrings.t(context, 'day')}'),
                onTap: () {
                  _setCityDayCount(cityIndex, (_allocations[cityIndex] + 1).clamp(1, _daysCount));
                  Navigator.pop(ctx);
                },
              ),
              ListTile(
                leading: const Icon(Icons.remove),
                title: Text('-1 ${AppStrings.t(context, 'day')}'),
                onTap: () {
                  _setCityDayCount(cityIndex, (_allocations[cityIndex] - 1).clamp(1, _daysCount));
                  Navigator.pop(ctx);
                },
              ),
              ListTile(leading: const Icon(Icons.balance), title: const Text('Auto-balance'), onTap: () { _autoBalanceCities(); Navigator.pop(ctx); }),
              ListTile(
                leading: Icon(Icons.delete_outline, color: Theme.of(ctx).colorScheme.error),
                title: Text(AppStrings.t(context, 'remove'), style: TextStyle(color: Theme.of(ctx).colorScheme.error)),
                onTap: () {
                  _removeCity(cityIndex);
                  Navigator.pop(ctx);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showTransportSheet(int segmentIndex) async {
    final override = _transportOverrides[segmentIndex];
    TransportType type = override?.type ?? TransportType.unknown;
    final descController = TextEditingController(text: override?.description ?? '');
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.spacingLg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(AppStrings.t(context, 'add_transport_title'), style: Theme.of(ctx).textTheme.titleMedium),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ...TransportType.values.where((t) => t != TransportType.unknown).map((t) => FilterChip(
                      label: Text(t.name),
                      selected: type == t,
                      onSelected: (_) => setModalState(() => type = t),
                    )),
                    FilterChip(label: Text(AppStrings.t(context, 'skip')), selected: type == TransportType.unknown, onSelected: (_) => setModalState(() => type = TransportType.unknown)),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descController,
                  decoration: InputDecoration(labelText: AppStrings.t(context, 'description_optional'), hintText: AppStrings.t(context, 'transport_hint')),
                  maxLines: 2,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    TextButton(onPressed: () => setModalState(() => type = TransportType.unknown), child: const Text('Reset to auto')),
                    const Spacer(),
                    FilledButton(
                      onPressed: () {
                        _setTransport(segmentIndex, type, descController.text.trim());
                        Navigator.pop(ctx);
                      },
                      child: Text(AppStrings.t(context, 'done')),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showAddVenueSheet(int cityIndex, int firstDay, int lastDay, String category) async {
    String name = '';
    double? lat;
    double? lng;
    String? url;
    Set<int> chosenDays = {firstDay};
    int? rating;
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(AppTheme.spacingLg, AppTheme.spacingLg, AppTheme.spacingLg, MediaQuery.viewPaddingOf(ctx).bottom + AppTheme.spacingLg),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('${AppStrings.t(context, 'add')} ${_venueCategoryLabel(category)}', style: Theme.of(ctx).textTheme.titleMedium),
                  const SizedBox(height: 12),
                  PlacesField(
                hint: '${AppStrings.t(context, 'search')} ${_venueCategoryLabel(category)}…',
                countryCodes: _selectedCountries.isNotEmpty ? _selectedCountries : null,
                locationLatLng: _cities[cityIndex].lat != null && _cities[cityIndex].lng != null ? (_cities[cityIndex].lat!, _cities[cityIndex].lng!) : null,
                lang: Localizations.localeOf(ctx).languageCode,
                onSelected: (n, la, ln, u, _) {
                  name = n;
                  lat = la;
                  lng = ln;
                  url = u;
                  setModalState(() {});
                },
              ),
                if (name.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Row(
                      children: [
                        Icon(Icons.check_circle_outline, size: 18, color: Theme.of(ctx).colorScheme.primary),
                        const SizedBox(width: 6),
                        Expanded(child: Text(name, style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis)),
                      ],
                    ),
                  ),
                const SizedBox(height: 12),
                Text(AppStrings.t(context, 'assign_days'), style: Theme.of(ctx).textTheme.titleSmall),
                const SizedBox(height: 4),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: List.generate(lastDay - firstDay + 1, (i) {
                      final d = firstDay + i;
                      final selected = chosenDays.contains(d);
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          label: Text('${AppStrings.t(context, 'day')} $d'),
                          selected: selected,
                          onSelected: (_) {
                            setModalState(() {
                              if (selected) {
                                chosenDays = Set.from(chosenDays)..remove(d);
                                if (chosenDays.isEmpty) chosenDays = {d};
                              } else {
                                chosenDays = Set.from(chosenDays)..add(d);
                              }
                            });
                          },
                        ),
                      );
                    }),
                  ),
                ),
                const SizedBox(height: 12),
                Text(AppStrings.t(context, 'rating_optional'), style: Theme.of(ctx).textTheme.titleSmall),
                const SizedBox(height: 4),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(5, (i) {
                    final star = i + 1;
                    final r = rating;
                    final selected = r != null && r >= star;
                    return IconButton(
                      icon: Icon(selected ? Icons.star_rounded : Icons.star_border_rounded, color: selected ? Colors.amber : Theme.of(ctx).colorScheme.onSurfaceVariant),
                      onPressed: () => setModalState(() => rating = rating == star ? null : star),
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    );
                  }),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () {
                    if (name.isNotEmpty) {
                      for (final day in chosenDays) {
                        _addVenue(cityIndex, day, category, name, lat, lng, url, rating);
                      }
                    }
                    Navigator.pop(ctx);
                  },
                  child: Text(AppStrings.t(context, 'add')),
                ),
              ],
            ),
            ),
          ),
        ),
      ),
    );
  }

  String _venueCategoryLabel(String cat) {
    switch (cat) {
      case 'hotel': return AppStrings.t(context, 'hotel');
      case 'guide': return AppStrings.t(context, 'guide');
      case 'bar': return AppStrings.t(context, 'drinks');
      case 'coffee': return AppStrings.t(context, 'coffee');
      default: return AppStrings.t(context, 'restaurant');
    }
  }
}

class _YearPickerDialog extends StatefulWidget {
  final DateTime now;
  final int currentYearIndex;
  final double itemHeight;
  final void Function(int) onSelected;

  const _YearPickerDialog({
    required this.now,
    required this.currentYearIndex,
    required this.itemHeight,
    required this.onSelected,
  });

  @override
  State<_YearPickerDialog> createState() => _YearPickerDialogState();
}

class _YearPickerDialogState extends State<_YearPickerDialog> {
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.jumpTo(widget.currentYearIndex * widget.itemHeight);
        }
      });
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 320),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(AppStrings.t(context, 'year'), style: Theme.of(context).textTheme.titleMedium),
            ),
            Flexible(
              child: ListView.builder(
                controller: _scrollController,
                itemExtent: widget.itemHeight,
                itemCount: 51,
                itemBuilder: (_, i) {
                  final yVal = widget.now.year - 50 + i;
                  return ListTile(
                    title: Text('$yVal'),
                    onTap: () => widget.onSelected(yVal),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChipLabel extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _ChipLabel({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.8),
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Padding(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8), child: Text(label, style: theme.textTheme.labelMedium)),
      ),
    );
  }
}

class _CityChip extends StatelessWidget {
  final String name;
  final int dayCount;
  final VoidCallback onTap;

  const _CityChip({required this.name, required this.dayCount, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.primaryContainer.withValues(alpha: 0.5),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(name.length > 12 ? '${name.substring(0, 12)}…' : name, style: theme.textTheme.labelLarge),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: theme.colorScheme.primary.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(8)),
                child: Text('$dayCount', style: theme.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TransportChip extends StatelessWidget {
  final TransportType type;
  final VoidCallback onTap;

  const _TransportChip({required this.type, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    IconData icon = Icons.swap_horiz_rounded;
    switch (type) {
      case TransportType.plane: icon = Icons.flight_rounded; break;
      case TransportType.train: icon = Icons.train_rounded; break;
      case TransportType.car: icon = Icons.directions_car_rounded; break;
      case TransportType.bus: icon = Icons.directions_bus_rounded; break;
      case TransportType.boat: icon = Icons.directions_boat_rounded; break;
      case TransportType.walk: icon = Icons.directions_walk_rounded; break;
      case TransportType.other: icon = Icons.help_outline_rounded; break;
      default: break;
    }
    return Material(
      color: theme.colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Icon(icon, size: 22, color: theme.colorScheme.onSurfaceVariant),
        ),
      ),
    );
  }
}

class _DestinationSection extends StatelessWidget {
  final String title;
  final int cityIndex;
  final int firstDay;
  final int lastDay;
  final Map<String, List<_VenueEntry>> venuesByDay;
  final VoidCallback onAddHotel;
  final VoidCallback onAddRestaurant;
  final VoidCallback onAddExperience;
  final VoidCallback onAddDrinks;
  final VoidCallback onAddCoffee;
  final void Function(String key, int venueIndex) onRemoveVenue;
  final void Function(int cityIndex, String name, String category) onRemoveVenueGroup;
  final void Function(String key, int venueIndex, int newDay) onMoveDay;
  final BuildContext context;
  final ThemeData theme;

  const _DestinationSection({
    required this.title,
    required this.cityIndex,
    required this.firstDay,
    required this.lastDay,
    required this.venuesByDay,
    required this.onAddHotel,
    required this.onAddRestaurant,
    required this.onAddExperience,
    required this.onAddDrinks,
    required this.onAddCoffee,
    required this.onRemoveVenue,
    required this.onRemoveVenueGroup,
    required this.onMoveDay,
    required this.context,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final grouped = <String, ({List<int> days, String name, String category})>{};
    for (var day = firstDay; day <= lastDay; day++) {
      final list = venuesByDay['${cityIndex}_$day'] ?? [];
      for (final v in list) {
        final key = '${v.name}|${v.category}';
        final existing = grouped[key];
        if (existing == null) {
          grouped[key] = (days: [day], name: v.name, category: v.category);
        } else {
          existing.days.add(day);
        }
      }
    }
    for (final g in grouped.values) {
      g.days.sort();
    }

    return Card(
      margin: const EdgeInsets.only(bottom: AppTheme.spacingMd),
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600))),
                IconButton(icon: const Icon(Icons.more_horiz), onPressed: () {}),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.tonal(onPressed: onAddHotel, child: Row(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.hotel_rounded, size: 18), const SizedBox(width: 6), Text(AppStrings.t(context, 'hotel'))])),
                FilledButton.tonal(onPressed: onAddRestaurant, child: Row(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.restaurant_rounded, size: 18), const SizedBox(width: 6), Text(AppStrings.t(context, 'restaurant'))])),
                FilledButton.tonal(onPressed: onAddExperience, child: Row(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.account_balance_rounded, size: 18), const SizedBox(width: 6), Text(AppStrings.t(context, 'guide'))])),
                FilledButton.tonal(onPressed: onAddDrinks, child: Row(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.local_bar_rounded, size: 18), const SizedBox(width: 6), Text(AppStrings.t(context, 'drinks'))])),
                FilledButton.tonal(onPressed: onAddCoffee, child: Row(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.coffee_rounded, size: 18), const SizedBox(width: 6), Text(AppStrings.t(context, 'coffee'))])),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final g in grouped.values)
                  Padding(
                    padding: const EdgeInsets.only(right: 6, bottom: 4),
                    child: Chip(
                      avatar: CircleAvatar(
                        backgroundColor: theme.colorScheme.primaryContainer,
                        child: Text(
                          _formatDayRange(g.days),
                          style: TextStyle(fontSize: 10, color: theme.colorScheme.onPrimaryContainer),
                        ),
                      ),
                      label: Text(g.name, overflow: TextOverflow.ellipsis, maxLines: 1),
                      deleteIcon: Icon(Icons.close, size: 18, color: theme.colorScheme.error),
                      onDeleted: () => onRemoveVenueGroup(cityIndex, g.name, g.category),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
