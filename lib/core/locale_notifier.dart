import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String _localeKey = 'app_locale';

/// Supported app languages. [localeCode] is used for persistence and translation target.
const Map<String, String> supportedLocales = {
  'en': 'English',
  'es': 'Español',
  'fr': 'Français',
  'de': 'Deutsch',
  'it': 'Italiano',
  'zh': '中文',
  'ja': '日本語',
  'pt': 'Português',
  'el': 'Ελληνικά',
  'tr': 'Türkçe',
  'ar': 'العربية',
  'fa': 'فارسی',
};

/// Order for displaying languages in the selector: English first, then alphabetical by English name.
const List<String> supportedLocalesOrder = [
  'en',  // English first (default / international)
  'ar',  // Arabic
  'zh',  // Chinese
  'fa',  // Farsi
  'fr',  // French
  'de',  // German
  'el',  // Greek
  'it',  // Italian
  'ja',  // Japanese
  'pt',  // Portuguese
  'es',  // Spanish
  'tr',  // Turkish
];

const String defaultLocaleCode = 'en';

/// Persists and notifies app locale (language) changes.
class LocaleNotifier extends ChangeNotifier {
  static final LocaleNotifier instance = LocaleNotifier._();
  factory LocaleNotifier() => instance;

  LocaleNotifier._() {
    _load();
  }

  String _localeCode = defaultLocaleCode;

  String get localeCode => _localeCode;

  Locale get locale => Locale(_localeCode);

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_localeKey);
    if (stored != null && supportedLocales.containsKey(stored)) {
      _localeCode = stored;
    } else {
      // No saved choice: use system language if supported, otherwise default
      final systemLang = WidgetsBinding.instance.platformDispatcher.locale.languageCode;
      _localeCode = supportedLocales.containsKey(systemLang) ? systemLang : defaultLocaleCode;
    }
    notifyListeners();
  }

  Future<void> setLocaleCode(String code) async {
    if (!supportedLocales.containsKey(code) || _localeCode == code) return;
    _localeCode = code;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_localeKey, code);
    notifyListeners();
  }
}
