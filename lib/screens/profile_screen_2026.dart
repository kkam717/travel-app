import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/theme.dart';
import '../core/analytics.dart';
import '../core/profile_cache.dart';
import '../core/profile_refresh_notifier.dart';
import '../models/profile.dart';
import '../models/itinerary.dart';
import '../models/user_city.dart';
import '../data/countries.dart';
import '../widgets/profile_hero_map.dart';
import '../widgets/profile_insight_card.dart';
import '../widgets/country_filter_chips.dart';
import '../widgets/profile_trip_grid_tile.dart';
import '../services/supabase_service.dart';
import '../l10n/app_strings.dart';
import 'expand_map_route.dart';

/// When true, use the 2026 profile layout (sliver hero, pill stats, modern trip cards).
const bool useProfile2026 = true;

List<String> _mergedVisitedCountries(Profile profile, List<Itinerary> itineraries) {
  final fromProfile = profile.visitedCountries.toSet();
  for (final it in itineraries) {
    for (final code in destinationToCountryCodes(it.destination)) {
      fromProfile.add(code);
    }
  }
  return fromProfile.toList()..sort();
}

class ProfileScreen2026 extends StatefulWidget {
  const ProfileScreen2026({super.key});

  @override
  State<ProfileScreen2026> createState() => _ProfileScreen2026State();
}

class _ProfileScreen2026State extends State<ProfileScreen2026> {
  Profile? _profile;
  List<Itinerary> _myItineraries = [];
  List<UserPastCity> _pastCities = [];
  int _followersCount = 0;
  int _followingCount = 0;
  bool _isLoading = true;
  String? _error;
  final ScrollController _scrollController = ScrollController();
  String? _selectedCountryCode;

  @override
  void initState() {
    super.initState();
    _initOrLoad();
    ProfileRefreshNotifier.addListener(_onRefreshRequested);
  }

  @override
  void dispose() {
    ProfileRefreshNotifier.removeListener(_onRefreshRequested);
    _scrollController.dispose();
    super.dispose();
  }

  void _onRefreshRequested() {
    if (mounted) _load(silent: true);
  }

  List<String> _tripCountryCodes() {
    final codes = <String>{};
    for (final it in _myItineraries) {
      codes.addAll(destinationToCountryCodes(it.destination));
    }
    return codes.toList()..sort();
  }

  List<Itinerary> _filteredTrips() {
    if (_selectedCountryCode == null) return _myItineraries;
    final name = countries[_selectedCountryCode];
    if (name == null) return _myItineraries;
    return _myItineraries.where((it) {
      final dest = it.destination.toLowerCase();
      return dest.contains(name.toLowerCase());
    }).toList();
  }

  void _initOrLoad() {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;
    if (ProfileCache.hasData(userId)) {
      final cached = ProfileCache.get(userId);
      if (mounted) {
        setState(() {
          _profile = cached.profile;
          _myItineraries = cached.myItineraries;
          _pastCities = cached.pastCities;
          _followersCount = cached.followersCount;
          _followingCount = cached.followingCount;
          _isLoading = false;
          _error = null;
        });
      }
      _load(silent: true);
    } else {
      _load(silent: false);
    }
  }

  Future<void> _load({bool silent = false}) async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;
    if (!mounted) return;
    if (!silent) setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        SupabaseService.getProfile(userId),
        SupabaseService.getUserItineraries(userId, publicOnly: false),
        SupabaseService.getPastCities(userId),
        SupabaseService.getFollowerCount(userId),
        SupabaseService.getFollowingCount(userId),
      ]);
      var myItineraries = results[1] as List<Itinerary>;
      if (myItineraries.isNotEmpty) {
        final ids = myItineraries.map((i) => i.id).toList();
        final likeCounts = await SupabaseService.getLikeCounts(ids);
        myItineraries = myItineraries.map((i) => i.copyWith(likeCount: likeCounts[i.id])).toList();
      }
      final profile = results[0] as Profile?;
      final pastCities = results[2] as List<UserPastCity>;
      final followersCount = results[3] as int;
      final followingCount = results[4] as int;
      if (!mounted) return;
      ProfileCache.put(
        userId,
        profile: profile,
        myItineraries: myItineraries,
        pastCities: pastCities,
        followersCount: followersCount,
        followingCount: followingCount,
      );
      setState(() {
        _profile = profile;
        _myItineraries = myItineraries;
        _pastCities = pastCities;
        _followersCount = followersCount;
        _followingCount = followingCount;
        _error = null;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      if (silent) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(AppStrings.t(context, 'could_not_refresh'))),
          );
        }
        return;
      }
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
      final bytes = await xfile.readAsBytes();
      final path = xfile.path;
      final ext = (path.contains('.') && !path.startsWith('blob:'))
          ? path.split('.').last.toLowerCase()
          : 'jpg';
      final url = await SupabaseService.uploadAvatar(userId, bytes, ext);
      await SupabaseService.updateProfile(userId, {'photo_url': url});
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppStrings.t(context, 'could_not_upload_photo'))),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploadingPhoto = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    Analytics.logScreenView('profile');
    if (_isLoading && _profile == null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 40,
                height: 40,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(height: AppTheme.spacingLg),
              Text(
                AppStrings.t(context, 'loading_profile'),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      );
    }
    if (_error != null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.spacingLg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.person_off_outlined, size: 64, color: Theme.of(context).colorScheme.outline),
                const SizedBox(height: AppTheme.spacingLg),
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: AppTheme.spacingLg),
                FilledButton.icon(
                  onPressed: _load,
                  icon: const Icon(Icons.refresh, size: 20),
                  label: Text(AppStrings.t(context, 'retry')),
                ),
              ],
            ),
          ),
        ),
      );
    }
    final p = _profile!;
    final userId = Supabase.instance.client.auth.currentUser?.id ?? p.id;
    final visitedCountries = _mergedVisitedCountries(p, _myItineraries);
    final currentCity = p.currentCity?.trim();
    final hasCity = currentCity != null && currentCity.isNotEmpty;
    final livedCount = (hasCity ? 1 : 0) + _pastCities.length;
    final filteredTrips = _filteredTrips();
    final tripCountryCodes = _tripCountryCodes();

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () => _load(silent: true),
        child: CustomScrollView(
          controller: _scrollController,
          slivers: [
            // A) Hero: Places visited world map + avatar overlay + map control, QR/Settings
            SliverToBoxAdapter(
              child: ProfileHeroMap(
                visitedCountryCodes: visitedCountries,
                photoUrl: p.photoUrl,
                isUploadingPhoto: _isUploadingPhoto,
                onAvatarTap: _uploadPhoto,
                onMapControlTap: () {},
                onMapTap: (Rect? sourceRect) async {
                  await Navigator.of(context, rootNavigator: true).push(ExpandMapRoute(
                    codes: visitedCountries,
                    canEdit: true,
                    sourceRect: sourceRect,
                  ));
                  if (mounted) _load();
                },
                onQrTap: () => context.push('/profile/qr', extra: {'userId': userId, 'userName': p.name}),
                onSettingsTap: () => context.push('/profile/settings'),
              ),
            ),
            // B) Identity row: name + Edit Profile, current city; then insight pills; then followers/following
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(AppTheme.spacingLg, 44 + 16, AppTheme.spacingLg, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _ProfileIdentityRow(
                      name: p.name?.trim().isNotEmpty == true ? p.name! : null,
                      currentCity: hasCity ? currentCity : null,
                      editProfileLabel: AppStrings.t(context, 'edit_profile'),
                      editProfileMenuItems: [
                        PopupMenuItem<String>(
                          value: 'name',
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.person_outline, size: 20),
                              const SizedBox(width: 12),
                              Text(AppStrings.t(context, 'name')),
                            ],
                          ),
                        ),
                        PopupMenuItem<String>(
                          value: 'travel_stats',
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.location_city_outlined, size: 20),
                              const SizedBox(width: 12),
                              Text(AppStrings.t(context, 'travel_stats')),
                            ],
                          ),
                        ),
                      ],
                      onEditProfileSelected: (value) async {
                        if (value == 'name') {
                          await _showNameEditor(p.name ?? '', (name) => _updateProfile(name: name));
                        } else if (value == 'travel_stats') {
                          final hCity = p.currentCity?.trim().isNotEmpty == true;
                          final hasPast = _pastCities.isNotEmpty;
                          final hasStyles = p.travelStyles.isNotEmpty;
                          String? open;
                          if (!hCity) {
                            open = 'current_city';
                          } else if (!hasPast) {
                            open = 'past_cities';
                          } else if (!hasStyles) {
                            open = 'travel_styles';
                          }
                          await context.push(open != null ? '/profile/stats?open=$open' : '/profile/stats');
                        }
                        if (mounted) _load();
                      },
                      onCityTap: hasCity
                          ? () => context.push('/city/${Uri.encodeComponent(currentCity)}?userId=$userId')
                          : () {
                              context.push('/profile/stats?open=current_city').then((_) {
                                if (mounted) _load();
                              });
                            },
                    ),
                    const SizedBox(height: AppTheme.spacingLg),
                    ProfileInsightCardsRow(
                      countriesCount: visitedCountries.length,
                      placesCount: livedCount,
                      onCountriesTap: () async {
                        await context.push('/map/countries?codes=${visitedCountries.join(',')}&editable=1');
                        if (mounted) _load();
                      },
                      onPlacesTap: () async {
                        await context.push('/profile/stats');
                        if (mounted) _load();
                      },
                    ),
                    const SizedBox(height: AppTheme.spacingLg),
                    _FollowersFollowingRow(
                      followersCount: _followersCount,
                      followingCount: _followingCount,
                      onFollowersTap: () => context.push('/profile/followers'),
                      onFollowingTap: () => context.push('/profile/following'),
                    ),
                    const SizedBox(height: AppTheme.spacingLg),
                    Text(
                      AppStrings.t(context, 'trips'),
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        fontSize: 22,
                      ),
                    ),
                    const SizedBox(height: 12),
                    CountryFilterChips(
                      countryCodes: tripCountryCodes,
                      selectedCode: _selectedCountryCode,
                      onSelected: (code) => setState(() => _selectedCountryCode = code),
                      showAllChip: true,
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
            // C) Trip grid (2 columns) or empty state as first tile
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(AppTheme.spacingLg, AppTheme.spacingMd, AppTheme.spacingLg, AppTheme.spacingXl + 80),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 0,
                  crossAxisSpacing: 0,
                  childAspectRatio: 0.82,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, i) {
                    if (filteredTrips.isEmpty) {
                      return i == 0
                          ? ProfileTripEmptyTile(onCreateTap: () => context.push('/create').then((_) => _load()))
                          : const SizedBox.shrink();
                    }
                    return ProfileTripGridTile(
                      itinerary: filteredTrips[i],
                      onRefresh: _load,
                      canEdit: true,
                    );
                  },
                  childCount: filteredTrips.isEmpty ? 1 : filteredTrips.length,
                  addRepaintBoundaries: true,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showNameEditor(String initial, void Function(String) onSave) async {
    final controller = TextEditingController(text: initial);
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacingLg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                AppStrings.t(context, 'edit_name'),
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: AppTheme.spacingLg),
              TextField(
                controller: controller,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  labelText: AppStrings.t(context, 'name'),
                  hintText: AppStrings.t(context, 'enter_your_name'),
                  prefixIcon: const Icon(Icons.person_outline),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: Text(AppStrings.t(context, 'cancel')),
                  ),
                  const Spacer(),
                  FilledButton(
                    onPressed: () {
                      final name = controller.text.trim();
                      if (name.isEmpty) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          SnackBar(content: Text(AppStrings.t(context, 'please_enter_name'))),
                        );
                      } else {
                        onSave(name);
                        Navigator.pop(ctx);
                        _load();
                      }
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

  Future<void> _updateProfile({String? name, List<String>? visitedCountries}) async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;
    final data = <String, dynamic>{};
    if (name != null) data['name'] = name;
    if (visitedCountries != null) data['visited_countries'] = visitedCountries;
    await SupabaseService.updateProfile(userId, data);
    await _load();
  }
}

/// Name (left), Edit Profile button (right); current city row below name.
class _ProfileIdentityRow extends StatelessWidget {
  final String? name;
  final String? currentCity;
  final String editProfileLabel;
  final List<PopupMenuEntry<String>> editProfileMenuItems;
  final void Function(String?) onEditProfileSelected;
  final VoidCallback? onCityTap;

  const _ProfileIdentityRow({
    this.name,
    this.currentCity,
    required this.editProfileLabel,
    required this.editProfileMenuItems,
    required this.onEditProfileSelected,
    this.onCityTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                name ?? AppStrings.t(context, 'profile'),
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.onSurface,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 12),
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: theme.colorScheme.shadow.withValues(alpha: 0.06),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Material(
                color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(20),
                child: PopupMenuButton<String>(
                onSelected: onEditProfileSelected,
                itemBuilder: (_) => editProfileMenuItems,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.edit_outlined, size: 18, color: theme.colorScheme.onSurface),
                      const SizedBox(width: 6),
                      Text(
                        editProfileLabel,
                        style: theme.textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: onCityTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.location_on_outlined,
                  size: 18,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 6),
                Text(
                  currentCity?.trim().isNotEmpty == true
                      ? currentCity!
                      : AppStrings.t(context, 'not_set'),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Followers and following count/links, placed above Trips in the main section.
class _FollowersFollowingRow extends StatelessWidget {
  final int followersCount;
  final int followingCount;
  final VoidCallback onFollowersTap;
  final VoidCallback onFollowingTap;

  const _FollowersFollowingRow({
    required this.followersCount,
    required this.followingCount,
    required this.onFollowersTap,
    required this.onFollowingTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
      fontWeight: FontWeight.w400,
    );
    return Row(
      children: [
        InkWell(
          onTap: onFollowersTap,
          borderRadius: BorderRadius.circular(6),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
            child: Text(
              '$followersCount ${AppStrings.t(context, 'followers')}',
              style: style,
            ),
          ),
        ),
        Text(
          ' · ',
          style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        InkWell(
          onTap: onFollowingTap,
          borderRadius: BorderRadius.circular(6),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
            child: Text(
              '$followingCount ${AppStrings.t(context, 'following')}',
              style: style,
            ),
          ),
        ),
      ],
    );
  }
}
