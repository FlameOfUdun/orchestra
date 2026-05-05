import '../domain/inspector_state.dart';
import '../domain/nodes.dart';
import '../ui_state/filters.dart';

class _Cache {
  Map<String, EntityNode>? entitiesKey;
  EntityFilter? filterKey;
  List<EntityNode>? value;
}

final _cache = _Cache();

List<EntityNode> filteredEntitiesSelector(InspectorState state, EntityFilter filter) {
  final c = _cache;
  if (identical(c.entitiesKey, state.entities) && c.filterKey == filter && c.value != null) {
    return c.value!;
  }
  final result = state.entities.values.where(filter.matches).toList()
    ..sort((a, b) => a.name.compareTo(b.name));
  c.entitiesKey = state.entities;
  c.filterKey = filter;
  c.value = List.unmodifiable(result);
  return c.value!;
}
