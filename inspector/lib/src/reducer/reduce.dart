import 'package:orchestra/inspector_export.dart';

import '../domain/inspector_state.dart';
import '../domain/log_entry.dart';
import '../domain/nodes.dart';
import '../domain/system_firing.dart';
import '../transport/inspector_message.dart';

InspectorState reduce(InspectorState s, InspectorMessage msg) {
  return switch (msg) {
    ConnectionChanged(state: final cs) => s.copyWith(connection: cs),
    Bootstrap(data: final data) => _applyBootstrap(s, data),
    RuntimeEvent(event: final e) => _applyEvent(s, e),
    TransportError() => s,
  };
}

InspectorState _applyBootstrap(InspectorState s, SubscribeResponseDto data) {
  final orchestrators = <String, OrchestratorNode>{};
  final orchestrations = <String, OrchestrationNode>{};
  final entities = <String, EntityNode>{};
  final systems = <String, SystemNode>{};

  for (final orchestrator in data.orchestrators) {
    orchestrators[orchestrator.id] = OrchestratorNode(
      id: orchestrator.id,
      name: orchestrator.name,
      isActive: orchestrator.isActive,
      orchestrationIds: orchestrator.orchestrations.map((o) => o.id).toList(),
    );
    for (final orchestration in orchestrator.orchestrations) {
      orchestrations[orchestration.id] = OrchestrationNode(
        id: orchestration.id,
        name: orchestration.name,
        orchestratorId: orchestrator.id,
        entityIds: orchestration.entities.map((e) => e.id).toList(),
        systemIds: orchestration.systems.map((sys) => sys.id).toList(),
      );
      for (final entity in orchestration.entities) {
        entities[entity.id] = EntityNode.fromDto(entity);
      }
      for (final system in orchestration.systems) {
        systems[system.id] = SystemNode.fromDto(system);
      }
    }
  }

  var logs = s.logs;
  // Bootstrap brings a recent-logs window; replace any existing buffer with it.
  final freshLogs = InspectorState.initial.logs;
  logs = freshLogs.pushAll(data.recentLogs.map(LogEntry.fromDto));

  return s.copyWith(
    sessionId: data.sessionId,
    protocolVersion: data.protocolVersion,
    lastSeq: data.seq,
    orchestrators: orchestrators,
    orchestrations: orchestrations,
    entities: entities,
    systems: systems,
    logs: logs,
    firings: InspectorState.initial.firings,
  );
}

InspectorState _applyEvent(InspectorState s, EventDto event) {
  // Drop events from a different session (e.g. straggler after hot restart).
  if (s.sessionId != null && event.sessionId != s.sessionId) {
    return s;
  }
  final next = s.copyWith(lastSeq: event.seq);
  return switch (event) {
    HeartbeatEventDto() => next,
    BatchEventDto() => _applyBatch(next, event),
    LogEmittedEventDto() => _applyLog(next, event),
    TopologyEventDto() => _applyTopology(next, event),
  };
}

InspectorState _applyBatch(InspectorState s, BatchEventDto batch) {
  Map<String, EntityNode>? entities;
  Map<String, SystemNode>? systems;
  var firings = s.firings;
  var stats = s.stats;

  if (batch.entityUpdates.isNotEmpty) {
    entities = Map<String, EntityNode>.of(s.entities);
    for (final upd in batch.entityUpdates) {
      final existing = entities[upd.entityId];
      if (existing == null) continue;
      entities[upd.entityId] = existing.copyWith(
        value: upd.value,
        previous: upd.previous,
        updatedAtMicros: upd.updatedAtMicros,
        updateCount: upd.updateCount,
      );
    }
  }

  if (batch.entityFirings.isNotEmpty) {
    entities ??= Map<String, EntityNode>.of(s.entities);
    for (final fired in batch.entityFirings) {
      final existing = entities[fired.entityId];
      if (existing == null) continue;
      entities[fired.entityId] = existing.copyWith(
        value: fired.payloadValue,
        updatedAtMicros: fired.firedAtMicros,
        updateCount: fired.fireCount,
      );
    }
  }

  if (batch.systemFirings.isNotEmpty) {
    systems = Map<String, SystemNode>.of(s.systems);
    for (final fired in batch.systemFirings) {
      firings = firings.push(SystemFiring(
        systemId: fired.systemId,
        triggerEntityId: fired.triggerEntityId,
        firedAtMicros: fired.firedAtMicros,
        durationMicros: fired.durationMicros,
        succeeded: fired.succeeded,
      ));
      final existing = systems[fired.systemId];
      if (existing == null) continue;
      systems[fired.systemId] = existing.copyWith(
        firingCount: existing.firingCount + 1,
        lastFiredAtMicros: fired.firedAtMicros,
        lastDurationMicros: fired.durationMicros,
        errorCount: existing.errorCount + (fired.succeeded ? 0 : 1),
      );
    }
  }

  if (batch.droppedFirings > 0 || batch.systemFirings.isNotEmpty || batch.entityUpdates.isNotEmpty || batch.entityFirings.isNotEmpty) {
    stats = stats.copyWith(
      droppedFirings: stats.droppedFirings + batch.droppedFirings,
      batchesReceived: stats.batchesReceived + 1,
    );
  }

  return s.copyWith(
    entities: entities,
    systems: systems,
    firings: firings,
    stats: stats,
  );
}

InspectorState _applyLog(InspectorState s, LogEmittedEventDto event) {
  return s.copyWith(logs: s.logs.push(LogEntry.fromDto(event.log)));
}

InspectorState _applyTopology(InspectorState s, TopologyEventDto event) {
  return switch (event.change) {
    TopologyChangeKind.orchestratorAdded => _orchestratorAdded(s, event),
    TopologyChangeKind.orchestratorRemoved => _orchestratorRemoved(s, event),
    TopologyChangeKind.orchestrationAdded => _orchestrationAdded(s, event),
    TopologyChangeKind.orchestrationRemoved => _orchestrationRemoved(s, event),
    TopologyChangeKind.entityAdded => _entityAdded(s, event),
    TopologyChangeKind.entityRemoved => _entityRemoved(s, event),
    TopologyChangeKind.systemAdded => _systemAdded(s, event),
    TopologyChangeKind.systemRemoved => _systemRemoved(s, event),
  };
}

InspectorState _orchestratorAdded(InspectorState s, TopologyEventDto event) {
  final orchestrator = event.orchestrator;
  if (orchestrator == null) return s;
  final orchestrators = Map<String, OrchestratorNode>.of(s.orchestrators);
  final orchestrations = Map<String, OrchestrationNode>.of(s.orchestrations);
  final entities = Map<String, EntityNode>.of(s.entities);
  final systems = Map<String, SystemNode>.of(s.systems);

  orchestrators[orchestrator.id] = OrchestratorNode(
    id: orchestrator.id,
    name: orchestrator.name,
    isActive: orchestrator.isActive,
    orchestrationIds: orchestrator.orchestrations.map((o) => o.id).toList(),
  );
  for (final orchestration in orchestrator.orchestrations) {
    orchestrations[orchestration.id] = OrchestrationNode(
      id: orchestration.id,
      name: orchestration.name,
      orchestratorId: orchestrator.id,
      entityIds: orchestration.entities.map((e) => e.id).toList(),
      systemIds: orchestration.systems.map((sys) => sys.id).toList(),
    );
    for (final entity in orchestration.entities) {
      entities[entity.id] = EntityNode.fromDto(entity);
    }
    for (final system in orchestration.systems) {
      systems[system.id] = SystemNode.fromDto(system);
    }
  }
  return s.copyWith(
    orchestrators: orchestrators,
    orchestrations: orchestrations,
    entities: entities,
    systems: systems,
  );
}

InspectorState _orchestratorRemoved(InspectorState s, TopologyEventDto event) {
  final id = event.removedId;
  if (id == null) return s;
  final orchestrator = s.orchestrators[id];
  if (orchestrator == null) return s;
  final orchestrators = Map<String, OrchestratorNode>.of(s.orchestrators)..remove(id);
  final orchestrations = Map<String, OrchestrationNode>.of(s.orchestrations);
  final entities = Map<String, EntityNode>.of(s.entities);
  final systems = Map<String, SystemNode>.of(s.systems);
  for (final orchestrationId in orchestrator.orchestrationIds) {
    final orchestration = orchestrations.remove(orchestrationId);
    if (orchestration == null) continue;
    for (final eid in orchestration.entityIds) {
      entities.remove(eid);
    }
    for (final sid in orchestration.systemIds) {
      systems.remove(sid);
    }
  }
  return s.copyWith(
    orchestrators: orchestrators,
    orchestrations: orchestrations,
    entities: entities,
    systems: systems,
  );
}

InspectorState _orchestrationAdded(InspectorState s, TopologyEventDto event) {
  final dto = event.orchestration;
  if (dto == null) return s;
  final orchestrations = Map<String, OrchestrationNode>.of(s.orchestrations);
  final entities = Map<String, EntityNode>.of(s.entities);
  final systems = Map<String, SystemNode>.of(s.systems);
  final orchestrators = Map<String, OrchestratorNode>.of(s.orchestrators);

  orchestrations[dto.id] = OrchestrationNode(
    id: dto.id,
    name: dto.name,
    orchestratorId: dto.orchestratorId,
    entityIds: dto.entities.map((e) => e.id).toList(),
    systemIds: dto.systems.map((sys) => sys.id).toList(),
  );
  for (final entity in dto.entities) {
    entities[entity.id] = EntityNode.fromDto(entity);
  }
  for (final system in dto.systems) {
    systems[system.id] = SystemNode.fromDto(system);
  }
  final parent = orchestrators[dto.orchestratorId];
  if (parent != null && !parent.orchestrationIds.contains(dto.id)) {
    orchestrators[dto.orchestratorId] = parent.copyWith(
      orchestrationIds: [...parent.orchestrationIds, dto.id],
    );
  }
  return s.copyWith(
    orchestrators: orchestrators,
    orchestrations: orchestrations,
    entities: entities,
    systems: systems,
  );
}

InspectorState _orchestrationRemoved(InspectorState s, TopologyEventDto event) {
  final id = event.removedId;
  if (id == null) return s;
  final orchestration = s.orchestrations[id];
  if (orchestration == null) return s;
  final orchestrations = Map<String, OrchestrationNode>.of(s.orchestrations)..remove(id);
  final entities = Map<String, EntityNode>.of(s.entities);
  final systems = Map<String, SystemNode>.of(s.systems);
  for (final eid in orchestration.entityIds) {
    entities.remove(eid);
  }
  for (final sid in orchestration.systemIds) {
    systems.remove(sid);
  }
  final orchestrators = Map<String, OrchestratorNode>.of(s.orchestrators);
  final parent = orchestrators[orchestration.orchestratorId];
  if (parent != null) {
    orchestrators[orchestration.orchestratorId] = parent.copyWith(
      orchestrationIds: parent.orchestrationIds.where((it) => it != id).toList(),
    );
  }
  return s.copyWith(
    orchestrators: orchestrators,
    orchestrations: orchestrations,
    entities: entities,
    systems: systems,
  );
}

InspectorState _entityAdded(InspectorState s, TopologyEventDto event) {
  final dto = event.entity;
  if (dto == null) return s;
  final entities = Map<String, EntityNode>.of(s.entities);
  entities[dto.id] = EntityNode.fromDto(dto);
  final orchestrations = Map<String, OrchestrationNode>.of(s.orchestrations);
  final parent = orchestrations[dto.orchestrationId];
  if (parent != null && !parent.entityIds.contains(dto.id)) {
    orchestrations[dto.orchestrationId] = parent.copyWith(
      entityIds: [...parent.entityIds, dto.id],
    );
  }
  return s.copyWith(entities: entities, orchestrations: orchestrations);
}

InspectorState _entityRemoved(InspectorState s, TopologyEventDto event) {
  final id = event.removedId;
  if (id == null) return s;
  final entity = s.entities[id];
  if (entity == null) return s;
  final entities = Map<String, EntityNode>.of(s.entities)..remove(id);
  final orchestrations = Map<String, OrchestrationNode>.of(s.orchestrations);
  final parent = orchestrations[entity.orchestrationId];
  if (parent != null) {
    orchestrations[entity.orchestrationId] = parent.copyWith(
      entityIds: parent.entityIds.where((it) => it != id).toList(),
    );
  }
  return s.copyWith(entities: entities, orchestrations: orchestrations);
}

InspectorState _systemAdded(InspectorState s, TopologyEventDto event) {
  final dto = event.system;
  if (dto == null) return s;
  final systems = Map<String, SystemNode>.of(s.systems);
  systems[dto.id] = SystemNode.fromDto(dto);
  final orchestrations = Map<String, OrchestrationNode>.of(s.orchestrations);
  final parent = orchestrations[dto.orchestrationId];
  if (parent != null && !parent.systemIds.contains(dto.id)) {
    orchestrations[dto.orchestrationId] = parent.copyWith(
      systemIds: [...parent.systemIds, dto.id],
    );
  }
  return s.copyWith(systems: systems, orchestrations: orchestrations);
}

InspectorState _systemRemoved(InspectorState s, TopologyEventDto event) {
  final id = event.removedId;
  if (id == null) return s;
  final system = s.systems[id];
  if (system == null) return s;
  final systems = Map<String, SystemNode>.of(s.systems)..remove(id);
  final orchestrations = Map<String, OrchestrationNode>.of(s.orchestrations);
  final parent = orchestrations[system.orchestrationId];
  if (parent != null) {
    orchestrations[system.orchestrationId] = parent.copyWith(
      systemIds: parent.systemIds.where((it) => it != id).toList(),
    );
  }
  return s.copyWith(systems: systems, orchestrations: orchestrations);
}
