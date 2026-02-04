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
import '../widgets/profile_hero_banner.dart';
import '../widgets/profile_insight_card.dart';
import '../widgets/country_filter_chips.dart';
import '../widgets/trip_photo_card.dart';
import '../services/supabase_service.dart';
import '../core/locale_notifier.dart';
import '../l10n/app_strings.dart';

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
            // A) Hero banner: photo/gradient + overlay, QR/Settings, avatar, centered name, location + Edit pill, stat tiles
            SliverToBoxAdapter(
              child: ProfileHeroBanner(
                currentCity: hasCity ? currentCity : null,
                coverImageUrl: null,
                coverImageAsset: 'assets/images/profile_banner_hero.png',
                seedKey: userId,
                name: p.name?.trim().isNotEmpty == true ? p.name : null,
                photoUrl: p.photoUrl,
                onQrTap: () => context.push('/profile/qr', extra: {'userId': userId, 'userName': p.name}),
                onSettingsTap: () => context.push('/profile/settings'),
                onEditProfileTap: () => _showEditProfileSheet(p),
                onAvatarTap: _isUploadingPhoto ? null : _uploadPhoto,
                onCityTap: hasCity ? () => context.push('/city/${Uri.encodeComponent(currentCity!)}?userId=$userId') : null,
                isUploadingPhoto: _isUploadingPhoto,
                editProfileLabel: AppStrings.t(context, 'edit_profile'),
                statTilesRow: ProfileInsightCardsRow(
                  countriesCount: visitedCountries.length,
                  placesCount: livedCount,
                  currentCity: hasCity ? currentCity : null,
                  onCountriesTap: () async {
                    await context.push('/map/countries?codes=${visitedCountries.join(',')}&editable=1');
                    if (mounted) _load();
                  },
                  onPlacesTap: () async {
                    await context.push('/profile/stats');
                    if (mounted) _load();
                  },
                  onBaseTap: hasCity ? () => context.push('/city/${Uri.encodeComponent(currentCity!)}?userId=$userId') : () => context.push('/profile/stats'),
                ),
              ),
            ),
            // B) Main section: followers/following links, then Trips header + country filter chips
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(AppTheme.spacingLg, AppTheme.spacingLg, AppTheme.spacingLg, AppTheme.spacingSm),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
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
                    if (tripCountryCodes.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      CountryFilterChips(
                        countryCodes: tripCountryCodes,
                        selectedCode: _selectedCountryCode,
                        onSelected: (code) => setState(() => _selectedCountryCode = code),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            // C) Trip cards or empty state (CTA below so not behind nav)
            filteredTrips.isEmpty
                ? SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(AppTheme.spacingLg, AppTheme.spacingMd, AppTheme.spacingLg, AppTheme.spacingXl + 80),
                      child: Column(
                        children: [
                          Text(
                            AppStrings.t(context, 'no_trips_yet'),
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 16),
                          FilledButton.icon(
                            onPressed: () => context.push('/create'),
                            icon: const Icon(Icons.add, size: 20),
                            label: Text(AppStrings.t(context, 'create_first_trip_to_start')),
                          ),
                        ],
                      ),
                    ),
                  )
                : SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (_, i) => TripPhotoCard(
                        itinerary: filteredTrips[i],
                        onRefresh: _load,
                      ),
                      childCount: filteredTrips.length,
                      addRepaintBoundaries: true,
                    ),
                  ),
          ],
        ),
      ),
    );
  }

  Future<void> _showEditProfileSheet(Profile p) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.35,
        expand: false,
        builder: (_, scrollController) => ListView(
          controller: scrollController,
          padding: const EdgeInsets.all(AppTheme.spacingLg),
          children: [
            Text(
              AppStrings.t(context, 'edit_profile'),
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: AppTheme.spacingLg),
            ListTile(
              leading: const Icon(Icons.person_outline),
              title: Text(AppStrings.t(context, 'name')),
              subtitle: Text(p.name?.isNotEmpty == true ? p.name! : AppStrings.t(context, 'not_set')),
              trailing: const Icon(Icons.chevron_right),
              onTap: () async {
                Navigator.pop(ctx);
                await _showNameEditor(p.name ?? '', (name) => _updateProfile(name: name));
              },
            ),
            ListTile(
              leading: const Icon(Icons.location_city_outlined),
              title: Text(AppStrings.t(context, 'travel_stats')),
              subtitle: Text(AppStrings.t(context, 'home_town_lived_before')),
              trailing: const Icon(Icons.chevron_right),
              onTap: () async {
                Navigator.pop(ctx);
                final hasCity = p.currentCity?.trim().isNotEmpty == true;
                final hasPast = _pastCities.isNotEmpty;
                final hasStyles = p.travelStyles.isNotEmpty;
                String? open;
                if (!hasCity) open = 'current_city';
                else if (!hasPast) open = 'past_cities';
                else if (!hasStyles) open = 'travel_styles';
                await context.push(open != null ? '/profile/stats?open=$open' : '/profile/stats');
                if (mounted) _load();
              },
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
