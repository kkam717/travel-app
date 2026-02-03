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
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.showFollowing ? AppStrings.t(context, 'following') : AppStrings.t(context, 'followers')),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
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
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: AppTheme.spacingLg),
                  Text(
                    widget.showFollowing ? AppStrings.t(context, 'loading_following') : AppStrings.t(context, 'loading_followers'),
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
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
                        Icon(
                          Icons.people_outline,
                          size: 64,
                          color: Theme.of(context).colorScheme.outline,
                        ),
                        const SizedBox(height: AppTheme.spacingLg),
                        Text(
                          AppStrings.t(context, _error!),
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
                )
              : _profiles.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(AppTheme.spacingLg),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.people_outline,
                              size: 64,
                              color: Theme.of(context).colorScheme.outline,
                            ),
                            const SizedBox(height: AppTheme.spacingLg),
                            Text(
                              widget.showFollowing ? AppStrings.t(context, 'not_following_anyone') : AppStrings.t(context, 'no_followers_yet'),
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: AppTheme.spacingSm),
                            Text(
                              widget.showFollowing ? AppStrings.t(context, 'find_people_follow') : AppStrings.t(context, 'share_trips_followers'),
                              textAlign: TextAlign.center,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(AppTheme.spacingMd),
                        itemCount: _profiles.length,
                        itemBuilder: (_, i) {
                          final p = _profiles[i];
                          return Card(
                            margin: const EdgeInsets.only(bottom: AppTheme.spacingMd),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundImage:
                                    p.photoUrl != null ? NetworkImage(p.photoUrl!) : null,
                                child: p.photoUrl == null
                                    ? Icon(
                                        Icons.person_outline,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurfaceVariant,
                                      )
                                    : null,
                              ),
                              title: Text(
                                p.name ?? AppStrings.t(context, 'unknown'),
                                style: Theme.of(context).textTheme.titleSmall,
                              ),
                              trailing: Icon(
                                Icons.chevron_right,
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                              onTap: () => context.push('/author/${p.id}'),
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}
