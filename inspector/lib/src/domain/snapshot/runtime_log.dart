import 'package:orchestra/inspector_export.dart';

final class RuntimeLog {
  final String id;
  final LogLevelDto level;
  final int tsMicros;
  final String message;
  final String? orchestrationId;
  final String? systemId;
  final List<String> elementRefs;
  final String? stack;

  const RuntimeLog({
    required this.id,
    required this.level,
    required this.tsMicros,
    required this.message,
    this.orchestrationId,
    this.systemId,
    this.elementRefs = const [],
    this.stack,
  });

  factory RuntimeLog.fromDto(LogDto dto) {
    return RuntimeLog(
      id: dto.id,
      level: dto.level,
      tsMicros: dto.tsMicros,
      message: dto.message,
      orchestrationId: dto.orchestrationId,
      systemId: dto.systemId,
      elementRefs: dto.entityRefs,
      stack: dto.stack,
    );
  }
}
