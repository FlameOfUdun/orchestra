import 'package:orchestra/inspector_export.dart';

final class OrchestratorNode {
  final String id;
  final String name;
  final bool isActive;
  final List<String> orchestrationIds;

  const OrchestratorNode({
    required this.id,
    required this.name,
    required this.isActive,
    this.orchestrationIds = const [],
  });

  OrchestratorNode copyWith({
    String? name,
    bool? isActive,
    List<String>? orchestrationIds,
  }) {
    return OrchestratorNode(
      id: id,
      name: name ?? this.name,
      isActive: isActive ?? this.isActive,
      orchestrationIds: orchestrationIds ?? this.orchestrationIds,
    );
  }
}

final class OrchestrationNode {
  final String id;
  final String name;
  final String orchestratorId;
  final List<String> entityIds;
  final List<String> systemIds;

  const OrchestrationNode({
    required this.id,
    required this.name,
    required this.orchestratorId,
    this.entityIds = const [],
    this.systemIds = const [],
  });

  OrchestrationNode copyWith({
    String? name,
    String? orchestratorId,
    List<String>? entityIds,
    List<String>? systemIds,
  }) {
    return OrchestrationNode(
      id: id,
      name: name ?? this.name,
      orchestratorId: orchestratorId ?? this.orchestratorId,
      entityIds: entityIds ?? this.entityIds,
      systemIds: systemIds ?? this.systemIds,
    );
  }
}

final class EntityNode {
  final String id;
  final String name;
  final EntityKindDto kind;
  final String typeName;
  final String orchestrationId;
  final JsonValueDto? value;
  final JsonValueDto? previous;
  final int? updatedAtMicros;
  final int updateCount;

  const EntityNode({
    required this.id,
    required this.name,
    required this.kind,
    required this.typeName,
    required this.orchestrationId,
    this.value,
    this.previous,
    this.updatedAtMicros,
    this.updateCount = 0,
  });

  EntityNode copyWith({
    String? name,
    EntityKindDto? kind,
    String? typeName,
    String? orchestrationId,
    JsonValueDto? value,
    JsonValueDto? previous,
    int? updatedAtMicros,
    int? updateCount,
  }) {
    return EntityNode(
      id: id,
      name: name ?? this.name,
      kind: kind ?? this.kind,
      typeName: typeName ?? this.typeName,
      orchestrationId: orchestrationId ?? this.orchestrationId,
      value: value ?? this.value,
      previous: previous ?? this.previous,
      updatedAtMicros: updatedAtMicros ?? this.updatedAtMicros,
      updateCount: updateCount ?? this.updateCount,
    );
  }

  factory EntityNode.fromDto(EntityDto dto) {
    return EntityNode(
      id: dto.id,
      name: dto.name,
      kind: dto.kind,
      typeName: dto.typeName,
      orchestrationId: dto.orchestrationId,
      value: dto.value,
      previous: dto.previous,
      updatedAtMicros: dto.updatedAtMicros,
    );
  }
}

final class SystemNode {
  final String id;
  final String name;
  final SystemKindDto kind;
  final String orchestrationId;
  final List<String> reactsToEntityIds;
  final List<String> interactsWithEntityIds;
  final int firingCount;
  final int? lastFiredAtMicros;
  final int? lastDurationMicros;
  final int errorCount;

  const SystemNode({
    required this.id,
    required this.name,
    required this.kind,
    required this.orchestrationId,
    this.reactsToEntityIds = const [],
    this.interactsWithEntityIds = const [],
    this.firingCount = 0,
    this.lastFiredAtMicros,
    this.lastDurationMicros,
    this.errorCount = 0,
  });

  SystemNode copyWith({
    String? name,
    SystemKindDto? kind,
    String? orchestrationId,
    List<String>? reactsToEntityIds,
    List<String>? interactsWithEntityIds,
    int? firingCount,
    int? lastFiredAtMicros,
    int? lastDurationMicros,
    int? errorCount,
  }) {
    return SystemNode(
      id: id,
      name: name ?? this.name,
      kind: kind ?? this.kind,
      orchestrationId: orchestrationId ?? this.orchestrationId,
      reactsToEntityIds: reactsToEntityIds ?? this.reactsToEntityIds,
      interactsWithEntityIds: interactsWithEntityIds ?? this.interactsWithEntityIds,
      firingCount: firingCount ?? this.firingCount,
      lastFiredAtMicros: lastFiredAtMicros ?? this.lastFiredAtMicros,
      lastDurationMicros: lastDurationMicros ?? this.lastDurationMicros,
      errorCount: errorCount ?? this.errorCount,
    );
  }

  factory SystemNode.fromDto(SystemDto dto) {
    return SystemNode(
      id: dto.id,
      name: dto.name,
      kind: dto.kind,
      orchestrationId: dto.orchestrationId,
      reactsToEntityIds: dto.reactsToEntityIds,
      interactsWithEntityIds: dto.interactsWithEntityIds,
    );
  }
}
