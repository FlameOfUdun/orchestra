import 'package:orchestra/inspector_export.dart';

final class LogEntry {
  final String id;
  final LogLevelDto level;
  final int tsMicros;
  final String message;
  final String? orchestrationId;
  final String? systemId;
  final List<String> entityRefs;
  final String? stack;

  const LogEntry({
    required this.id,
    required this.level,
    required this.tsMicros,
    required this.message,
    this.orchestrationId,
    this.systemId,
    this.entityRefs = const [],
    this.stack,
  });

  factory LogEntry.fromDto(LogDto dto) {
    return LogEntry(
      id: dto.id,
      level: dto.level,
      tsMicros: dto.tsMicros,
      message: dto.message,
      orchestrationId: dto.orchestrationId,
      systemId: dto.systemId,
      entityRefs: dto.entityRefs,
      stack: dto.stack,
    );
  }
}
