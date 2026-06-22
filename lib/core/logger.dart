import 'dart:developer' as developer;

/// Severity levels for [Logger].
enum LogLevel { debug, info, warning, error }

/// Minimal leveled logger. Use this instead of `print` (AGENTS.md §12).
///
/// Backed by `dart:developer`'s `log`, so output is structured (tagged by
/// [name]) and handled by the platform's logging instead of stdout.
class Logger {
  const Logger(this.name);

  /// A short tag identifying the source, e.g. `'sync'` or `'scheduler'`.
  final String name;

  void debug(String message) => _log(LogLevel.debug, message);

  void info(String message) => _log(LogLevel.info, message);

  void warning(String message) => _log(LogLevel.warning, message);

  void error(String message, {Object? error, StackTrace? stackTrace}) =>
      _log(LogLevel.error, message, error: error, stackTrace: stackTrace);

  void _log(
    LogLevel level,
    String message, {
    Object? error,
    StackTrace? stackTrace,
  }) {
    developer.log(
      message,
      name: 'kbuzz.$name',
      level: _levelValue(level),
      error: error,
      stackTrace: stackTrace,
    );
  }

  // Maps to dart:developer's conventional level scale.
  int _levelValue(LogLevel level) => switch (level) {
        LogLevel.debug => 500,
        LogLevel.info => 800,
        LogLevel.warning => 900,
        LogLevel.error => 1000,
      };
}
