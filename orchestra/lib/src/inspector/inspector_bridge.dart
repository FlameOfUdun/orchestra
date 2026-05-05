// ignore_for_file: invalid_use_of_visible_for_testing_member

import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;

import '../base/export.dart';
import '../utilities/logger.dart';
import 'ring_buffer.dart';
import 'wire.dart';

typedef OrchestratorRegistry = Iterable<Orchestrator> Function();

const int _kFiringBufferCap = 4096;
const int _kLogRingCap = 5000;
const Duration _kHeartbeatInterval = Duration(seconds: 2);

/// Singleton bridge: registers DevTools service extensions, posts events, and
/// coalesces high-frequency emit calls into microtask-batched payloads.
///
/// Hot-path emit sites must guard with [enabled] before any work.
final class InspectorBridge {
  InspectorBridge._();

  static final InspectorBridge instance = InspectorBridge._();

  bool _registered = false;
  bool _subscribed = false;
  String _sessionId = '';
  int _seq = 0;
  int _serverStartedAtMicros = 0;
  int _nextEntityId = 0;
  int _nextSystemId = 0;
  int _nextLogId = 0;

  OrchestratorRegistry? _registry;

  // Coalescing buffers.
  final Map<String, EntityUpdatedEventDto> _pendingUpdates = {};
  final List<EntityFiredEventDto> _pendingEntityFirings = [];
  final List<SystemFiredEventDto> _pendingSystemFirings = [];
  int _droppedFirings = 0;
  bool _flushScheduled = false;

  // Bounded buffers for the bootstrap snapshot.
  final RingBuffer<LogDto> _logs = RingBuffer<LogDto>(_kLogRingCap);

  // Per-entity counters for change tracking.
  final Map<String, int> _updateCounts = {};
  final Map<String, int> _fireCounts = {};

  Timer? _heartbeatTimer;

  bool get enabled => _subscribed;

  /// Registers DevTools service extensions. Called once from
  /// `Orchestrator._ensureDevtoolsRegistered`.
  void registerDevtools(OrchestratorRegistry registry) {
    if (_registered) return;
    _registered = true;
    _registry = registry;
    _serverStartedAtMicros = _nowMicros();

    developer.registerExtension(kSubscribeExtension,
        (method, parameters) async {
      final response = _onSubscribe();
      return developer.ServiceExtensionResponse.result(
          jsonEncode(response.toJson()));
    });

    developer.registerExtension(kUnsubscribeExtension,
        (method, parameters) async {
      _onUnsubscribe();
      return developer.ServiceExtensionResponse.result('{}');
    });

    developer.registerExtension(kResyncExtension, (method, parameters) async {
      final response = _buildSnapshot();
      return developer.ServiceExtensionResponse.result(
          jsonEncode(response.toJson()));
    });
  }

  /// Allocates a stable id for an entity at registration time.
  String allocEntityId() => 'entity_${_nextEntityId++}';

  /// Allocates a stable id for a system at registration time.
  String allocSystemId() => 'system_${_nextSystemId++}';

  // ─── Topology ────────────────────────────────────────────────────────────

  void orchestratorActivated(Orchestrator orchestrator) {
    if (!enabled) return;
    _post(TopologyEventDto(
      seq: ++_seq,
      tsMicros: _nowMicros(),
      sessionId: _sessionId,
      change: TopologyChangeKind.orchestratorAdded,
      orchestrator: _orchestratorDto(orchestrator),
    ));
  }

  void orchestratorDeactivated(Orchestrator orchestrator) {
    if (!enabled) return;
    _post(TopologyEventDto(
      seq: ++_seq,
      tsMicros: _nowMicros(),
      sessionId: _sessionId,
      change: TopologyChangeKind.orchestratorRemoved,
      removedId: _orchestratorId(orchestrator),
    ));
  }

  void orchestrationAttached(Orchestration orchestration) {
    if (!enabled) return;
    _post(TopologyEventDto(
      seq: ++_seq,
      tsMicros: _nowMicros(),
      sessionId: _sessionId,
      change: TopologyChangeKind.orchestrationAdded,
      orchestration: _orchestrationDto(orchestration),
    ));
  }

  void entityAdded(Entity entity) {
    if (!enabled) return;
    final dto = _entityDto(entity);
    if (dto == null) return;
    _post(TopologyEventDto(
      seq: ++_seq,
      tsMicros: _nowMicros(),
      sessionId: _sessionId,
      change: TopologyChangeKind.entityAdded,
      entity: dto,
    ));
  }

  void systemAdded(System system) {
    if (!enabled) return;
    final dto = _systemDto(system);
    if (dto == null) return;
    _post(TopologyEventDto(
      seq: ++_seq,
      tsMicros: _nowMicros(),
      sessionId: _sessionId,
      change: TopologyChangeKind.systemAdded,
      system: dto,
    ));
  }

  // ─── High-frequency stream (coalesced) ───────────────────────────────────

  void componentUpdated(Entity entity, Object? value, Object? previous) {
    if (!enabled) return;
    final id = entity.inspectorId;
    if (id == null) return;
    final count = (_updateCounts[id] ?? 0) + 1;
    _updateCounts[id] = count;
    _pendingUpdates[id] = EntityUpdatedEventDto(
      entityId: id,
      value: JsonValueDto.encode(value),
      previous: JsonValueDto.encode(previous),
      updatedAtMicros: _nowMicros(),
      updateCount: count,
    );
    _scheduleFlush();
  }

  void eventFired(Entity entity, Object? payload) {
    if (!enabled) return;
    final id = entity.inspectorId;
    if (id == null) return;
    final count = (_fireCounts[id] ?? 0) + 1;
    _fireCounts[id] = count;
    if (_pendingEntityFirings.length >= _kFiringBufferCap) {
      _droppedFirings++;
    } else {
      _pendingEntityFirings.add(EntityFiredEventDto(
        entityId: id,
        payloadValue: payload == null ? null : JsonValueDto.encode(payload),
        firedAtMicros: _nowMicros(),
        fireCount: count,
      ));
    }
    _scheduleFlush();
  }

  void systemFired({
    required String systemId,
    required String? triggerEntityId,
    required int durationMicros,
    required bool succeeded,
  }) {
    if (!enabled) return;
    if (_pendingSystemFirings.length >= _kFiringBufferCap) {
      _droppedFirings++;
      _scheduleFlush();
      return;
    }
    _pendingSystemFirings.add(SystemFiredEventDto(
      systemId: systemId,
      triggerEntityId: triggerEntityId,
      durationMicros: durationMicros,
      succeeded: succeeded,
      firedAtMicros: _nowMicros(),
    ));
    _scheduleFlush();
  }

  // ─── Logs ────────────────────────────────────────────────────────────────

  void logEmitted({
    required LogLevel level,
    required String message,
    String? orchestrationId,
    String? systemId,
    List<String> entityRefs = const [],
    String? stack,
  }) {
    final id = 'log_${_nextLogId++}';
    final dto = LogDto(
      id: id,
      level: logLevelDtoFromRuntime(level),
      tsMicros: _nowMicros(),
      message: message,
      orchestrationId: orchestrationId,
      systemId: systemId,
      entityRefs: entityRefs,
      stack: stack,
    );
    _logs.add(dto);
    if (!enabled) return;
    _post(LogEmittedEventDto(
      seq: ++_seq,
      tsMicros: dto.tsMicros,
      sessionId: _sessionId,
      log: dto,
    ));
  }

  // ─── Subscription lifecycle ──────────────────────────────────────────────

  SubscribeResponseDto _onSubscribe() {
    _subscribed = true;
    _sessionId = 'session_${DateTime.now().microsecondsSinceEpoch}';
    _seq = 0;
    _droppedFirings = 0;
    _pendingUpdates.clear();
    _pendingEntityFirings.clear();
    _pendingSystemFirings.clear();
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(_kHeartbeatInterval, (_) => _heartbeat());
    return _buildSnapshot();
  }

  void _onUnsubscribe() {
    _subscribed = false;
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    _pendingUpdates.clear();
    _pendingEntityFirings.clear();
    _pendingSystemFirings.clear();
    _droppedFirings = 0;
  }

  SubscribeResponseDto _buildSnapshot() {
    final orchestrators = (_registry?.call() ?? const <Orchestrator>[])
        .map(_orchestratorDto)
        .toList();
    return SubscribeResponseDto(
      protocolVersion: kInspectorProtocolVersion,
      sessionId: _sessionId,
      serverStartedAtMicros: _serverStartedAtMicros,
      seq: _seq,
      orchestrators: orchestrators,
      recentLogs: _logs.toList(),
    );
  }

  void _heartbeat() {
    if (!enabled) return;
    _post(HeartbeatEventDto(
      seq: ++_seq,
      tsMicros: _nowMicros(),
      sessionId: _sessionId,
    ));
  }

  // ─── Flush plumbing ──────────────────────────────────────────────────────

  void _scheduleFlush() {
    if (_flushScheduled) return;
    _flushScheduled = true;
    scheduleMicrotask(_flush);
  }

  void _flush() {
    _flushScheduled = false;
    if (!enabled) {
      _pendingUpdates.clear();
      _pendingEntityFirings.clear();
      _pendingSystemFirings.clear();
      _droppedFirings = 0;
      return;
    }
    if (_pendingUpdates.isEmpty &&
        _pendingEntityFirings.isEmpty &&
        _pendingSystemFirings.isEmpty &&
        _droppedFirings == 0) {
      return;
    }
    final batch = BatchEventDto(
      seq: ++_seq,
      tsMicros: _nowMicros(),
      sessionId: _sessionId,
      entityUpdates: _pendingUpdates.values.toList(),
      entityFirings: List.of(_pendingEntityFirings),
      systemFirings: List.of(_pendingSystemFirings),
      droppedFirings: _droppedFirings,
    );
    _pendingUpdates.clear();
    _pendingEntityFirings.clear();
    _pendingSystemFirings.clear();
    _droppedFirings = 0;
    _post(batch);
  }

  void _post(EventDto event) {
    developer.postEvent(kInspectorEventStream, event.toJson());
  }

  // ─── DTO building ────────────────────────────────────────────────────────

  String _orchestratorId(Orchestrator orchestrator) => orchestrator.identifier;

  String _orchestrationId(Orchestration orchestration) =>
      orchestration.identifier;

  OrchestratorDto _orchestratorDto(Orchestrator orchestrator) {
    return OrchestratorDto(
      id: _orchestratorId(orchestrator),
      name: orchestrator.identifier,
      isActive: orchestrator.isActive,
      orchestrations:
          orchestrator.orchestrations.map(_orchestrationDto).toList(),
    );
  }

  OrchestrationDto _orchestrationDto(Orchestration orchestration) {
    final id = _orchestrationId(orchestration);
    final entities = orchestration.entities.values
        .map(_entityDto)
        .whereType<EntityDto>()
        .toList();
    final systems = <SystemDto>[];
    void addAll(Iterable<System> source) {
      for (final s in source) {
        final dto = _systemDto(s);
        if (dto != null) systems.add(dto);
      }
    }

    addAll(orchestration.initializeSystems);
    addAll(orchestration.executeSystems);
    addAll(orchestration.cleanupSystems);
    addAll(orchestration.teardownSystems);
    addAll(orchestration.reactiveSystems);

    return OrchestrationDto(
      id: id,
      name: orchestration.runtimeType.toString(),
      orchestratorId: orchestration.orchestrator?.identifier ?? '',
      entities: entities,
      systems: systems,
    );
  }

  EntityDto? _entityDto(Entity entity) {
    final id = entity.inspectorId;
    if (id == null) return null;
    final orchestrationId = entity.orchestration?.identifier ?? '';
    final EntityKindDto kind;
    Object? value;
    Object? previous;
    int? updatedAtMicros;
    String typeName = entity.runtimeType.toString();

    if (entity is Component) {
      kind = EntityKindDto.component;
      value = entity.value;
      previous = entity.previous;
      updatedAtMicros = entity.updatedAt?.microsecondsSinceEpoch;
    } else if (entity is DataEvent) {
      kind = EntityKindDto.dataEvent;
      value = entity.dataOrNull;
      updatedAtMicros = entity.triggeredAt?.microsecondsSinceEpoch;
    } else if (entity is Event) {
      kind = EntityKindDto.event;
      updatedAtMicros = entity.triggeredAt?.microsecondsSinceEpoch;
    } else if (entity is Dependency) {
      kind = EntityKindDto.dependency;
      value = entity.value;
    } else {
      return null;
    }

    return EntityDto(
      id: id,
      name: entity.runtimeType.toString(),
      kind: kind,
      typeName: typeName,
      orchestrationId: orchestrationId,
      value: value == null ? null : JsonValueDto.encode(value),
      previous: previous == null ? null : JsonValueDto.encode(previous),
      updatedAtMicros: updatedAtMicros,
    );
  }

  SystemDto? _systemDto(System system) {
    final id = system.inspectorId;
    if (id == null) return null;
    final orchestrationId = system.orchestration?.identifier ?? '';
    final SystemKindDto kind;
    final reactsTo = <String>[];

    if (system is ReactiveSystem) {
      kind = SystemKindDto.reactive;
      final orchestrator = system.orchestration?.orchestrator;
      if (orchestrator != null) {
        for (final type in system.reactsTo) {
          try {
            final entity = orchestrator.getType(type);
            final eid = entity.inspectorId;
            if (eid != null) reactsTo.add(eid);
          } catch (_) {
            // entity not yet registered; skip
          }
        }
      }
    } else if (system is InitializeSystem) {
      kind = SystemKindDto.initialize;
    } else if (system is ExecuteSystem) {
      kind = SystemKindDto.execute;
    } else if (system is CleanupSystem) {
      kind = SystemKindDto.cleanup;
    } else if (system is TeardownSystem) {
      kind = SystemKindDto.teardown;
    } else {
      return null;
    }

    final interactsWith = <String>[];
    final orchestrator = system.orchestration?.orchestrator;
    if (orchestrator != null) {
      for (final type in system.interactsWith) {
        try {
          final entity = orchestrator.getType(type);
          final eid = entity.inspectorId;
          if (eid != null) interactsWith.add(eid);
        } catch (_) {
          // not yet registered
        }
      }
    }

    return SystemDto(
      id: id,
      name: system.runtimeType.toString(),
      kind: kind,
      orchestrationId: orchestrationId,
      reactsToEntityIds: reactsTo,
      interactsWithEntityIds: interactsWith,
    );
  }

  int _nowMicros() => DateTime.now().microsecondsSinceEpoch;
}
