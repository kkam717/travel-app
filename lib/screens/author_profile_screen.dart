import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
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

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final itineraries = await SupabaseService.getUserItineraries(widget.authorId, publicOnly: true);
      setState(() {
        _itineraries = itineraries;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Author')),
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
