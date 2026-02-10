import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/analytics.dart';
import '../core/home_cache.dart';
import '../core/profile_cache.dart';
import '../core/saved_cache.dart';
import '../core/theme_mode_notifier.dart';
import '../core/locale_notifier.dart';
import '../l10n/app_strings.dart';

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
          SnackBar(content: Text(AppStrings.t(context, 'could_not_sign_out'))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    Analytics.logScreenView('settings');
    return Scaffold(
      appBar: AppBar(
        title: Text(AppStrings.t(context, 'settings')),
      ),
      body: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
            child: Text(AppStrings.t(context, 'appearance'), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          ),
          ListenableBuilder(
            listenable: ThemeModeNotifier.instance,
            builder: (context, _) {
              final mode = ThemeModeNotifier.instance.themeMode;
              return Column(
                children: [
                  RadioListTile<ThemeMode>(
                    title: Text(AppStrings.t(context, 'light')),
                    secondary: const Icon(Icons.light_mode_outlined),
                    value: ThemeMode.light,
                    groupValue: mode,
                    onChanged: (_) => ThemeModeNotifier.instance.setThemeMode(ThemeMode.light),
                  ),
                  RadioListTile<ThemeMode>(
                    title: Text(AppStrings.t(context, 'dark')),
                    secondary: const Icon(Icons.dark_mode_outlined),
                    value: ThemeMode.dark,
                    groupValue: mode,
                    onChanged: (_) => ThemeModeNotifier.instance.setThemeMode(ThemeMode.dark),
                  ),
                  RadioListTile<ThemeMode>(
                    title: Text(AppStrings.t(context, 'system')),
                    secondary: const Icon(Icons.brightness_auto_outlined),
                    subtitle: Text(AppStrings.t(context, 'match_device')),
                    value: ThemeMode.system,
                    groupValue: mode,
                    onChanged: (_) => ThemeModeNotifier.instance.setThemeMode(ThemeMode.system),
                  ),
                ],
              );
            },
          ),
          const Divider(height: 32),
          ListenableBuilder(
            listenable: LocaleNotifier.instance,
            builder: (context, _) {
              final current = LocaleNotifier.instance.localeCode;
              final currentLabel = supportedLocales[current] ?? current;
              return ExpansionTile(
                initiallyExpanded: false,
                leading: const Icon(Icons.language_outlined),
                title: Text(AppStrings.t(context, 'language'), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                subtitle: Text(currentLabel, style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                children: supportedLocalesOrder.map((code) {
                  final label = supportedLocales[code]!;
                  return RadioListTile<String>(
                    title: Text(label),
                    value: code,
                    groupValue: current,
                    onChanged: (_) => LocaleNotifier.instance.setLocaleCode(code),
                  );
                }).toList(),
              );
            },
          ),
          const Divider(height: 32),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Text(AppStrings.t(context, 'account'), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          ),
          ListTile(
            leading: const Icon(Icons.logout_outlined),
            title: Text(AppStrings.t(context, 'sign_out')),
            onTap: () => _signOut(context),
          ),
        ],
      ),
    );
  }
}
