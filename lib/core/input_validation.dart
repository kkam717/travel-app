// Strict input validation and sanitization (OWASP: injection, oversized payloads, unexpected fields).
// Schema-based: type checks, length limits, allowlisted fields. Reject invalid input before sending to Supabase.

/// Thrown when user input fails validation. UI should show a safe, generic message.
class ValidationException implements Exception {
  final String message;

  ValidationException(this.message);

  @override
  String toString() => 'ValidationException: $message';
}

// --- Length limits (align with DB / UX). OWASP: limit input size to prevent DoS and storage abuse. ---
const int maxTitleLength = 200;
const int maxDestinationLength = 500;
const int maxNameLength = 100;
const int maxSearchQueryLength = 100;
const int maxCityNameLength = 120;
const int maxUrlLength = 2048;
const int maxDescriptionLength = 500;
const int maxItineraryStops = 500;
const int maxStyleTags = 20;
const int maxProfileNameLength = 100;

// --- Sanitization helpers (trim, length cap). No HTML/script injection in Supabase text fields; still cap length. ---

/// Returns trimmed string capped to [maxLen]. Throws [ValidationException] if required and empty after trim.
String sanitizeString(String? value, {int maxLen = 1000, bool required = false}) {
  final s = value?.trim() ?? '';
  if (required && s.isEmpty) throw ValidationException('Required field is empty');
  if (s.length > maxLen) return s.substring(0, maxLen);
  return s;
}

/// Validates URL format and length. Returns null for empty; throws for invalid.
String? sanitizeUrl(String? value) {
  final s = value?.trim();
  if (s == null || s.isEmpty) return null;
  if (s.length > maxUrlLength) throw ValidationException('URL too long');
  final uri = Uri.tryParse(s);
  if (uri == null || (!uri.isScheme('http') && !uri.isScheme('https'))) {
    throw ValidationException('Invalid URL');
  }
  return s;
}

/// Profile update: only allow known fields; validate types and lengths.
Map<String, dynamic> validateProfileUpdate(Map<String, dynamic> data) {
  const allowed = {'name', 'photo_url', 'visited_countries', 'travel_styles', 'travel_mode', 'cities_lived', 'onboarding_complete', 'updated_at', 'id'};
  final out = <String, dynamic>{};
  for (final k in data.keys) {
    if (!allowed.contains(k)) continue;
    final v = data[k];
    if (k == 'name') {
      out[k] = sanitizeString(v is String ? v : v?.toString(), maxLen: maxProfileNameLength);
    } else if (k == 'photo_url') {
      final url = v is String ? sanitizeUrl(v) : null;
      if (url != null) out[k] = url;
    } else if (k == 'visited_countries' || k == 'travel_styles') {
      if (v is List) {
        final list = v.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).take(50).toList();
        out[k] = list;
      }
    } else if (k == 'travel_mode') {
      if (v is String && ['budget', 'standard', 'luxury'].contains(v)) out[k] = v;
    } else if (k == 'cities_lived') {
      if (v is List) out[k] = v;
    } else if (k == 'onboarding_complete') {
      if (v is bool) out[k] = v;
    } else if (k == 'updated_at' || k == 'id') {
      out[k] = v;
    }
  }
  return out;
}

/// Itinerary create/update: validate title, destination, days_count, mode, visibility, etc.
void validateItineraryCreate({
  required String title,
  required String destination,
  required int daysCount,
  required String mode,
  required String visibility,
  required List<Map<String, dynamic>> stopsData,
}) {
  sanitizeString(title, maxLen: maxTitleLength, required: true);
  sanitizeString(destination, maxLen: maxDestinationLength, required: true);
  if (daysCount < 1 || daysCount > 365) throw ValidationException('days_count must be 1–365');
  if (!['budget', 'standard', 'luxury'].contains(mode)) throw ValidationException('Invalid mode');
  if (!['private', 'friends', 'public'].contains(visibility)) throw ValidationException('Invalid visibility');
  if (stopsData.length > maxItineraryStops) throw ValidationException('Too many stops');
}

/// Returns only allowed fields, validated. Drops unexpected fields (OWASP: reject unexpected).
Map<String, dynamic> validateItineraryUpdate(Map<String, dynamic> data) {
  const allowed = {'title', 'destination', 'days_count', 'style_tags', 'mode', 'visibility', 'use_dates', 'start_date', 'end_date', 'duration_year', 'duration_month', 'duration_season', 'transport_transitions', 'cost_per_person', 'updated_at'};
  final out = <String, dynamic>{};
  for (final k in data.keys) {
    if (!allowed.contains(k)) continue;
    final v = data[k];
    if (k == 'title') {
      if (v != null) out[k] = sanitizeString(v is String ? v : v.toString(), maxLen: maxTitleLength, required: true);
    } else if (k == 'destination') {
      if (v != null) out[k] = sanitizeString(v is String ? v : v.toString(), maxLen: maxDestinationLength, required: true);
    } else if (k == 'days_count') {
      if (v != null && v is int && v >= 1 && v <= 365) out[k] = v;
    } else if (k == 'mode') {
      if (v != null && ['budget', 'standard', 'luxury'].contains(v.toString())) out[k] = v.toString();
    } else if (k == 'visibility') {
      if (v != null && ['private', 'friends', 'public'].contains(v.toString())) out[k] = v.toString();
    } else if (k == 'style_tags' && v is List) {
      out[k] = v.map((e) => e.toString().trim().toLowerCase()).where((e) => e.isNotEmpty).take(maxStyleTags).toList();
    } else if (k == 'transport_transitions' && v is List) {
      out[k] = v;
    } else if (k == 'cost_per_person' && v is int && v >= 0) {
      out[k] = v;
    } else if (k == 'use_dates' || k == 'start_date' || k == 'end_date' || k == 'duration_year' || k == 'duration_month' || k == 'duration_season' || k == 'updated_at') {
      out[k] = v;
    }
  }
  return out;
}

/// Single stop: allowed fields and types; name/category/url length.
Map<String, dynamic> validateItineraryStop(Map<String, dynamic> stop) {
  const allowed = {'itinerary_id', 'position', 'day', 'name', 'category', 'stop_type', 'external_url', 'lat', 'lng', 'place_id', 'google_place_id', 'rating'};
  final out = <String, dynamic>{};
  for (final k in stop.keys) {
    if (!allowed.contains(k)) continue;
    final v = stop[k];
    if (k == 'name') {
      out[k] = sanitizeString(v is String ? v : v?.toString(), maxLen: 300, required: true);
    } else if (k == 'category' || k == 'stop_type') {
      if (v is String && v.trim().isNotEmpty) out[k] = v.trim().toLowerCase();
    } else if (k == 'external_url') {
      final url = v is String ? sanitizeUrl(v) : null;
      if (url != null) out[k] = url;
    } else if (k == 'position' || k == 'day') {
      if (v is int) out[k] = v;
      if (v is num) out[k] = v.toInt();
    } else if (k == 'lat' || k == 'lng') {
      if (v is num && v >= -180 && v <= 180) out[k] = v.toDouble();
    } else if (k == 'rating') {
      if (v is int && v >= 1 && v <= 5) out[k] = v;
      if (v is num) {
        final r = v.toInt();
        if (r >= 1 && r <= 5) out[k] = r;
      }
    } else if (k == 'place_id' || k == 'google_place_id') {
      if (v is String && v.trim().isNotEmpty) out[k] = v.trim();
    } else if (k == 'itinerary_id') {
      out[k] = v;
    }
  }
  return out;
}

/// Search query: cap length and trim.
String validateSearchQuery(String? query) {
  return sanitizeString(query, maxLen: maxSearchQueryLength);
}

/// City name for past cities / top spots.
String validateCityName(String? name) {
  return sanitizeString(name, maxLen: maxCityNameLength, required: true);
}

/// Auth: email format and password length (Supabase minimum 6).
void validateEmail(String? email) {
  final s = sanitizeString(email, maxLen: 256, required: true);
  if (!RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(s)) throw ValidationException('Invalid email format');
}

void validatePassword(String? password, {bool isSignUp = false}) {
  final s = password ?? '';
  if (s.length < 6) throw ValidationException('Password must be at least 6 characters');
  if (s.length > 512) throw ValidationException('Password too long');
}
