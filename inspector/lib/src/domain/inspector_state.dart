import 'connection_state.dart';
import 'log_entry.dart';
import 'nodes.dart';
import 'ring_buffer.dart';
import 'stats.dart';
import 'system_firing.dart';

const int kLogRingCapacity = 5000;
const int kFiringRingCapacity = 5000;

final class InspectorState {
  final String? sessionId;
  final InspectorConnectionState connection;
  final int? lastSeq;
  final int protocolVersion;

  final Map<String, OrchestratorNode> orchestrators;
  final Map<String, OrchestrationNode> orchestrations;
  final Map<String, EntityNode> entities;
  final Map<String, SystemNode> systems;

  final RingBuffer<LogEntry> logs;
  final RingBuffer<SystemFiring> firings;

  final InspectorStats stats;

  const InspectorState({
    required this.sessionId,
    required this.connection,
    required this.lastSeq,
    required this.protocolVersion,
    required this.orchestrators,
    required this.orchestrations,
    required this.entities,
    required this.systems,
    required this.logs,
    required this.firings,
    required this.stats,
  });

  static final InspectorState initial = InspectorState(
    sessionId: null,
    connection: const Disconnected(),
    lastSeq: null,
    protocolVersion: 0,
    orchestrators: const {},
    orchestrations: const {},
    entities: const {},
    systems: const {},
    logs: RingBuffer<LogEntry>(kLogRingCapacity),
    firings: RingBuffer<SystemFiring>(kFiringRingCapacity),
    stats: InspectorStats.empty,
  );

  InspectorState copyWith({
    String? sessionId,
    bool clearSessionId = false,
    InspectorConnectionState? connection,
    int? lastSeq,
    bool clearLastSeq = false,
    int? protocolVersion,
    Map<String, OrchestratorNode>? orchestrators,
    Map<String, OrchestrationNode>? orchestrations,
    Map<String, EntityNode>? entities,
    Map<String, SystemNode>? systems,
    RingBuffer<LogEntry>? logs,
    RingBuffer<SystemFiring>? firings,
    InspectorStats? stats,
  }) {
    return InspectorState(
      sessionId: clearSessionId ? null : (sessionId ?? this.sessionId),
      connection: connection ?? this.connection,
      lastSeq: clearLastSeq ? null : (lastSeq ?? this.lastSeq),
      protocolVersion: protocolVersion ?? this.protocolVersion,
      orchestrators: orchestrators ?? this.orchestrators,
      orchestrations: orchestrations ?? this.orchestrations,
      entities: entities ?? this.entities,
      systems: systems ?? this.systems,
      logs: logs ?? this.logs,
      firings: firings ?? this.firings,
      stats: stats ?? this.stats,
    );
  }
}
