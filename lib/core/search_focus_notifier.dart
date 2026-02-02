import 'package:flutter/foundation.dart';

/// Notifies SearchScreen to focus the search bar when the Search tab is tapped while already on the search page.
class SearchFocusNotifier {
  static final _listeners = <VoidCallback>[];

  static void addListener(VoidCallback cb) => _listeners.add(cb);
  static void removeListener(VoidCallback cb) => _listeners.remove(cb);

  static void notify() {
    for (final cb in List.of(_listeners)) {
      cb();
    }
  }
}
