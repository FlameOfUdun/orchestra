import '../domain/inspector_state.dart';
import '../domain/log_entry.dart';
import '../domain/ring_buffer.dart';

class _Cache {
  RingBuffer<LogEntry>? logsKey;
  String? selectedNodeIdKey;
  Set<String>? value;
}

final _cache = _Cache();

/// O(1) membership index of log ids structurally related to [selectedNodeId].
///
/// Structural match only: log.systemId or log.entityRefs reference the node id.
/// No substring scraping of message content.
Set<String> relatedLogIdsSelector(InspectorState state, String? selectedNodeId) {
  final c = _cache;
  if (identical(c.logsKey, state.logs) && c.selectedNodeIdKey == selectedNodeId && c.value != null) {
    return c.value!;
  }
  if (selectedNodeId == null) {
    c.logsKey = state.logs;
    c.selectedNodeIdKey = null;
    c.value = const <String>{};
    return c.value!;
  }
  final out = <String>{};
  for (final log in state.logs.values) {
    if (log.systemId == selectedNodeId || log.entityRefs.contains(selectedNodeId)) {
      out.add(log.id);
    }
  }
  c.logsKey = state.logs;
  c.selectedNodeIdKey = selectedNodeId;
  c.value = Set.unmodifiable(out);
  return c.value!;
}
