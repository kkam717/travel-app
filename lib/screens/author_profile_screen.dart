import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/theme.dart';
import '../models/itinerary.dart';
import '../services/supabase_service.dart';

class AuthorProfileScreen extends StatefulWidget {
  final String authorId;

  const AuthorProfileScreen({super.key, required this.authorId});

  @override
  State<AuthorProfileScreen> createState() => _AuthorProfileScreenState();
}

class _AuthorProfileScreenState extends State<AuthorProfileScreen> {
  List<Itinerary> _itineraries = [];
  bool _isLoading = true;
  String? _error;
  bool _isFollowing = false;

  bool get _isOwnProfile => Supabase.instance.client.auth.currentUser?.id == widget.authorId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      final results = await Future.wait([
        SupabaseService.getUserItineraries(widget.authorId, publicOnly: true),
        userId != null && !_isOwnProfile ? SupabaseService.isFollowing(userId, widget.authorId) : Future.value(false),
      ]);
      setState(() {
        _itineraries = results[0] as List<Itinerary>;
        _isFollowing = results[1] as bool;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleFollow() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null || _isOwnProfile) return;
    setState(() => _isFollowing = !_isFollowing);
    try {
      if (_isFollowing) {
        await SupabaseService.followUser(userId, widget.authorId);
      } else {
        await SupabaseService.unfollowUser(userId, widget.authorId);
      }
    } catch (e) {
      setState(() => _isFollowing = !_isFollowing);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Author'),
        actions: [
          if (!_isOwnProfile && !_isLoading)
            TextButton.icon(
              onPressed: _toggleFollow,
              icon: Icon(_isFollowing ? Icons.person : Icons.person_add, size: 18),
              label: Text(_isFollowing ? 'Following' : 'Follow'),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [Text(_error!), const SizedBox(height: 16), FilledButton(onPressed: _load, child: const Text('Retry'))]))
              : _itineraries.isEmpty
                  ? Center(child: Text('No public itineraries', style: TextStyle(color: Colors.grey[600])))
                  : ListView.builder(
                      padding: const EdgeInsets.all(AppTheme.spacingMd),
                      itemCount: _itineraries.length,
                      itemBuilder: (_, i) {
                        final it = _itineraries[i];
                        return Card(
                          margin: const EdgeInsets.only(bottom: AppTheme.spacingMd),
                          child: ListTile(
                            title: Text(it.title),
                            subtitle: Text('${it.destination} • ${it.daysCount} days'),
                            onTap: () => context.push('/itinerary/${it.id}'),
                          ),
                        );
                      },
                    ),
    );
  }
}
