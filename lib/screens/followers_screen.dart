import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/theme.dart';
import '../core/analytics.dart';
import '../l10n/app_strings.dart';
import '../models/profile.dart';
import '../services/supabase_service.dart';

/// Shows either followers (people who follow the user) or following (people the user follows).
/// [userId] - whose list to show (defaults to current user)
/// [showFollowing] - if true, show people they follow; if false, show people who follow them
class FollowersScreen extends StatefulWidget {
  final String? userId;
  final bool showFollowing;

  const FollowersScreen({
    super.key,
    this.userId,
    this.showFollowing = false,
  });

  @override
  State<FollowersScreen> createState() => _FollowersScreenState();
}

class _FollowersScreenState extends State<FollowersScreen> {
  List<Profile> _profiles = [];
  bool _isLoading = true;
  String? _error;

  String get _effectiveUserId =>
      widget.userId ?? Supabase.instance.client.auth.currentUser?.id ?? '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(FollowersScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userId != widget.userId || oldWidget.showFollowing != widget.showFollowing) {
      _load();
    }
  }

  Future<void> _load() async {
    final userId = _effectiveUserId;
    if (userId.isEmpty) return;
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final profiles = widget.showFollowing
          ? await SupabaseService.getFollowing(userId)
          : await SupabaseService.getFollowers(userId);
      if (!mounted) return;
      setState(() {
        _profiles = profiles;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'could_not_refresh';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    Analytics.logScreenView(widget.showFollowing ? 'following' : 'followers');
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.showFollowing
              ? AppStrings.t(context, 'following')
              : AppStrings.t(context, 'followers'),
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 40,
                    height: 40,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: cs.primary,
                    ),
                  ),
                  const SizedBox(height: AppTheme.spacingLg),
                  Text(
                    widget.showFollowing
                        ? AppStrings.t(context, 'loading_following')
                        : AppStrings.t(context, 'loading_followers'),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
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
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.people_outline, size: 48, color: cs.outline),
                        ),
                        const SizedBox(height: AppTheme.spacingLg),
                        Text(
                          AppStrings.t(context, _error!),
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyLarge,
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
                )
              : _profiles.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(AppTheme.spacingXl),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                color: cs.primary.withValues(alpha: 0.08),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(Icons.people_outline_rounded, size: 48, color: cs.primary),
                            ),
                            const SizedBox(height: AppTheme.spacingLg),
                            Text(
                              widget.showFollowing
                                  ? AppStrings.t(context, 'not_following_anyone')
                                  : AppStrings.t(context, 'no_followers_yet'),
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: AppTheme.spacingSm),
                            Text(
                              widget.showFollowing
                                  ? AppStrings.t(context, 'find_people_follow')
                                  : AppStrings.t(context, 'share_trips_followers'),
                              textAlign: TextAlign.center,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: cs.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(
                            AppTheme.spacingLg, AppTheme.spacingMd, AppTheme.spacingLg, AppTheme.spacingXl),
                        itemCount: _profiles.length,
                        separatorBuilder: (_, __) => const SizedBox(height: AppTheme.spacingSm),
                        itemBuilder: (_, i) {
                          final p = _profiles[i];
                          return _FollowerCard(profile: p);
                        },
                      ),
                    ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Modern follower card
// ─────────────────────────────────────────────────────────────────────────────

class _FollowerCard extends StatelessWidget {
  final Profile profile;

  const _FollowerCard({required this.profile});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final cardColor = theme.brightness == Brightness.light
        ? Colors.white
        : cs.surfaceContainerHighest;

    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: cs.shadow.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: () => context.push('/author/${profile.id}'),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: cs.shadow.withValues(alpha: 0.08),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: CircleAvatar(
                    radius: 24,
                    backgroundImage: profile.photoUrl != null && profile.photoUrl!.isNotEmpty
                        ? NetworkImage(profile.photoUrl!)
                        : null,
                    backgroundColor: cs.surfaceContainerHighest,
                    child: profile.photoUrl == null || profile.photoUrl!.isEmpty
                        ? Icon(Icons.person_outline_rounded, size: 24, color: cs.onSurfaceVariant)
                        : null,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        profile.name ?? AppStrings.t(context, 'unknown'),
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: cs.onSurface,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (profile.currentCity != null && profile.currentCity!.trim().isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          profile.currentCity!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, size: 20, color: cs.onSurfaceVariant),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
