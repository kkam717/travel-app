import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/theme.dart';
import '../core/analytics.dart';
import '../models/profile.dart';
import '../models/itinerary.dart';
import '../data/countries.dart';
import '../services/supabase_service.dart';

/// Merges profile visited countries with countries from all user itineraries.
List<String> _mergedVisitedCountries(Profile profile, List<Itinerary> itineraries) {
  final fromProfile = profile.visitedCountries.toSet();
  for (final it in itineraries) {
    for (final code in destinationToCountryCodes(it.destination)) {
      fromProfile.add(code);
    }
  }
  return fromProfile.toList()..sort();
}

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Profile? _profile;
  List<Itinerary> _myItineraries = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        SupabaseService.getProfile(userId),
        SupabaseService.getUserItineraries(userId, publicOnly: false),
      ]);
      if (!mounted) return;
      setState(() {
        _profile = results[0] as Profile?;
        _myItineraries = results[1] as List<Itinerary>;
        _error = null;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Something went wrong. Pull down to retry.';
        _isLoading = false;
      });
    }
  }

  bool _isUploadingPhoto = false;

  Future<void> _uploadPhoto() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;
    final picker = ImagePicker();
    final xfile = await picker.pickImage(source: ImageSource.gallery, maxWidth: 512, maxHeight: 512, imageQuality: 85);
    if (xfile == null) return;
    setState(() => _isUploadingPhoto = true);
    try {
      final bytes = await xfile.readAsBytes() as Uint8List;
      final ext = xfile.path.split('.').last;
      final url = await SupabaseService.uploadAvatar(userId, bytes, ext);
      await SupabaseService.updateProfile(userId, {'photo_url': url});
      await _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not upload photo. Please try again.')));
    } finally {
      if (mounted) setState(() => _isUploadingPhoto = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    Analytics.logScreenView('profile');
    if (_isLoading && _profile == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Profile')),
        body: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [Text(_error!, textAlign: TextAlign.center), const SizedBox(height: 16), FilledButton(onPressed: _load, child: const Text('Retry'))])),
      );
    }
    final p = _profile!;
    final visitedCountries = _mergedVisitedCountries(p, _myItineraries);
    return Scaffold(
      appBar: AppBar(title: const Text('Profile'), actions: [IconButton(icon: const Icon(Icons.logout), onPressed: () => _signOut())]),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(AppTheme.spacingMd),
          children: [
            Center(
              child: GestureDetector(
                onTap: _isUploadingPhoto ? null : _uploadPhoto,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CircleAvatar(
                      radius: 50,
                      backgroundImage: p.photoUrl != null ? NetworkImage(p.photoUrl!) : null,
                      child: p.photoUrl == null ? const Icon(Icons.person, size: 50) : null,
                    ),
                    if (_isUploadingPhoto)
                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(color: Colors.black38, shape: BoxShape.circle),
                        child: const Center(child: SizedBox(width: 32, height: 32, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))),
                      ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 24),
          _Section(title: 'Visited countries', count: visitedCountries.length, onEdit: () => _editVisitedCountries(p)),
          if (visitedCountries.isNotEmpty) ...[
            Wrap(spacing: 4, runSpacing: 4, children: visitedCountries.take(10).map((c) => Chip(label: Text(countries[c] ?? c))).toList()),
            if (visitedCountries.length > 10) Text('+${visitedCountries.length - 10} more', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
          ],
          const SizedBox(height: 16),
          _Section(title: 'Travel styles', count: p.travelStyles.length, onEdit: () => _editTravelStyles(p)),
          if (p.travelStyles.isNotEmpty) Wrap(spacing: 4, runSpacing: 4, children: p.travelStyles.map((s) => Chip(label: Text(s))).toList()),
          const SizedBox(height: 8),
          Text('Mode: ${p.travelMode ?? "Not set"}', style: TextStyle(color: Colors.grey[600])),
          const SizedBox(height: 24),
          _Section(title: 'Favourite countries (3)', count: p.favouriteCountries.length, onEdit: () => _editFavouriteCountries(p)),
          if (p.favouriteCountries.isNotEmpty) Wrap(spacing: 4, runSpacing: 4, children: p.favouriteCountries.map((c) => Chip(label: Text(countries[c] ?? c))).toList()),
          const SizedBox(height: 24),
          _Section(title: 'Places lived', count: p.citiesLived.length, onEdit: () => _editCitiesLived(p)),
          if (p.citiesLived.isNotEmpty) ...p.citiesLived.map((c) => ListTile(dense: true, title: Text('${c.city}, ${c.country}'))),
          const SizedBox(height: 24),
          _Section(title: 'Ideas / future trips', count: p.ideasFutureTrips.length, onEdit: () => _editIdeasTrips(p)),
          if (p.ideasFutureTrips.isNotEmpty) ...p.ideasFutureTrips.map((i) => ListTile(dense: true, title: Text(i.title), subtitle: Text(i.notes))),
          const SizedBox(height: 24),
          _Section(title: 'My itineraries', count: _myItineraries.length),
          if (_myItineraries.isNotEmpty) ...[
            const SizedBox(height: 8),
            ..._myItineraries.map((it) => Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    title: Text(it.title),
                    subtitle: Text('${it.destination} • ${it.daysCount} days'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push('/itinerary/${it.id}'),
                  ),
                )),
          ],
          const SizedBox(height: 24),
          _Section(title: 'Favourite trip', onEdit: () => _editFavouriteTrip(p)),
          if (p.favouriteTripTitle != null) ...[
            Text(p.favouriteTripTitle!, style: const TextStyle(fontWeight: FontWeight.bold)),
            if (p.favouriteTripDescription != null) Text(p.favouriteTripDescription!, style: TextStyle(color: Colors.grey[600])),
            if (p.favouriteTripLink != null)
              InkWell(
                onTap: () async {
                  final uri = Uri.tryParse(p.favouriteTripLink!);
                  if (uri != null && (uri.scheme == 'http' || uri.scheme == 'https')) {
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(uri, mode: LaunchMode.externalApplication);
                    }
                  }
                },
                child: Text(p.favouriteTripLink!, style: TextStyle(color: Colors.blue, decoration: TextDecoration.underline)),
              ),
          ],
          ],
        ),
      ),
    );
  }

  Future<void> _signOut() async {
    try {
      await Supabase.instance.client.auth.signOut();
      if (mounted) context.go('/');
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not sign out. Please try again.')));
    }
  }

  void _editVisitedCountries(Profile p) => _showCountriesEditor(p.visitedCountries, (list) => _updateProfile(visitedCountries: list));
  void _editFavouriteCountries(Profile p) => _showCountriesEditor(p.favouriteCountries, (list) => _updateProfile(favouriteCountries: list.take(3).toList()), max: 3);
  void _editTravelStyles(Profile p) => _showStylesEditor(p.travelStyles, (list) => _updateProfile(travelStyles: list));
  void _editCitiesLived(Profile p) => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Edit places lived - use profile edit screen')));
  void _editIdeasTrips(Profile p) => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Edit ideas - use profile edit screen')));
  void _editFavouriteTrip(Profile p) => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Edit favourite trip - use profile edit screen')));

  Future<void> _showCountriesEditor(List<String> initial, void Function(List<String>) onSave, {int? max}) async {
    Set<String> selected = initial.toSet();
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (_, setModal) {
          return DraggableScrollableSheet(
            initialChildSize: 0.7,
            expand: false,
            builder: (_, scrollController) => Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                      const Spacer(),
                      FilledButton(
                        onPressed: () {
                          onSave(selected.toList());
                          Navigator.pop(ctx);
                          _load();
                        },
                        child: const Text('Save'),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    itemCount: countries.length,
                    itemBuilder: (_, i) {
                      final e = countries.entries.elementAt(i);
                      final sel = selected.contains(e.key);
                      return CheckboxListTile(
                        value: sel,
                        onChanged: (v) {
                          setModal(() {
                            if (v == true) {
                              if (max == null || selected.length < max) selected.add(e.key);
                            } else {
                              selected.remove(e.key);
                            }
                          });
                        },
                        title: Text(e.value),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _showStylesEditor(List<String> initial, void Function(List<String>) onSave) async {
    Set<String> selected = initial.toSet();
    await showModalBottomSheet(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (_, setModal) => Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Travel styles', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: travelStyles.map((s) {
                  final sel = selected.contains(s);
                  return FilterChip(
                    label: Text(s),
                    selected: sel,
                    onSelected: (_) => setModal(() {
                      if (sel) selected.remove(s);
                      else selected.add(s);
                    }),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                  const Spacer(),
                  FilledButton(
                    onPressed: () {
                      onSave(selected.toList());
                      Navigator.pop(ctx);
                      _load();
                    },
                    child: const Text('Save'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _updateProfile({List<String>? visitedCountries, List<String>? travelStyles, List<String>? favouriteCountries}) async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;
    final data = <String, dynamic>{};
    if (visitedCountries != null) data['visited_countries'] = visitedCountries;
    if (travelStyles != null) data['travel_styles'] = travelStyles.map((s) => s.toLowerCase()).toList();
    if (favouriteCountries != null) data['favourite_countries'] = favouriteCountries;
    await SupabaseService.updateProfile(userId, data);
    await _load();
  }
}

class _Section extends StatelessWidget {
  final String title;
  final int? count;
  final VoidCallback? onEdit;

  const _Section({required this.title, this.count, this.onEdit});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
        if (count != null) Text(' ($count)', style: TextStyle(color: Colors.grey[600])),
        const Spacer(),
        if (onEdit != null) TextButton(onPressed: onEdit, child: const Text('Edit')),
      ],
    );
  }
}
