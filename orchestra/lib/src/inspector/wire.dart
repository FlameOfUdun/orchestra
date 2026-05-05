import '../utilities/logger.dart';

const int kInspectorProtocolVersion = 1;

const String kInspectorEventStream = 'orchestra';

const String kSubscribeExtension = 'ext.orchestra.inspector.subscribe';
const String kUnsubscribeExtension = 'ext.orchestra.inspector.unsubscribe';
const String kResyncExtension = 'ext.orchestra.inspector.resync';

enum EntityKindDto { component, event, dataEvent, dependency }

enum SystemKindDto { reactive, execute, cleanup, teardown, initialize }

enum LogLevelDto { verbose, debug, info, warning, error, fatal }

LogLevelDto logLevelDtoFromRuntime(LogLevel level) {
  return switch (level) {
    LogLevel.verbose => LogLevelDto.verbose,
    LogLevel.debug => LogLevelDto.debug,
    LogLevel.info => LogLevelDto.info,
    LogLevel.warning => LogLevelDto.warning,
    LogLevel.error => LogLevelDto.error,
    LogLevel.fatal => LogLevelDto.fatal,
  };
}

LogLevelDto logLevelDtoFromName(String name) {
  for (final value in LogLevelDto.values) {
    if (value.name == name) return value;
  }
  return LogLevelDto.info;
}

EntityKindDto entityKindDtoFromName(String name) {
  for (final value in EntityKindDto.values) {
    if (value.name == name) return value;
  }
  throw FormatException('Unknown entity kind: $name');
}

SystemKindDto systemKindDtoFromName(String name) {
  for (final value in SystemKindDto.values) {
    if (value.name == name) return value;
  }
  throw FormatException('Unknown system kind: $name');
}

/// Structured value carried over the wire.
///
/// The runtime tries to JSON-serialize values directly. When that fails or the
/// value is too large, it ships an opaque marker with a string representation
/// and a `truncated` flag.
sealed class JsonValueDto {
  const JsonValueDto();

  Object? toJson();

  factory JsonValueDto.fromJson(Object? raw) {
    if (raw is Map<String, dynamic> && raw['\$kind'] == 'opaque') {
      return OpaqueValueDto(
        typeName: raw['typeName'] as String? ?? 'Object',
        repr: raw['repr'] as String? ?? '',
        truncated: raw['truncated'] as bool? ?? false,
      );
    }
    return DirectValueDto(raw);
  }

  /// Best-effort conversion of an arbitrary Dart value to a [JsonValueDto].
  ///
  /// Scalars, lists, and string-keyed maps are shipped directly. Anything else
  /// becomes an [OpaqueValueDto] using `toString()`.
  factory JsonValueDto.encode(Object? value, {int maxLength = 4096}) {
    if (value == null || value is bool || value is num || value is String) {
      if (value is String && value.length > maxLength) {
        return OpaqueValueDto(
          typeName: 'String',
          repr: value.substring(0, maxLength),
          truncated: true,
        );
      }
      return DirectValueDto(value);
    }
    if (value is List) {
      try {
        final encoded = value.map((e) => JsonValueDto.encode(e, maxLength: maxLength).toJson()).toList();
        return DirectValueDto(encoded);
      } catch (_) {
        return _opaqueOf(value, maxLength);
      }
    }
    if (value is Map) {
      try {
        final encoded = <String, Object?>{};
        for (final entry in value.entries) {
          encoded[entry.key.toString()] = JsonValueDto.encode(entry.value, maxLength: maxLength).toJson();
        }
        return DirectValueDto(encoded);
      } catch (_) {
        return _opaqueOf(value, maxLength);
      }
    }
    return _opaqueOf(value, maxLength);
  }

  static JsonValueDto _opaqueOf(Object value, int maxLength) {
    final repr = value.toString();
    final truncated = repr.length > maxLength;
    return OpaqueValueDto(
      typeName: value.runtimeType.toString(),
      repr: truncated ? repr.substring(0, maxLength) : repr,
      truncated: truncated,
    );
  }
}

final class DirectValueDto extends JsonValueDto {
  final Object? value;
  const DirectValueDto(this.value);

  @override
  Object? toJson() => value;
}

final class OpaqueValueDto extends JsonValueDto {
  final String typeName;
  final String repr;
  final bool truncated;

  const OpaqueValueDto({
    required this.typeName,
    required this.repr,
    required this.truncated,
  });

  @override
  Object? toJson() => {
        '\$kind': 'opaque',
        'typeName': typeName,
        'repr': repr,
        'truncated': truncated,
      };
}

final class EntityDto {
  final String id;
  final String name;
  final EntityKindDto kind;
  final String typeName;
  final String orchestrationId;
  final JsonValueDto? value;
  final JsonValueDto? previous;
  final int? updatedAtMicros;

  const EntityDto({
    required this.id,
    required this.name,
    required this.kind,
    required this.typeName,
    required this.orchestrationId,
    this.value,
    this.previous,
    this.updatedAtMicros,
  });

  Map<String, Object?> toJson() => {
        'id': id,
        'name': name,
        'kind': kind.name,
        'typeName': typeName,
        'orchestrationId': orchestrationId,
        if (value != null) 'value': value!.toJson(),
        if (previous != null) 'previous': previous!.toJson(),
        if (updatedAtMicros != null) 'updatedAtMicros': updatedAtMicros,
      };

  factory EntityDto.fromJson(Map<String, Object?> json) => EntityDto(
        id: json['id'] as String,
        name: json['name'] as String,
        kind: entityKindDtoFromName(json['kind'] as String),
        typeName: json['typeName'] as String,
        orchestrationId: json['orchestrationId'] as String,
        value: json.containsKey('value') ? JsonValueDto.fromJson(json['value']) : null,
        previous: json.containsKey('previous') ? JsonValueDto.fromJson(json['previous']) : null,
        updatedAtMicros: json['updatedAtMicros'] as int?,
      );
}

final class SystemDto {
  final String id;
  final String name;
  final SystemKindDto kind;
  final String orchestrationId;
  final List<String> reactsToEntityIds;
  final List<String> interactsWithEntityIds;

  const SystemDto({
    required this.id,
    required this.name,
    required this.kind,
    required this.orchestrationId,
    this.reactsToEntityIds = const [],
    this.interactsWithEntityIds = const [],
  });

  Map<String, Object?> toJson() => {
        'id': id,
        'name': name,
        'kind': kind.name,
        'orchestrationId': orchestrationId,
        'reactsToEntityIds': reactsToEntityIds,
        'interactsWithEntityIds': interactsWithEntityIds,
      };

  factory SystemDto.fromJson(Map<String, Object?> json) => SystemDto(
        id: json['id'] as String,
        name: json['name'] as String,
        kind: systemKindDtoFromName(json['kind'] as String),
        orchestrationId: json['orchestrationId'] as String,
        reactsToEntityIds: (json['reactsToEntityIds'] as List?)?.cast<String>() ?? const [],
        interactsWithEntityIds: (json['interactsWithEntityIds'] as List?)?.cast<String>() ?? const [],
      );
}

final class OrchestrationDto {
  final String id;
  final String name;
  final String orchestratorId;
  final List<EntityDto> entities;
  final List<SystemDto> systems;

  const OrchestrationDto({
    required this.id,
    required this.name,
    required this.orchestratorId,
    this.entities = const [],
    this.systems = const [],
  });

  Map<String, Object?> toJson() => {
        'id': id,
        'name': name,
        'orchestratorId': orchestratorId,
        'entities': entities.map((e) => e.toJson()).toList(),
        'systems': systems.map((s) => s.toJson()).toList(),
      };

  factory OrchestrationDto.fromJson(Map<String, Object?> json) => OrchestrationDto(
        id: json['id'] as String,
        name: json['name'] as String,
        orchestratorId: json['orchestratorId'] as String,
        entities: (json['entities'] as List? ?? const [])
            .map((e) => EntityDto.fromJson((e as Map).cast<String, Object?>()))
            .toList(),
        systems: (json['systems'] as List? ?? const [])
            .map((s) => SystemDto.fromJson((s as Map).cast<String, Object?>()))
            .toList(),
      );
}

final class OrchestratorDto {
  final String id;
  final String name;
  final bool isActive;
  final List<OrchestrationDto> orchestrations;

  const OrchestratorDto({
    required this.id,
    required this.name,
    required this.isActive,
    this.orchestrations = const [],
  });

  Map<String, Object?> toJson() => {
        'id': id,
        'name': name,
        'isActive': isActive,
        'orchestrations': orchestrations.map((o) => o.toJson()).toList(),
      };

  factory OrchestratorDto.fromJson(Map<String, Object?> json) => OrchestratorDto(
        id: json['id'] as String,
        name: json['name'] as String,
        isActive: json['isActive'] as bool? ?? false,
        orchestrations: (json['orchestrations'] as List? ?? const [])
            .map((o) => OrchestrationDto.fromJson((o as Map).cast<String, Object?>()))
            .toList(),
      );
}

final class LogDto {
  final String id;
  final LogLevelDto level;
  final int tsMicros;
  final String message;
  final String? orchestrationId;
  final String? systemId;
  final List<String> entityRefs;
  final String? stack;

  const LogDto({
    required this.id,
    required this.level,
    required this.tsMicros,
    required this.message,
    this.orchestrationId,
    this.systemId,
    this.entityRefs = const [],
    this.stack,
  });

  Map<String, Object?> toJson() => {
        'id': id,
        'level': level.name,
        'tsMicros': tsMicros,
        'message': message,
        if (orchestrationId != null) 'orchestrationId': orchestrationId,
        if (systemId != null) 'systemId': systemId,
        if (entityRefs.isNotEmpty) 'entityRefs': entityRefs,
        if (stack != null) 'stack': stack,
      };

  factory LogDto.fromJson(Map<String, Object?> json) => LogDto(
        id: json['id'] as String,
        level: logLevelDtoFromName(json['level'] as String),
        tsMicros: json['tsMicros'] as int,
        message: json['message'] as String? ?? '',
        orchestrationId: json['orchestrationId'] as String?,
        systemId: json['systemId'] as String?,
        entityRefs: (json['entityRefs'] as List?)?.cast<String>() ?? const [],
        stack: json['stack'] as String?,
      );
}

final class SubscribeResponseDto {
  final int protocolVersion;
  final String sessionId;
  final int serverStartedAtMicros;
  final int seq;
  final List<OrchestratorDto> orchestrators;
  final List<LogDto> recentLogs;

  const SubscribeResponseDto({
    required this.protocolVersion,
    required this.sessionId,
    required this.serverStartedAtMicros,
    required this.seq,
    required this.orchestrators,
    required this.recentLogs,
  });

  Map<String, Object?> toJson() => {
        'protocolVersion': protocolVersion,
        'sessionId': sessionId,
        'serverStartedAtMicros': serverStartedAtMicros,
        'seq': seq,
        'orchestrators': orchestrators.map((o) => o.toJson()).toList(),
        'recentLogs': recentLogs.map((l) => l.toJson()).toList(),
      };

  factory SubscribeResponseDto.fromJson(Map<String, Object?> json) => SubscribeResponseDto(
        protocolVersion: json['protocolVersion'] as int,
        sessionId: json['sessionId'] as String,
        serverStartedAtMicros: json['serverStartedAtMicros'] as int,
        seq: json['seq'] as int,
        orchestrators: (json['orchestrators'] as List? ?? const [])
            .map((o) => OrchestratorDto.fromJson((o as Map).cast<String, Object?>()))
            .toList(),
        recentLogs: (json['recentLogs'] as List? ?? const [])
            .map((l) => LogDto.fromJson((l as Map).cast<String, Object?>()))
            .toList(),
      );
}

/// Sealed union of every push event.
sealed class EventDto {
  final int seq;
  final int tsMicros;
  final String sessionId;

  const EventDto({
    required this.seq,
    required this.tsMicros,
    required this.sessionId,
  });

  String get kind;

  Map<String, Object?> toJson() => {
        'kind': kind,
        'seq': seq,
        'tsMicros': tsMicros,
        'sessionId': sessionId,
        ...payload(),
      };

  Map<String, Object?> payload();

  factory EventDto.fromJson(Map<String, Object?> json) {
    final kind = json['kind'] as String;
    final seq = json['seq'] as int;
    final ts = json['tsMicros'] as int;
    final sessionId = json['sessionId'] as String;
    return switch (kind) {
      'heartbeat' => HeartbeatEventDto(seq: seq, tsMicros: ts, sessionId: sessionId),
      'batch' => BatchEventDto(
          seq: seq,
          tsMicros: ts,
          sessionId: sessionId,
          entityUpdates: (json['entityUpdates'] as List? ?? const [])
              .map((e) => EntityUpdatedEventDto.fromMap((e as Map).cast<String, Object?>()))
              .toList(),
          entityFirings: (json['entityFirings'] as List? ?? const [])
              .map((e) => EntityFiredEventDto.fromMap((e as Map).cast<String, Object?>()))
              .toList(),
          systemFirings: (json['systemFirings'] as List? ?? const [])
              .map((e) => SystemFiredEventDto.fromMap((e as Map).cast<String, Object?>()))
              .toList(),
          droppedFirings: json['droppedFirings'] as int? ?? 0,
        ),
      'log' => LogEmittedEventDto(
          seq: seq,
          tsMicros: ts,
          sessionId: sessionId,
          log: LogDto.fromJson((json['log'] as Map).cast<String, Object?>()),
        ),
      'topology' => TopologyEventDto.fromJsonInner(json, seq: seq, tsMicros: ts, sessionId: sessionId),
      _ => throw FormatException('Unknown event kind: $kind'),
    };
  }
}

final class HeartbeatEventDto extends EventDto {
  const HeartbeatEventDto({
    required super.seq,
    required super.tsMicros,
    required super.sessionId,
  });

  @override
  String get kind => 'heartbeat';

  @override
  Map<String, Object?> payload() => const {};
}

final class EntityUpdatedEventDto {
  final String entityId;
  final JsonValueDto? value;
  final JsonValueDto? previous;
  final int updatedAtMicros;
  final int updateCount;

  const EntityUpdatedEventDto({
    required this.entityId,
    required this.value,
    required this.previous,
    required this.updatedAtMicros,
    required this.updateCount,
  });

  Map<String, Object?> toMap() => {
        'entityId': entityId,
        if (value != null) 'value': value!.toJson(),
        if (previous != null) 'previous': previous!.toJson(),
        'updatedAtMicros': updatedAtMicros,
        'updateCount': updateCount,
      };

  factory EntityUpdatedEventDto.fromMap(Map<String, Object?> json) => EntityUpdatedEventDto(
        entityId: json['entityId'] as String,
        value: json.containsKey('value') ? JsonValueDto.fromJson(json['value']) : null,
        previous: json.containsKey('previous') ? JsonValueDto.fromJson(json['previous']) : null,
        updatedAtMicros: json['updatedAtMicros'] as int,
        updateCount: json['updateCount'] as int,
      );
}

final class EntityFiredEventDto {
  final String entityId;
  final JsonValueDto? payloadValue;
  final int firedAtMicros;
  final int fireCount;

  const EntityFiredEventDto({
    required this.entityId,
    required this.payloadValue,
    required this.firedAtMicros,
    required this.fireCount,
  });

  Map<String, Object?> toMap() => {
        'entityId': entityId,
        if (payloadValue != null) 'payload': payloadValue!.toJson(),
        'firedAtMicros': firedAtMicros,
        'fireCount': fireCount,
      };

  factory EntityFiredEventDto.fromMap(Map<String, Object?> json) => EntityFiredEventDto(
        entityId: json['entityId'] as String,
        payloadValue: json.containsKey('payload') ? JsonValueDto.fromJson(json['payload']) : null,
        firedAtMicros: json['firedAtMicros'] as int,
        fireCount: json['fireCount'] as int,
      );
}

final class SystemFiredEventDto {
  final String systemId;
  final String? triggerEntityId;
  final int durationMicros;
  final bool succeeded;
  final int firedAtMicros;

  const SystemFiredEventDto({
    required this.systemId,
    required this.triggerEntityId,
    required this.durationMicros,
    required this.succeeded,
    required this.firedAtMicros,
  });

  Map<String, Object?> toMap() => {
        'systemId': systemId,
        if (triggerEntityId != null) 'triggerEntityId': triggerEntityId,
        'durationMicros': durationMicros,
        'succeeded': succeeded,
        'firedAtMicros': firedAtMicros,
      };

  factory SystemFiredEventDto.fromMap(Map<String, Object?> json) => SystemFiredEventDto(
        systemId: json['systemId'] as String,
        triggerEntityId: json['triggerEntityId'] as String?,
        durationMicros: json['durationMicros'] as int,
        succeeded: json['succeeded'] as bool,
        firedAtMicros: json['firedAtMicros'] as int,
      );
}

final class BatchEventDto extends EventDto {
  final List<EntityUpdatedEventDto> entityUpdates;
  final List<EntityFiredEventDto> entityFirings;
  final List<SystemFiredEventDto> systemFirings;
  final int droppedFirings;

  const BatchEventDto({
    required super.seq,
    required super.tsMicros,
    required super.sessionId,
    required this.entityUpdates,
    required this.entityFirings,
    required this.systemFirings,
    required this.droppedFirings,
  });

  @override
  String get kind => 'batch';

  @override
  Map<String, Object?> payload() => {
        'entityUpdates': entityUpdates.map((e) => e.toMap()).toList(),
        'entityFirings': entityFirings.map((e) => e.toMap()).toList(),
        'systemFirings': systemFirings.map((e) => e.toMap()).toList(),
        if (droppedFirings > 0) 'droppedFirings': droppedFirings,
      };
}

final class LogEmittedEventDto extends EventDto {
  final LogDto log;

  const LogEmittedEventDto({
    required super.seq,
    required super.tsMicros,
    required super.sessionId,
    required this.log,
  });

  @override
  String get kind => 'log';

  @override
  Map<String, Object?> payload() => {'log': log.toJson()};
}

enum TopologyChangeKind {
  orchestratorAdded,
  orchestratorRemoved,
  orchestrationAdded,
  orchestrationRemoved,
  entityAdded,
  entityRemoved,
  systemAdded,
  systemRemoved,
}

final class TopologyEventDto extends EventDto {
  final TopologyChangeKind change;
  final OrchestratorDto? orchestrator;
  final OrchestrationDto? orchestration;
  final EntityDto? entity;
  final SystemDto? system;
  final String? removedId;

  const TopologyEventDto({
    required super.seq,
    required super.tsMicros,
    required super.sessionId,
    required this.change,
    this.orchestrator,
    this.orchestration,
    this.entity,
    this.system,
    this.removedId,
  });

  @override
  String get kind => 'topology';

  @override
  Map<String, Object?> payload() => {
        'change': change.name,
        if (orchestrator != null) 'orchestrator': orchestrator!.toJson(),
        if (orchestration != null) 'orchestration': orchestration!.toJson(),
        if (entity != null) 'entity': entity!.toJson(),
        if (system != null) 'system': system!.toJson(),
        if (removedId != null) 'removedId': removedId,
      };

  factory TopologyEventDto.fromJsonInner(
    Map<String, Object?> json, {
    required int seq,
    required int tsMicros,
    required String sessionId,
  }) {
    return TopologyEventDto(
      seq: seq,
      tsMicros: tsMicros,
      sessionId: sessionId,
      change: TopologyChangeKind.values.byName(json['change'] as String),
      orchestrator: json['orchestrator'] is Map
          ? OrchestratorDto.fromJson((json['orchestrator'] as Map).cast<String, Object?>())
          : null,
      orchestration: json['orchestration'] is Map
          ? OrchestrationDto.fromJson((json['orchestration'] as Map).cast<String, Object?>())
          : null,
      entity: json['entity'] is Map ? EntityDto.fromJson((json['entity'] as Map).cast<String, Object?>()) : null,
      system: json['system'] is Map ? SystemDto.fromJson((json['system'] as Map).cast<String, Object?>()) : null,
      removedId: json['removedId'] as String?,
    );
  }
}
