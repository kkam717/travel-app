import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/analytics.dart';
import '../core/home_cache.dart';
import '../core/profile_cache.dart';
import '../core/saved_cache.dart';
import '../core/theme_mode_notifier.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Future<void> _signOut(BuildContext context) async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      await Supabase.instance.client.auth.signOut();
      if (userId != null) {
        HomeCache.clear(userId);
        SavedCache.clear(userId);
        ProfileCache.clear(userId);
      }
      if (context.mounted) context.go('/');
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not sign out. Please try again.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    Analytics.logScreenView('settings');
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 24, 16, 8),
            child: Text('Appearance', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          ),
          ListenableBuilder(
            listenable: ThemeModeNotifier.instance,
            builder: (context, _) {
              final mode = ThemeModeNotifier.instance.themeMode;
              return Column(
                children: [
                  RadioListTile<ThemeMode>(
                    title: const Text('Light'),
                    secondary: const Icon(Icons.light_mode_outlined),
                    value: ThemeMode.light,
                    groupValue: mode,
                    onChanged: (_) => ThemeModeNotifier.instance.setThemeMode(ThemeMode.light),
                  ),
                  RadioListTile<ThemeMode>(
                    title: const Text('Dark'),
                    secondary: const Icon(Icons.dark_mode_outlined),
                    value: ThemeMode.dark,
                    groupValue: mode,
                    onChanged: (_) => ThemeModeNotifier.instance.setThemeMode(ThemeMode.dark),
                  ),
                  RadioListTile<ThemeMode>(
                    title: const Text('System'),
                    secondary: const Icon(Icons.brightness_auto_outlined),
                    subtitle: const Text('Match device settings'),
                    value: ThemeMode.system,
                    groupValue: mode,
                    onChanged: (_) => ThemeModeNotifier.instance.setThemeMode(ThemeMode.system),
                  ),
                ],
              );
            },
          ),
          const Divider(height: 32),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Text('Account', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          ),
          ListTile(
            leading: const Icon(Icons.logout_outlined),
            title: const Text('Sign out'),
            onTap: () => _signOut(context),
          ),
        ],
      ),
    );
  }
}
