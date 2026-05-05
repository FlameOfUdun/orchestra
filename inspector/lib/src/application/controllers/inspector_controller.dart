import 'package:flutter/foundation.dart';

import '../../domain/inspector_state.dart' hide kLogRingCapacity, kFiringRingCapacity;
import '../../domain/log_entry.dart';
import '../../domain/nodes.dart';
import '../../domain/ring_buffer.dart';
import '../../domain/snapshot/runtime_element.dart';
import '../../domain/snapshot/runtime_log.dart';
import '../../domain/snapshot/runtime_orchestration.dart';
import '../../domain/snapshot/runtime_orchestrator.dart';
import '../../domain/snapshot/runtime_snapshot.dart';
import '../../domain/snapshot/runtime_system.dart';
import '../../store/inspector_store.dart';
import '../../transport/inspector_client.dart';

/// High-level controller that owns connection lifecycle and exposes a
/// [RuntimeSnapshot] for the presentation layer.
///
/// This is the single integration point for new UI code. It wraps
/// [InspectorStore] during the migration from [InspectorState] to
/// [RuntimeSnapshot]; once the migration is complete the store will be
/// absorbed into this controller.
final class InspectorController extends ChangeNotifier
    implements ValueListenable<RuntimeSnapshot> {
  InspectorController(InspectorClient client)
      : _store = InspectorStore(client),
        _client = client {
    _listener = () {
      _snapshot = null; // Invalidate the cached projection.
      notifyListeners();
    };
    _store.addListener(_listener);
  }

  final InspectorStore _store;
  final InspectorClient _client;
  late final VoidCallback _listener;

  RuntimeSnapshot? _snapshot;

  /// The underlying store – exposed for backward-compat with old UI widgets
  /// during the migration.  New code should use [value] / [RuntimeSnapshot].
  InspectorStore get store => _store;

  /// Current runtime snapshot, lazily projected from the internal state.
  @override
  RuntimeSnapshot get value => _snapshot ??= _project(_store.value);

  // ─── Connection lifecycle ────────────────────────────────────────────────

  Future<void> connect() => _client.connect();
  Future<void> resync() => _client.resync();
  Future<void> disconnect() => _client.disconnect();

  @override
  void dispose() {
    _store.removeListener(_listener);
    _store.dispose();
    super.dispose();
  }

  // ─── Projection ─────────────────────────────────────────────────────────

  static RuntimeSnapshot _project(InspectorState s) {
    return RuntimeSnapshot(
      sessionId: s.sessionId,
      connection: s.connection,
      lastSeq: s.lastSeq,
      protocolVersion: s.protocolVersion,
      orchestrators: s.orchestrators.map(
        (k, v) => MapEntry(
          k,
          RuntimeOrchestrator(
            id: v.id,
            name: v.name,
            isActive: v.isActive,
            orchestrationIds: v.orchestrationIds,
          ),
        ),
      ),
      orchestrations: s.orchestrations.map(
        (k, v) => MapEntry(
          k,
          RuntimeOrchestration(
            id: v.id,
            name: v.name,
            orchestratorId: v.orchestratorId,
            elementIds: v.entityIds,
            systemIds: v.systemIds,
          ),
        ),
      ),
      elements: s.entities.map(
        (k, v) => MapEntry(k, _projectElement(v)),
      ),
      systems: s.systems.map(
        (k, v) => MapEntry(k, _projectSystem(v)),
      ),
      logs: _projectLogs(s.logs),
      firings: s.firings,
      droppedFirings: s.stats.droppedFirings,
      gapsDetected: s.stats.gapsDetected,
      batchesReceived: s.stats.batchesReceived,
    );
  }

  static RuntimeElement _projectElement(EntityNode v) {
    return RuntimeElement(
      id: v.id,
      name: v.name,
      kind: v.kind,
      typeName: v.typeName,
      orchestrationId: v.orchestrationId,
      value: v.value,
      previous: v.previous,
      updatedAtMicros: v.updatedAtMicros,
      updateCount: v.updateCount,
    );
  }

  static RuntimeSystem _projectSystem(SystemNode v) {
    return RuntimeSystem(
      id: v.id,
      name: v.name,
      kind: v.kind,
      orchestrationId: v.orchestrationId,
      reactsToElementIds: v.reactsToEntityIds,
      interactsWithElementIds: v.interactsWithEntityIds,
      firingCount: v.firingCount,
      lastFiredAtMicros: v.lastFiredAtMicros,
      lastDurationMicros: v.lastDurationMicros,
      errorCount: v.errorCount,
    );
  }

  static RingBuffer<RuntimeLog> _projectLogs(RingBuffer<LogEntry> logs) {
    var result = RingBuffer<RuntimeLog>(kLogRingCapacity);
    for (final entry in logs.values) {
      result = result.push(RuntimeLog(
        id: entry.id,
        level: entry.level,
        tsMicros: entry.tsMicros,
        message: entry.message,
        orchestrationId: entry.orchestrationId,
        systemId: entry.systemId,
        elementRefs: entry.entityRefs,
        stack: entry.stack,
      ));
    }
    return result;
  }
}
