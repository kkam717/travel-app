import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/theme.dart';
import '../l10n/app_strings.dart';
import '../models/user_city.dart';
import '../services/places_service.dart';
import '../services/supabase_service.dart';
import '../utils/map_urls.dart';
import '../widgets/places_field.dart';

/// Screen for viewing/editing a city (current or past) with top spots.
class CityDetailScreen extends StatefulWidget {
  final String userId;
  final String cityName;
  final bool isOwnProfile;
  final bool isCurrentCity;

  const CityDetailScreen({
    super.key,
    required this.userId,
    required this.cityName,
    required this.isOwnProfile,
    this.isCurrentCity = false,
  });

  @override
  State<CityDetailScreen> createState() => _CityDetailScreenState();
}

class _CityDetailScreenState extends State<CityDetailScreen> {
  List<UserTopSpot> _spots = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final spots = await SupabaseService.getTopSpots(widget.userId, widget.cityName);
      if (!mounted) return;
      setState(() {
        _spots = spots;
        _isLoading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = 'Could not load spots.';
      });
    }
  }

  Map<String, List<UserTopSpot>> get _spotsByCategory {
    final map = <String, List<UserTopSpot>>{};
    for (final c in ['eat', 'drink', 'date', 'chill']) {
      map[c] = _spots.where((s) => s.category == c).toList()..sort((a, b) => a.position.compareTo(b.position));
    }
    return map;
  }

  IconData _iconForCategory(String cat) {
    switch (cat) {
      case 'eat':
        return Icons.restaurant;
      case 'drink':
        return Icons.local_bar;
      case 'date':
        return Icons.favorite;
      case 'chill':
        return Icons.beach_access;
      default:
        return Icons.place;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/home');
            }
          },
        ),
        title: Text(widget.cityName),
        actions: [
          if (widget.isOwnProfile)
            IconButton(
              icon: const Icon(Icons.add_circle_outline),
              onPressed: () => _addSpot(),
            ),
        ],
      ),
      body: _isLoading
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
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(AppTheme.spacingLg),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.error_outline, size: 64, color: Theme.of(context).colorScheme.outline),
                        const SizedBox(height: AppTheme.spacingLg),
                        Text(_error!, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyLarge),
                        const SizedBox(height: AppTheme.spacingLg),
                        FilledButton.icon(onPressed: _load, icon: const Icon(Icons.refresh, size: 20), label: Text(AppStrings.t(context, 'retry'))),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(AppTheme.spacingMd),
                    children: [
                      Text(
                        '${AppStrings.t(context, 'top_spots_in')} ${widget.cityName}',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: AppTheme.spacingLg),
                      ...['eat', 'drink', 'date', 'chill'].map((cat) {
                        final list = _spotsByCategory[cat] ?? [];
                        if (list.isEmpty && !widget.isOwnProfile) return const SizedBox.shrink();
                        return _CategorySection(
                          category: cat,
                          label: topSpotCategoryLabels[cat] ?? cat,
                          icon: _iconForCategory(cat),
                          spots: list,
                          isOwnProfile: widget.isOwnProfile,
                          onAdd: list.length < 5 ? () => _addSpot(category: cat) : null,
                          onEdit: widget.isOwnProfile ? (s) => _editSpot(s) : null,
                          onRemove: widget.isOwnProfile ? (s) => _removeSpot(s) : null,
                          onTap: (s) => _openSpot(s),
                        );
                      }),
                    ],
                  ),
                ),
    );
  }

  Future<void> _addSpot({String? category}) async {
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _SpotEditorSheet(
        cityName: widget.cityName,
        category: category,
        onSave: (data) => Navigator.pop(ctx, data),
      ),
    );
    if (result == null || !mounted) return;
    try {
      final spot = UserTopSpot(
        id: '',
        userId: widget.userId,
        cityName: widget.cityName,
        category: result['category'] as String,
        name: result['name'] as String,
        description: result['description'] as String?,
        locationUrl: result['location_url'] as String?,
        position: 0,
      );
      await SupabaseService.addTopSpot(spot);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppStrings.t(context, 'spot_added'))));
        _load();
      }
    } on StateError catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message ?? AppStrings.t(context, 'max_5_spots_per_category'))));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppStrings.t(context, 'could_not_add_spot'))));
    }
  }

  Future<void> _editSpot(UserTopSpot spot) async {
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _SpotEditorSheet(
        cityName: widget.cityName,
        category: spot.category,
        initialName: spot.name,
        initialDescription: spot.description,
        initialLocationUrl: spot.locationUrl,
        onSave: (data) => Navigator.pop(ctx, data),
      ),
    );
    if (result == null || !mounted) return;
    try {
      await SupabaseService.updateTopSpot(spot.id, {
        'name': result['name'],
        'description': result['description'],
        'location_url': result['location_url'],
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppStrings.t(context, 'spot_updated'))));
        _load();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppStrings.t(context, 'could_not_update_spot'))));
    }
  }

  Future<void> _removeSpot(UserTopSpot spot) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppStrings.t(context, 'remove_spot_confirm')),
        content: Text('${AppStrings.t(context, 'remove')} "${spot.name}" ${topSpotCategoryLabels[spot.category]}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(AppStrings.t(context, 'cancel'))),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(AppStrings.t(context, 'remove'))),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await SupabaseService.removeTopSpot(spot.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppStrings.t(context, 'spot_removed'))));
        _load();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppStrings.t(context, 'could_not_remove_spot'))));
    }
  }

  Future<void> _openSpot(UserTopSpot spot) async {
    final uri = MapUrls.buildTopSpotMapUrl(spot);
    if (uri != null) {
      try {
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        } else if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppStrings.t(context, 'could_not_open_maps'))));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppStrings.t(context, 'could_not_open_maps'))));
        }
      }
    } else {
      await showModalBottomSheet(
        context: context,
        builder: (ctx) => Padding(
          padding: const EdgeInsets.all(AppTheme.spacingLg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(spot.name, style: Theme.of(context).textTheme.titleLarge),
              if (spot.description != null && spot.description!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(spot.description!, style: Theme.of(context).textTheme.bodyMedium),
              ],
              if (spot.locationUrl == null || spot.locationUrl!.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Text(AppStrings.t(context, 'no_location_link'), style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                ),
            ],
          ),
        ),
      );
    }
  }
}

class _CategorySection extends StatelessWidget {
  final String category;
  final String label;
  final IconData icon;
  final List<UserTopSpot> spots;
  final bool isOwnProfile;
  final VoidCallback? onAdd;
  final void Function(UserTopSpot)? onEdit;
  final void Function(UserTopSpot)? onRemove;
  final void Function(UserTopSpot)? onTap;

  const _CategorySection({
    required this.category,
    required this.label,
    required this.icon,
    required this.spots,
    required this.isOwnProfile,
    this.onAdd,
    this.onEdit,
    this.onRemove,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.spacingLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 22, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 8),
              Text(label, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
              if (spots.isNotEmpty) Text(' (${spots.length})', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
              const Spacer(),
              if (onAdd != null)
                TextButton.icon(
                  onPressed: onAdd,
                  icon: const Icon(Icons.add, size: 18),
                  label: Text(AppStrings.t(context, 'add')),
                ),
            ],
          ),
          const SizedBox(height: AppTheme.spacingSm),
          if (spots.isEmpty && !isOwnProfile)
            Padding(
              padding: const EdgeInsets.only(left: 30),
              child: Text(AppStrings.t(context, 'no_spots'), style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
            )
          else
            ...spots.map((s) => _SpotTile(
                  spot: s,
                  onTap: onTap != null ? () => onTap!(s) : null,
                  onEdit: onEdit != null ? () => onEdit!(s) : null,
                  onRemove: onRemove != null ? () => onRemove!(s) : null,
                )),
        ],
      ),
    );
  }
}

class _SpotTile extends StatelessWidget {
  final UserTopSpot spot;
  final VoidCallback? onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onRemove;

  const _SpotTile({required this.spot, this.onTap, this.onEdit, this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 30, bottom: 8),
      child: Material(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(spot.name, style: Theme.of(context).textTheme.titleSmall),
                      if (spot.description != null && spot.description!.isNotEmpty)
                        Text(spot.description!, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant), maxLines: 2, overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
                if (onEdit != null || onRemove != null)
                  PopupMenuButton<String>(
                    icon: Icon(Icons.more_vert, size: 20, color: Theme.of(context).colorScheme.onSurfaceVariant),
                    onSelected: (v) {
                      if (v == 'edit') onEdit?.call();
                      if (v == 'remove') onRemove?.call();
                    },
                    itemBuilder: (_) => [
                      PopupMenuItem(value: 'edit', child: Text(AppStrings.t(context, 'edit'))),
                      PopupMenuItem(value: 'remove', child: Text(AppStrings.t(context, 'remove'))),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SpotEditorSheet extends StatefulWidget {
  final String cityName;
  final String? category;
  final String? initialName;
  final String? initialDescription;
  final String? initialLocationUrl;
  final void Function(Map<String, dynamic>) onSave;

  const _SpotEditorSheet({
    required this.cityName,
    this.category,
    this.initialName,
    this.initialDescription,
    this.initialLocationUrl,
    required this.onSave,
  });

  @override
  State<_SpotEditorSheet> createState() => _SpotEditorSheetState();
}

class _SpotEditorSheetState extends State<_SpotEditorSheet> {
  late String _category;
  late TextEditingController _descController;
  late Future<(double, double)?> _cityCoordsFuture;
  late Future<String?> _countryCodeFuture;
  String? _placeName;
  String? _placeId;
  bool _showSearch = false;

  @override
  void initState() {
    super.initState();
    _category = widget.category ?? 'eat';
    _descController = TextEditingController(text: widget.initialDescription);
    _placeName = widget.initialName;
    _showSearch = widget.initialName == null || widget.initialName!.isEmpty;
    _cityCoordsFuture = PlacesService.geocodeAddress(widget.cityName);
    _countryCodeFuture = PlacesService.geocodeToCountryCode(widget.cityName);
  }

  @override
  void dispose() {
    _descController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacingLg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
            Text(widget.initialName != null ? AppStrings.t(context, 'edit_spot') : AppStrings.t(context, 'add_spot'), style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: AppTheme.spacingLg),
            if (widget.category == null)
              DropdownButtonFormField<String>(
                value: _category,
                decoration: InputDecoration(labelText: AppStrings.t(context, 'category')),
                items: ['eat', 'drink', 'date', 'chill'].map((c) => DropdownMenuItem(value: c, child: Text(topSpotCategoryLabels[c] ?? c))).toList(),
                onChanged: (v) => setState(() => _category = v ?? 'eat'),
              ),
            const SizedBox(height: AppTheme.spacingMd),
            if (_showSearch) ...[
              FutureBuilder<List<dynamic>>(
                future: Future.wait([_cityCoordsFuture, _countryCodeFuture]),
                builder: (context, snapshot) {
                  final coords = snapshot.hasData ? snapshot.data![0] as (double, double)? : null;
                  final countryCode = snapshot.hasData ? snapshot.data![1] as String? : null;
                  return PlacesField(
                    hint: 'Search for a place in ${widget.cityName}…',
                    locationLatLng: coords,
                    countryCodes: countryCode != null && countryCode.isNotEmpty ? [countryCode] : null,
                    onSelected: (name, _, __, locationUrl) {
                      setState(() {
                        _placeName = name;
                        _placeId = locationUrl;
                        _showSearch = false;
                      });
                    },
                  );
                },
              ),
              if (widget.initialName != null && widget.initialName!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: TextButton(
                    onPressed: () => setState(() {
                      _placeName = widget.initialName;
                      _placeId = null;
                      _showSearch = false;
                    }),
                    child: Text(AppStrings.t(context, 'keep_current_place')),
                  ),
                ),
            ] else
              Row(
                children: [
                  Expanded(
                    child: Chip(
                      avatar: Icon(Icons.place, size: 20, color: Theme.of(context).colorScheme.primary),
                      label: Text(_placeName ?? ''),
                    ),
                  ),
                  TextButton(
                    onPressed: () => setState(() {
                      _showSearch = true;
                      _placeName = null;
                      _placeId = null;
                    }),
                    child: Text(AppStrings.t(context, 'change')),
                  ),
                ],
              ),
            const SizedBox(height: AppTheme.spacingMd),
            TextField(
              controller: _descController,
              decoration: InputDecoration(labelText: AppStrings.t(context, 'description_optional'), hintText: AppStrings.t(context, 'description_optional_short')),
              maxLines: 2,
            ),
            const SizedBox(height: AppTheme.spacingLg),
            Row(
              children: [
                TextButton(onPressed: () => Navigator.pop(context), child: Text(AppStrings.t(context, 'cancel'))),
                const Spacer(),
                FilledButton(
                  onPressed: () {
                    final name = _placeName?.trim();
                    if (name == null || name.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppStrings.t(context, 'please_search_select_place'))));
                      return;
                    }
                    final locationUrl = _placeId != null && (_placeName ?? '').trim().isNotEmpty
                        ? MapUrls.mapUrlFromPlace(_placeName!.trim(), null, null, _placeId)
                        : widget.initialLocationUrl;
                    widget.onSave({
                      'category': _category,
                      'name': name,
                      'description': _descController.text.trim().isEmpty ? null : _descController.text.trim(),
                      'location_url': locationUrl,
                    });
                  },
                  child: Text(AppStrings.t(context, 'save')),
                ),
              ],
            ),
            ],
          ),
        ),
      ),
    );
  }
}
