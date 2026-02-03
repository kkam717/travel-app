import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import '../core/locale_notifier.dart';

const _libreTranslateUrl = 'https://libretranslate.com';
const _myMemoryUrl = 'https://api.mymemory.translated.net/get';

/// Normalize lang code for MyMemory (e.g. zh-cn -> zh-CN).
String _normalizeLangCode(String code) {
  if (code.contains('-')) {
    final parts = code.split('-');
    return '${parts[0]}-${parts[1].toUpperCase()}';
  }
  return code.toLowerCase();
}

/// Normalize to primary language code for comparison (e.g. en-US -> en).
String _primaryLangCode(String code) {
  if (code.isEmpty) return code;
  final base = code.contains('-') ? code.split('-').first : code;
  return base.toLowerCase();
}

/// Detects the language of [text] via LibreTranslate /detect. Returns null if detection fails.
Future<String?> detectLanguage(String text) async {
  if (text.length < 3) return null;
  try {
    final key = dotenv.env['LIBRETRANSLATE_API_KEY']?.trim();
    final body = <String, dynamic>{'q': text};
    if (key != null && key.isNotEmpty) body['api_key'] = key;

    final res = await http
        .post(
          Uri.parse('$_libreTranslateUrl/detect'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 5));
    if (res.statusCode != 200) return null;
    final list = jsonDecode(res.body);
    if (list is! List || list.isEmpty) return null;
    final first = list[0] as Map<String, dynamic>?;
    return first?['language'] as String?;
  } catch (e) {
    if (kDebugMode) debugPrint('Language detection error: $e');
    return null;
  }
}

/// Returns true if [text] is detected to be in a different language than [appLanguageCode].
/// Uses primary codes for comparison (e.g. en-US and en-GB both count as 'en').
/// When detection fails, uses a lightweight fallback for common English markers so the
/// translate button still appears (e.g. "(7 days)" on an Italian app).
Future<bool> isContentInDifferentLanguage(String text, String appLanguageCode) async {
  final trimmed = text.trim();
  if (trimmed.length < 3) return false;
  final appPrimary = _primaryLangCode(appLanguageCode);
  final detected = await detectLanguage(trimmed);
  if (detected != null) {
    return _primaryLangCode(detected) != appPrimary;
  }
  // Fallback when API fails: if app is not English and text looks like English, show translate
  if (appPrimary == 'en') return false;
  return _looksLikeEnglish(trimmed);
}

/// Lightweight heuristic for English-like content when detection API is unavailable.
bool _looksLikeEnglish(String text) {
  final lower = text.toLowerCase();
  const enMarkers = [
    ' days)', ' day)', ' (7 days)', ' (1 day)', 'usa', 'budget', 'culture', 'food',
    'hotel', 'market', 'terminal', 'street', 'avenue', 'road', 'new york', 'philadelphia', 'washington',
  ];
  return enMarkers.any((m) => lower.contains(m));
}

/// Translates [text] to [targetLanguageCode] (e.g. 'en', 'es').
/// Detects source language when not provided. Tries LibreTranslate first (optional API key), then MyMemory.
Future<String?> translate({
  required String text,
  required String targetLanguageCode,
  String? sourceLanguageCode,
  String? apiKey,
}) async {
  final t = text.trim();
  if (t.isEmpty) return null;

  // Detect source language if not provided
  String? source = sourceLanguageCode;
  if (source == null || source == 'auto') {
    source = await detectLanguage(t) ?? 'en';
  }
  // If already in target language, return as-is (skip API call)
  final targetNorm = _normalizeLangCode(targetLanguageCode);
  final sourceNorm = _normalizeLangCode(source);
  if (sourceNorm == targetNorm) return t;

  // Try LibreTranslate first when API key is set
  final key = apiKey ?? dotenv.env['LIBRETRANSLATE_API_KEY']?.trim();
  if (key != null && key.isNotEmpty) {
    final result = await _translateLibreTranslate(
      text: t,
      target: targetLanguageCode,
      source: source,
      apiKey: key,
    );
    if (result != null) return result;
  }

  // Fallback: MyMemory (free, no key) with detected source
  return _translateMyMemory(
    text: t,
    target: targetLanguageCode,
    source: source,
  );
}

Future<String?> _translateLibreTranslate({
  required String text,
  required String target,
  required String source,
  required String apiKey,
}) async {
  try {
    final body = <String, dynamic>{
      'q': text,
      'source': source,
      'target': target,
      'format': 'text',
      'api_key': apiKey,
    };
    final res = await http
        .post(
          Uri.parse('$_libreTranslateUrl/translate'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 10));
    if (res.statusCode != 200) return null;
    final data = jsonDecode(res.body) as Map<String, dynamic>?;
    return data?['translatedText'] as String?;
  } catch (e) {
    if (kDebugMode) debugPrint('LibreTranslate error: $e');
    return null;
  }
}

Future<String?> _translateMyMemory({
  required String text,
  required String target,
  required String source,
}) async {
  try {
    // MyMemory has a ~500-word limit; truncate very long text
    final toTranslate = text.length > 3000 ? '${text.substring(0, 3000)}...' : text;
    final langpair = '${_normalizeLangCode(source)}|${_normalizeLangCode(target)}';
    final uri = Uri.parse(_myMemoryUrl).replace(
      queryParameters: {
        'q': toTranslate,
        'langpair': langpair,
      },
    );
    final res = await http.get(uri).timeout(const Duration(seconds: 10));
    if (res.statusCode != 200) return null;
    final data = jsonDecode(res.body) as Map<String, dynamic>?;
    final responseData = data?['responseData'] as Map<String, dynamic>?;
    return responseData?['translatedText'] as String?;
  } catch (e) {
    if (kDebugMode) debugPrint('MyMemory error: $e');
    return null;
  }
}

