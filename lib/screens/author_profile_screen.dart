import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/theme.dart';
import '../data/countries.dart';
import '../models/itinerary.dart';
import '../models/profile.dart';
import '../models/user_city.dart';
import '../core/rate_limiter.dart';
import '../services/supabase_service.dart';
import '../l10n/app_strings.dart';
import '../widgets/profile_hero_map.dart';
import '../widgets/profile_insight_card.dart';
import '../widgets/country_filter_chips.dart';
import '../widgets/profile_trip_grid_tile.dart';
import 'expand_map_route.dart';

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
    } on RateLimitExceededException catch (_) {
      if (mounted) {
        setState(() => _isFollowing = !_isFollowing);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppStrings.t(context, 'rate_limit_try_again'))));
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

    final followPill = _isOwnProfile
        ? null
        : Material(
            color: Colors.white.withValues(alpha: 0.28),
            borderRadius: BorderRadius.circular(20),
            child: InkWell(
              onTap: _toggleFollow,
              borderRadius: BorderRadius.circular(20),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(_isFollowing ? Icons.person_rounded : Icons.person_add_rounded, size: 18, color: Colors.white),
                    const SizedBox(width: 6),
                    Text(
                      _isFollowing ? AppStrings.t(context, 'following') : AppStrings.t(context, 'follow'),
                      style: theme.textTheme.labelLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ),
          );

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _load,
        child: CustomScrollView(
          controller: _scrollController,
          slivers: [
            // A) Hero: Places visited map + avatar, back button, follow/QR
            SliverToBoxAdapter(
              child: ProfileHeroMap(
                visitedCountryCodes: visitedCountries,
                photoUrl: p.photoUrl,
                isUploadingPhoto: false,
                onAvatarTap: null,
                onMapControlTap: () {},
                onMapTap: (Rect? sourceRect) async {
                  await Navigator.of(context).push(ExpandMapRoute(
                    codes: visitedCountries,
                    canEdit: false,
                    sourceRect: sourceRect,
                  ));
                  if (mounted) _load();
                },
                onQrTap: () => context.push('/author/${widget.authorId}/qr', extra: {'userName': p.name}),
                onSettingsTap: null,
                leadingWidget: Material(
                  color: Colors.white.withValues(alpha: 0.28),
                  shape: const CircleBorder(),
                  clipBehavior: Clip.antiAlias,
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back_rounded, size: 24, color: Colors.white),
                    onPressed: () {
                      if (context.canPop()) context.pop();
                      else context.go('/home');
                    },
                    style: IconButton.styleFrom(minimumSize: const Size(44, 44), padding: EdgeInsets.zero),
                  ),
                ),
                trailingWidget: null,
              ),
            ),
            // B) Identity: name + follow pill (if not own), current city; then insight; then followers
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(AppTheme.spacingLg, 44 + 16, AppTheme.spacingLg, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _AuthorIdentityRow(
                      name: p.name?.trim().isNotEmpty == true ? p.name : null,
                      currentCity: hasCity ? currentCity : null,
                      trailing: followPill,
                      onCityTap: hasCity
                          ? () => context.push('/city/${Uri.encodeComponent(currentCity!)}?userId=${widget.authorId}')
                          : null,
                    ),
                    const SizedBox(height: AppTheme.spacingLg),
                    ProfileInsightCardsRow(
                      countriesCount: visitedCountries.length,
                      placesCount: livedCount,
                      onCountriesTap: () => context.push('/map/countries?codes=${visitedCountries.join(',')}'),
                      onPlacesTap: () => context.push('/profile/stats?userId=${widget.authorId}'),
                    ),
                    const SizedBox(height: AppTheme.spacingLg),
                    _AuthorFollowersFollowingRow(
                      followersCount: _followersCount,
                      followingCount: _followingCount,
                      youFollowEachOther: !_isOwnProfile && _isMutualFriend,
                      onFollowersTap: () => context.push('/profile/followers?userId=${widget.authorId}'),
                      onFollowingTap: () => context.push('/profile/following?userId=${widget.authorId}'),
                    ),
                    const SizedBox(height: AppTheme.spacingLg),
                    Text(
                      AppStrings.t(context, 'trips'),
                      style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700, fontSize: 22),
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
            // C) Trip grid (2 columns) or empty state tile
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
                      canEdit: _isOwnProfile,
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
}

/// Name (left), optional trailing (e.g. follow pill); current city row below. For view-profile.
class _AuthorIdentityRow extends StatelessWidget {
  final String? name;
  final String? currentCity;
  final Widget? trailing;
  final VoidCallback? onCityTap;

  const _AuthorIdentityRow({
    this.name,
    this.currentCity,
    this.trailing,
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
            if (trailing != null) ...[
              const SizedBox(width: 12),
              trailing!,
            ],
          ],
        ),
        if (currentCity != null && currentCity!.trim().isNotEmpty) ...[
          const SizedBox(height: 8),
          InkWell(
            onTap: onCityTap,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.location_on_outlined, size: 18, color: theme.colorScheme.onSurfaceVariant),
                  const SizedBox(width: 6),
                  Text(
                    currentCity!,
                    style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _AuthorFollowersFollowingRow extends StatelessWidget {
  final int followersCount;
  final int followingCount;
  final bool youFollowEachOther;
  final VoidCallback onFollowersTap;
  final VoidCallback onFollowingTap;

  const _AuthorFollowersFollowingRow({
    required this.followersCount,
    required this.followingCount,
    this.youFollowEachOther = false,
    required this.onFollowersTap,
    required this.onFollowingTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant, fontWeight: FontWeight.w400);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
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
        ),
        if (youFollowEachOther) ...[
          const SizedBox(height: 4),
          Text(
            AppStrings.t(context, 'you_follow_each_other'),
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.primary, fontWeight: FontWeight.w500),
          ),
        ],
      ],
    );
  }
}
