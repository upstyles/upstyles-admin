import 'package:flutter/foundation.dart';

/// Lightweight logging wrapper that keeps `avoid_print` happy while still
/// surfacing messages in Flutter debug output.
class AppLogger {
  const AppLogger._();

  static void debug(Object? message, {String tag = 'App'}) {
    if (!kDebugMode) return;
    debugPrint('[$tag] ${message ?? ''}');
  }

  static void info(Object? message, {String tag = 'App'}) {
    debugPrint('[$tag][INFO] ${message ?? ''}');
  }

  static void warn(Object? message, {String tag = 'App'}) {
    debugPrint('[$tag][WARN] ${message ?? ''}');
  }

  static void error(Object? message, {String tag = 'App', Object? error, StackTrace? stackTrace}) {
    final buffer = StringBuffer('[$tag][ERROR]');
    if (message != null) buffer.write(' $message');
    if (error != null) buffer.write(' — $error');
    if (stackTrace != null) buffer.write('\n$stackTrace');
    debugPrint(buffer.toString());
  }
}
