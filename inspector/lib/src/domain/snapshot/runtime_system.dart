import 'package:orchestra/inspector_export.dart';

final class RuntimeSystem {
  final String id;
  final String name;
  final SystemKindDto kind;
  final String orchestrationId;
  final List<String> reactsToElementIds;
  final List<String> interactsWithElementIds;
  final int firingCount;
  final int? lastFiredAtMicros;
  final int? lastDurationMicros;
  final int errorCount;

  const RuntimeSystem({
    required this.id,
    required this.name,
    required this.kind,
    required this.orchestrationId,
    this.reactsToElementIds = const [],
    this.interactsWithElementIds = const [],
    this.firingCount = 0,
    this.lastFiredAtMicros,
    this.lastDurationMicros,
    this.errorCount = 0,
  });

  RuntimeSystem copyWith({
    String? name,
    SystemKindDto? kind,
    String? orchestrationId,
    List<String>? reactsToElementIds,
    List<String>? interactsWithElementIds,
    int? firingCount,
    int? lastFiredAtMicros,
    int? lastDurationMicros,
    int? errorCount,
  }) {
    return RuntimeSystem(
      id: id,
      name: name ?? this.name,
      kind: kind ?? this.kind,
      orchestrationId: orchestrationId ?? this.orchestrationId,
      reactsToElementIds: reactsToElementIds ?? this.reactsToElementIds,
      interactsWithElementIds: interactsWithElementIds ?? this.interactsWithElementIds,
      firingCount: firingCount ?? this.firingCount,
      lastFiredAtMicros: lastFiredAtMicros ?? this.lastFiredAtMicros,
      lastDurationMicros: lastDurationMicros ?? this.lastDurationMicros,
      errorCount: errorCount ?? this.errorCount,
    );
  }

  factory RuntimeSystem.fromDto(SystemDto dto) {
    return RuntimeSystem(
      id: dto.id,
      name: dto.name,
      kind: dto.kind,
      orchestrationId: dto.orchestrationId,
      reactsToElementIds: dto.reactsToEntityIds,
      interactsWithElementIds: dto.interactsWithEntityIds,
    );
  }
}
