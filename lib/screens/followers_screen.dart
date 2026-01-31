import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/theme.dart';
import '../core/analytics.dart';
import '../models/profile.dart';
import '../services/supabase_service.dart';

class FollowersScreen extends StatefulWidget {
  const FollowersScreen({super.key});

  @override
  State<FollowersScreen> createState() => _FollowersScreenState();
}

class _FollowersScreenState extends State<FollowersScreen> {
  List<Profile> _followers = [];
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
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final followers = await SupabaseService.getFollowers(userId);
      if (!mounted) return;
      setState(() {
        _followers = followers;
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

  @override
  Widget build(BuildContext context) {
    Analytics.logScreenView('followers');
    return Scaffold(
      appBar: AppBar(
        title: const Text('Followers'),
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
                    child: CircularProgressIndicator(strokeWidth: 2, color: Theme.of(context).colorScheme.primary),
                  ),
                  const SizedBox(height: AppTheme.spacingLg),
                  Text('Loading followers…', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
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
                        Icon(Icons.people_outline, size: 64, color: Theme.of(context).colorScheme.outline),
                        const SizedBox(height: AppTheme.spacingLg),
                        Text(_error!, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyLarge),
                        const SizedBox(height: AppTheme.spacingLg),
                        FilledButton.icon(onPressed: _load, icon: const Icon(Icons.refresh, size: 20), label: const Text('Retry')),
                      ],
                    ),
                  ),
                )
              : _followers.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(AppTheme.spacingLg),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.people_outline, size: 64, color: Theme.of(context).colorScheme.outline),
                            const SizedBox(height: AppTheme.spacingLg),
                            Text('No followers yet', style: Theme.of(context).textTheme.titleMedium),
                            const SizedBox(height: AppTheme.spacingSm),
                            Text(
                              'Share your trips to get followers',
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(AppTheme.spacingMd),
                        itemCount: _followers.length,
                        itemBuilder: (_, i) {
                          final p = _followers[i];
                          return Card(
                            margin: const EdgeInsets.only(bottom: AppTheme.spacingMd),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundImage: p.photoUrl != null ? NetworkImage(p.photoUrl!) : null,
                                child: p.photoUrl == null ? Icon(Icons.person_outline, color: Theme.of(context).colorScheme.onSurfaceVariant) : null,
                              ),
                              title: Text(p.name ?? 'Unknown', style: Theme.of(context).textTheme.titleSmall),
                              trailing: Icon(Icons.chevron_right, color: Theme.of(context).colorScheme.onSurfaceVariant),
                              onTap: () => context.push('/author/${p.id}'),
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}
