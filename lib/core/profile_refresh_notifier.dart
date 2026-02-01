import 'package:flutter/foundation.dart';

/// Notifies ProfileScreen to refresh when returning from subpages or switching to Profile tab.
class ProfileRefreshNotifier {
  static final _listeners = <VoidCallback>[];

  static void addListener(VoidCallback cb) => _listeners.add(cb);
  static void removeListener(VoidCallback cb) => _listeners.remove(cb);

  static void notify() {
    for (final cb in List.of(_listeners)) {
      cb();
    }
  }
}
