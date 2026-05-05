import '../inspector/inspector_bridge.dart';

mixin Logger {
  final List<LogEntry> _logs = [];

  /// Maximum number of log entries to keep.
  ///
  /// This can be adjusted based on the application's needs.
  ///
  /// Default is set to 100 entries.
  ///
  /// if the number of entries exceeds this limit, the oldest entries will be
  /// removed.
  static const maxEntries = 100;

  /// Unmodifiable list of log entries.
  List<LogEntry> get logs => List.unmodifiable(_logs);

  /// Logs a custom log entry.
  void log(
    String message, {
    LogLevel level = LogLevel.info,
    String? orchestrationId,
    String? systemId,
    String? orchestrationName,
    String? systemName,
    List<String> entityRefs = const [],
  }) {
    final stack = StackTrace.current;
    if (_logs.length >= maxEntries) {
      _logs.removeAt(0);
    }
    _logs.add(LogEntry(
      time: DateTime.now(),
      level: level,
      message: message,
      stack: stack,
      orchestrationName: orchestrationName,
      systemName: systemName,
    ));
    InspectorBridge.instance.logEmitted(
      level: level,
      message: message,
      orchestrationId: orchestrationId,
      systemId: systemId,
      entityRefs: entityRefs,
      stack: stack.toString(),
    );
  }

  /// Clears all log entries.
  void clear() {
    _logs.clear();
  }
}

/// Base class for Orchestra log entries.
final class LogEntry {
  /// The time when the log entry was created.
  final DateTime time;

  /// The log level of the entry.
  final LogLevel level;

  /// The stack trace at the time of logging.
  final StackTrace stack;

  /// The log message.
  final String message;

  /// The name of the orchestration that generated the log entry.
  final String? orchestrationName;

  /// The name of the system that generated the log entry.
  final String? systemName;

  const LogEntry({
    required this.time,
    required this.level,
    required this.stack,
    required this.message,
    this.orchestrationName,
    this.systemName,
  });
}

/// Represents the log levels for Orchestra logging.
enum LogLevel {
  /// Informational log level.
  info,

  /// Warning log level.
  warning,

  /// Error log level.
  error,

  /// Debug log level.
  debug,

  /// Verbose log level.
  verbose,

  /// Fatal log level.
  fatal,
}
