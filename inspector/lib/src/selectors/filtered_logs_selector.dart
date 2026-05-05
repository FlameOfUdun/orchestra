import '../domain/inspector_state.dart';
import '../domain/log_entry.dart';
import '../domain/ring_buffer.dart';
import '../ui_state/filters.dart';

class _Cache {
  RingBuffer<LogEntry>? logsKey;
  LogFilter? filterKey;
  String? selectedNodeIdKey;
  List<LogEntry>? value;
}

final _cache = _Cache();

List<LogEntry> filteredLogsSelector(
  InspectorState state,
  LogFilter filter, {
  String? selectedNodeId,
}) {
  final c = _cache;
  if (identical(c.logsKey, state.logs) &&
      c.filterKey == filter &&
      c.selectedNodeIdKey == selectedNodeId &&
      c.value != null) {
    return c.value!;
  }
  Iterable<LogEntry> filtered = state.logs.values.where(filter.matches);
  if (filter.onlySelectedNodeContext && selectedNodeId != null) {
    filtered = filtered.where((log) =>
        log.systemId == selectedNodeId || log.entityRefs.contains(selectedNodeId));
  }
  final list = filtered.toList()..sort((a, b) => b.tsMicros.compareTo(a.tsMicros));
  c.logsKey = state.logs;
  c.filterKey = filter;
  c.selectedNodeIdKey = selectedNodeId;
  c.value = List.unmodifiable(list);
  return c.value!;
}
