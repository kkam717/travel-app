import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/theme.dart';
import '../data/countries.dart';
import '../models/itinerary.dart';
import '../models/profile.dart';
import '../models/user_city.dart';
import '../services/supabase_service.dart';
import '../l10n/app_strings.dart';
import '../widgets/profile_hero_banner.dart';
import '../widgets/profile_stat_tiles_row.dart';
import '../widgets/country_filter_chips.dart';
import '../widgets/trip_photo_card.dart';

List<String> _mergedVisitedCountries(Profile? profile, List<Itinerary> itineraries) {
  final fromProfile = (profile?.visitedCountries ?? []).toSet();
  for (final it in itineraries) {
    for (final code in destinationToCountryCodes(it.destination)) {
      fromProfile.add(code);
    }
  }
  return fromProfile.toList()..sort();
}

class AuthorProfileScreen extends StatefulWidget {
  final String authorId;

  const AuthorProfileScreen({super.key, required this.authorId});

  @override
  State<AuthorProfileScreen> createState() => _AuthorProfileScreenState();
}

class _AuthorProfileScreenState extends State<AuthorProfileScreen> {
  Profile? _profile;
  List<Itinerary> _itineraries = [];
  List<UserPastCity> _pastCities = [];
  int _followersCount = 0;
  int _followingCount = 0;
  bool _isLoading = true;
  String? _error;
  bool _isFollowing = false;
  bool _isMutualFriend = false;
  final Map<String, bool> _liked = {};
  String? _selectedCountryCode;
  final ScrollController _scrollController = ScrollController();

  bool get _isOwnProfile => Supabase.instance.client.auth.currentUser?.id == widget.authorId;

  List<String> _tripCountryCodes() {
    final codes = <String>{};
    for (final it in _itineraries) {
      codes.addAll(destinationToCountryCodes(it.destination));
    }
    return codes.toList()..sort();
  }

  List<Itinerary> _filteredTrips() {
    if (_selectedCountryCode == null) return _itineraries;
    final name = countries[_selectedCountryCode];
    if (name == null) return _itineraries;
    return _itineraries.where((it) {
      final dest = it.destination.toLowerCase();
      return dest.contains(name.toLowerCase());
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      final isMutual = userId != null && !_isOwnProfile ? SupabaseService.isMutualFriend(userId, widget.authorId) : Future.value(false);
      final results = await Future.wait([
        SupabaseService.getProfile(widget.authorId),
        SupabaseService.getPastCities(widget.authorId),
        SupabaseService.getFollowerCount(widget.authorId),
        SupabaseService.getFollowingCount(widget.authorId),
        userId != null && !_isOwnProfile ? SupabaseService.isFollowing(userId, widget.authorId) : Future.value(false),
        isMutual,
      ]);
      final profile = results[0] as Profile?;
      final pastCities = results[1] as List<UserPastCity>;
      final followersCount = results[2] as int;
      final followingCount = results[3] as int;
      final isFollowing = results[4] as bool;
      final mutualFriend = results[5] as bool;
      var itineraries = await SupabaseService.getUserItineraries(widget.authorId, publicOnly: !_isOwnProfile && !mutualFriend);
      Map<String, bool> likedMap = {};
      if (itineraries.isNotEmpty && userId != null) {
        final ids = itineraries.map((i) => i.id).toList();
        final likeCounts = await SupabaseService.getLikeCounts(ids);
        itineraries = itineraries.map((i) => i.copyWith(likeCount: likeCounts[i.id])).toList();
        if (!_isOwnProfile) {
          final likedIds = await SupabaseService.getLikedItineraryIds(userId, ids);
          likedMap = {for (final id in ids) id: likedIds.contains(id)};
        }
      }
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _pastCities = pastCities;
        _itineraries = itineraries;
        _followersCount = followersCount;
        _followingCount = followingCount;
        _isFollowing = isFollowing;
        _isMutualFriend = mutualFriend;
        _liked.clear();
        _liked.addAll(likedMap);
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Something went wrong. Please try again.';
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleFollow() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null || _isOwnProfile) return;
    if (!mounted) return;
    setState(() => _isFollowing = !_isFollowing);
    try {
      if (_isFollowing) {
        await SupabaseService.followUser(userId, widget.authorId);
      } else {
        await SupabaseService.unfollowUser(userId, widget.authorId);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isFollowing = !_isFollowing);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppStrings.t(context, 'could_not_update_follow_status'))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading && _profile == null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(width: 40, height: 40, child: CircularProgressIndicator(strokeWidth: 2, color: Theme.of(context).colorScheme.primary)),
              const SizedBox(height: AppTheme.spacingLg),
              Text(AppStrings.t(context, 'loading_profile'), style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
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
                Text(_error!, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyLarge),
                const SizedBox(height: AppTheme.spacingLg),
                FilledButton.icon(onPressed: _load, icon: const Icon(Icons.refresh, size: 20), label: Text(AppStrings.t(context, 'retry'))),
              ],
            ),
          ),
        ),
      );
    }
    final p = _profile!;
    final currentCity = p.currentCity?.trim();
    final hasCity = currentCity != null && currentCity.isNotEmpty;
    final visitedCountries = _mergedVisitedCountries(p, _itineraries);
    final livedCount = (hasCity ? 1 : 0) + _pastCities.length;
    final filteredTrips = _filteredTrips();
    final tripCountryCodes = _tripCountryCodes();
    final theme = Theme.of(context);

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _load,
        child: CustomScrollView(
          controller: _scrollController,
          slivers: [
            SliverToBoxAdapter(
              child: ProfileHeroBanner(
                currentCity: hasCity ? currentCity : null,
                coverImageUrl: null,
                coverImageAsset: 'assets/images/profile_banner_hero.png',
                seedKey: widget.authorId,
                name: p.name?.trim().isNotEmpty == true ? p.name : null,
                photoUrl: p.photoUrl,
                leadingWidget: Material(
                  color: Colors.black.withValues(alpha: 0.45),
                  shape: const CircleBorder(),
                  clipBehavior: Clip.antiAlias,
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back_rounded, size: 24),
                    color: Colors.white,
                    onPressed: () {
                      if (context.canPop()) context.pop();
                      else context.go('/home');
                    },
                    style: IconButton.styleFrom(
                      minimumSize: const Size(44, 44),
                      padding: EdgeInsets.zero,
                    ),
                  ),
                ),
                actionPill: _isOwnProfile
                    ? null
                    : Material(
                        color: Colors.white.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(999),
                        child: InkWell(
                          onTap: _toggleFollow,
                          borderRadius: BorderRadius.circular(999),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(_isFollowing ? Icons.person_rounded : Icons.person_add_rounded, size: 16, color: Colors.white),
                                const SizedBox(width: 6),
                                Text(
                                  _isFollowing ? AppStrings.t(context, 'following') : AppStrings.t(context, 'follow'),
                                  style: theme.textTheme.labelLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                showSettingsIcon: false,
                onQrTap: () => context.push('/author/${widget.authorId}/qr', extra: {'userName': p.name}),
                onSettingsTap: null,
                onEditProfileTap: null,
                onAvatarTap: null,
                onCityTap: hasCity ? () => context.push('/city/${Uri.encodeComponent(currentCity!)}?userId=${widget.authorId}') : null,
                isUploadingPhoto: false,
                editProfileLabel: AppStrings.t(context, 'edit_profile'),
                statTilesRow: ProfileStatTilesRow(
                  countriesCount: visitedCountries.length,
                  livedCount: livedCount,
                  currentCity: hasCity ? currentCity : null,
                  onCountriesTap: () => context.push('/map/countries?codes=${visitedCountries.join(',')}'),
                  onLivedTap: () => context.push('/profile/stats?userId=${widget.authorId}'),
                  onHomeTap: hasCity ? () => context.push('/city/${Uri.encodeComponent(currentCity!)}?userId=${widget.authorId}') : () => context.push('/profile/stats?userId=${widget.authorId}'),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(AppTheme.spacingLg, AppTheme.spacingLg, AppTheme.spacingLg, AppTheme.spacingSm),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _AuthorFollowersFollowingRow(
                      followersCount: _followersCount,
                      followingCount: _followingCount,
                      onFollowersTap: () => context.push('/profile/followers?userId=${widget.authorId}'),
                      onFollowingTap: () => context.push('/profile/following?userId=${widget.authorId}'),
                    ),
                    const SizedBox(height: AppTheme.spacingLg),
                    Text(
                      AppStrings.t(context, 'trips'),
                      style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700, fontSize: 22),
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
            if (filteredTrips.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(AppTheme.spacingLg, AppTheme.spacingMd, AppTheme.spacingLg, AppTheme.spacingXl + 80),
                  child: Text(
                    AppStrings.t(context, 'no_trips_yet'),
                    style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ),
              )
            else
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (_, i) => TripPhotoCard(itinerary: filteredTrips[i], onRefresh: _load),
                  childCount: filteredTrips.length,
                  addRepaintBoundaries: true,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _AuthorFollowersFollowingRow extends StatelessWidget {
  final int followersCount;
  final int followingCount;
  final VoidCallback onFollowersTap;
  final VoidCallback onFollowingTap;

  const _AuthorFollowersFollowingRow({
    required this.followersCount,
    required this.followingCount,
    required this.onFollowersTap,
    required this.onFollowingTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.primary, fontWeight: FontWeight.w500);
    return Row(
      children: [
        InkWell(
          onTap: onFollowersTap,
          borderRadius: BorderRadius.circular(6),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
            child: Text('$followersCount ${AppStrings.t(context, 'followers')}', style: style),
          ),
        ),
        Text(' · ', style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        InkWell(
          onTap: onFollowingTap,
          borderRadius: BorderRadius.circular(6),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
            child: Text('$followingCount ${AppStrings.t(context, 'following')}', style: style),
          ),
        ),
      ],
    );
  }
}
