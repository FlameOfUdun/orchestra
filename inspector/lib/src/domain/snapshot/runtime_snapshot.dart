import '../connection_state.dart';
import '../ring_buffer.dart';
import '../system_firing.dart';
import 'runtime_element.dart';
import 'runtime_log.dart';
import 'runtime_orchestration.dart';
import 'runtime_orchestrator.dart';
import 'runtime_system.dart';

const int kLogRingCapacity = 5000;
const int kFiringRingCapacity = 5000;

/// Normalized view of the current runtime state received from the DevTools
/// extension. This is the source of truth for all presentation layers.
final class RuntimeSnapshot {
  final String? sessionId;
  final InspectorConnectionState connection;
  final int? lastSeq;
  final int protocolVersion;

  final Map<String, RuntimeOrchestrator> orchestrators;
  final Map<String, RuntimeOrchestration> orchestrations;
  final Map<String, RuntimeElement> elements;
  final Map<String, RuntimeSystem> systems;

  final RingBuffer<RuntimeLog> logs;
  final RingBuffer<SystemFiring> firings;

  final int droppedFirings;
  final int gapsDetected;
  final int batchesReceived;

  const RuntimeSnapshot({
    required this.sessionId,
    required this.connection,
    required this.lastSeq,
    required this.protocolVersion,
    required this.orchestrators,
    required this.orchestrations,
    required this.elements,
    required this.systems,
    required this.logs,
    required this.firings,
    this.droppedFirings = 0,
    this.gapsDetected = 0,
    this.batchesReceived = 0,
  });

  static final RuntimeSnapshot initial = RuntimeSnapshot(
    sessionId: null,
    connection: const Disconnected(),
    lastSeq: null,
    protocolVersion: 0,
    orchestrators: const {},
    orchestrations: const {},
    elements: const {},
    systems: const {},
    logs: RingBuffer<RuntimeLog>(kLogRingCapacity),
    firings: RingBuffer<SystemFiring>(kFiringRingCapacity),
  );

  RuntimeSnapshot copyWith({
    String? sessionId,
    bool clearSessionId = false,
    InspectorConnectionState? connection,
    int? lastSeq,
    bool clearLastSeq = false,
    int? protocolVersion,
    Map<String, RuntimeOrchestrator>? orchestrators,
    Map<String, RuntimeOrchestration>? orchestrations,
    Map<String, RuntimeElement>? elements,
    Map<String, RuntimeSystem>? systems,
    RingBuffer<RuntimeLog>? logs,
    RingBuffer<SystemFiring>? firings,
    int? droppedFirings,
    int? gapsDetected,
    int? batchesReceived,
  }) {
    return RuntimeSnapshot(
      sessionId: clearSessionId ? null : (sessionId ?? this.sessionId),
      connection: connection ?? this.connection,
      lastSeq: clearLastSeq ? null : (lastSeq ?? this.lastSeq),
      protocolVersion: protocolVersion ?? this.protocolVersion,
      orchestrators: orchestrators ?? this.orchestrators,
      orchestrations: orchestrations ?? this.orchestrations,
      elements: elements ?? this.elements,
      systems: systems ?? this.systems,
      logs: logs ?? this.logs,
      firings: firings ?? this.firings,
      droppedFirings: droppedFirings ?? this.droppedFirings,
      gapsDetected: gapsDetected ?? this.gapsDetected,
      batchesReceived: batchesReceived ?? this.batchesReceived,
    );
  }
}
