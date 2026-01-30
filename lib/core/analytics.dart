/// Analytics hooks - no-op for MVP, ready for Phase 2 integration.
class Analytics {
  static void logEvent(String name, [Map<String, dynamic>? params]) {
    // No-op: Add Firebase/Mixpanel/etc. later
  }

  static void logScreenView(String screenName) {
    // No-op
  }

  static void setUserId(String? userId) {
    // No-op
  }
}
