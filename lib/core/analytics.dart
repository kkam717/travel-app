/// Analytics hooks - no-op for MVP, ready for Phase 2 integration.
/// Logging hygiene: redact PII and secrets from any params before sending to analytics/crash.
class Analytics {
  /// Redact tokens, emails, and token-like strings from log/analytics payloads.
  static String redactForLog(String? value) {
    if (value == null || value.isEmpty) return '';
    String s = value;
    // Mask email-like substrings (e.g. user@domain.com)
    s = s.replaceAllMapped(
      RegExp(r'[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}'),
      (_) => '[email redacted]',
    );
    // Mask bearer / token-like segments (e.g. Bearer eyJ..., supabase key prefixes)
    s = s.replaceAllMapped(
      RegExp(r'(Bearer\s+[^\s]+|eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]*|sb[a-z_]*_[a-zA-Z0-9]{20,})', caseSensitive: false),
      (_) => '[redacted]',
    );
    return s;
  }

  static void logEvent(String name, [Map<String, dynamic>? params]) {
    // No-op: Add Firebase/Mixpanel/etc. later. Callers should use redactForLog for error/PII params.
  }

  static void logScreenView(String screenName) {
    // No-op
  }

  static void setUserId(String? userId) {
    // No-op
  }
}
