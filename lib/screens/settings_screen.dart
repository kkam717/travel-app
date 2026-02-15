import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/analytics.dart';
import '../core/home_cache.dart';
import '../core/profile_cache.dart';
import '../core/saved_cache.dart';
import '../core/theme.dart';
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
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final cardColor = theme.brightness == Brightness.light
        ? Colors.white
        : cs.surfaceContainerHighest;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          AppStrings.t(context, 'settings'),
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
            AppTheme.spacingLg, AppTheme.spacingMd, AppTheme.spacingLg, AppTheme.spacingXl),
        children: [
          // ── Appearance Section ─────────────────────────────────────────
          _SectionLabel(label: AppStrings.t(context, 'appearance')),
          const SizedBox(height: AppTheme.spacingSm),
          Container(
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: cs.shadow.withValues(alpha: 0.06),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: ListenableBuilder(
              listenable: ThemeModeNotifier.instance,
              builder: (context, _) {
                final mode = ThemeModeNotifier.instance.themeMode;
                return Column(
                  children: [
                    _SettingsRadioTile<ThemeMode>(
                      icon: Icons.light_mode_outlined,
                      title: AppStrings.t(context, 'light'),
                      value: ThemeMode.light,
                      groupValue: mode,
                      onChanged: (_) => ThemeModeNotifier.instance.setThemeMode(ThemeMode.light),
                      isFirst: true,
                    ),
                    _ThinDivider(),
                    _SettingsRadioTile<ThemeMode>(
                      icon: Icons.dark_mode_outlined,
                      title: AppStrings.t(context, 'dark'),
                      value: ThemeMode.dark,
                      groupValue: mode,
                      onChanged: (_) => ThemeModeNotifier.instance.setThemeMode(ThemeMode.dark),
                    ),
                    _ThinDivider(),
                    _SettingsRadioTile<ThemeMode>(
                      icon: Icons.brightness_auto_outlined,
                      title: AppStrings.t(context, 'system'),
                      subtitle: AppStrings.t(context, 'match_device'),
                      value: ThemeMode.system,
                      groupValue: mode,
                      onChanged: (_) => ThemeModeNotifier.instance.setThemeMode(ThemeMode.system),
                      isLast: true,
                    ),
                  ],
                );
              },
            ),
          ),

          const SizedBox(height: AppTheme.spacingXl),

          // ── Language Section ───────────────────────────────────────────
          _SectionLabel(label: AppStrings.t(context, 'language')),
          const SizedBox(height: AppTheme.spacingSm),
          Container(
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: cs.shadow.withValues(alpha: 0.06),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: ListenableBuilder(
              listenable: LocaleNotifier.instance,
              builder: (context, _) {
                final current = LocaleNotifier.instance.localeCode;
                return Column(
                  children: [
                    for (int i = 0; i < supportedLocalesOrder.length; i++) ...[
                      if (i > 0) _ThinDivider(),
                      Builder(
                        builder: (context) {
                          final code = supportedLocalesOrder[i];
                          final label = supportedLocales[code]!;
                          return _SettingsRadioTile<String>(
                            icon: Icons.language_outlined,
                            title: label,
                            value: code,
                            groupValue: current,
                            onChanged: (_) => LocaleNotifier.instance.setLocaleCode(code),
                            isFirst: i == 0,
                            isLast: i == supportedLocalesOrder.length - 1,
                          );
                        },
                      ),
                    ],
                  ],
                );
              },
            ),
          ),

          const SizedBox(height: AppTheme.spacingXl),

          // ── Account Section ───────────────────────────────────────────
          _SectionLabel(label: AppStrings.t(context, 'account')),
          const SizedBox(height: AppTheme.spacingSm),
          Container(
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: cs.shadow.withValues(alpha: 0.06),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => _signOut(context),
              borderRadius: BorderRadius.circular(20),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: cs.error.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.logout_rounded, size: 20, color: cs.error),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        AppStrings.t(context, 'sign_out'),
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: cs.error,
                        ),
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded, size: 20, color: cs.onSurfaceVariant),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Section label
// ─────────────────────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 4),
      child: Text(
        label.toUpperCase(),
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Thin divider within cards
// ─────────────────────────────────────────────────────────────────────────────

class _ThinDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Divider(
        height: 1,
        thickness: 0.5,
        color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.5),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Settings radio tile (icon + title + radio)
// ─────────────────────────────────────────────────────────────────────────────

class _SettingsRadioTile<T> extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final T value;
  final T groupValue;
  final ValueChanged<T?> onChanged;
  final bool isFirst;
  final bool isLast;

  const _SettingsRadioTile({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.value,
    required this.groupValue,
    required this.onChanged,
    this.isFirst = false,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isSelected = value == groupValue;

    return InkWell(
      onTap: () => onChanged(value),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: isSelected
                    ? cs.primary.withValues(alpha: 0.12)
                    : cs.surfaceContainerHighest.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                size: 20,
                color: isSelected ? cs.primary : cs.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: cs.onSurface,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? cs.primary : cs.outline,
                  width: isSelected ? 6 : 2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
