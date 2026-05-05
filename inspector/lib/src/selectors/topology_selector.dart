import 'package:orchestra/inspector_export.dart';

import '../domain/inspector_state.dart';
import '../domain/snapshot/runtime_element.dart';
import '../domain/snapshot/runtime_system.dart';
import '../domain/topology/topology_builder.dart';
import '../domain/topology/topology_graph.dart';
import '../ui_state/filters.dart';

// Re-export topology types so existing import sites don't need updating.
export '../domain/topology/topology_builder.dart';
export '../domain/topology/topology_graph.dart';
export '../domain/topology/topology_node.dart';

class _TopologyCache {
  Map<String, dynamic>? entitiesKey;
  Map<String, dynamic>? systemsKey;
  TopologyGraph? value;
}

final _topologyCache = _TopologyCache();

/// Memoized selector: builds a [TopologyGraph] from [InspectorState].
///
/// Delegates to [buildTopology] in the domain layer; the selector layer only
/// handles the caching and the bridge from old [InspectorState] to new domain
/// types during the migration.
TopologyGraph topologySelector(InspectorState state) {
  final cache = _topologyCache;
  if (identical(cache.entitiesKey, state.entities) &&
      identical(cache.systemsKey, state.systems) &&
      cache.value != null) {
    return cache.value!;
  }

  final elements = state.entities.map(
    (k, v) => MapEntry(
      k,
      RuntimeElement(
        id: v.id,
        name: v.name,
        kind: v.kind,
        typeName: v.typeName,
        orchestrationId: v.orchestrationId,
        value: v.value,
        previous: v.previous,
        updatedAtMicros: v.updatedAtMicros,
        updateCount: v.updateCount,
      ),
    ),
  );

  final systems = state.systems.map(
    (k, v) => MapEntry(
      k,
      RuntimeSystem(
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
      ),
    ),
  );

  final graph = buildTopology(elements: elements, systems: systems);
  cache.entitiesKey = state.entities;
  cache.systemsKey = state.systems;
  cache.value = graph;
  return graph;
}

// ---------------------------------------------------------------------------
// Filtered topology selector
// ---------------------------------------------------------------------------

class _FilteredTopologyCache {
  Map<String, dynamic>? entitiesKey;
  Map<String, dynamic>? systemsKey;
  GraphFilter? filterKey;
  TopologyGraph? value;
}

final _filteredTopologyCache = _FilteredTopologyCache();

/// Memoized selector: builds a [TopologyGraph] with [GraphFilter] applied.
///
/// Filters elements and systems before passing them to [buildTopology] so the
/// graph only contains visible nodes from the start, rather than post-hoc
/// dimming or skipping inside the widget tree.
TopologyGraph filteredTopologySelector(InspectorState state, GraphFilter filter) {
  final cache = _filteredTopologyCache;
  if (identical(cache.entitiesKey, state.entities) &&
      identical(cache.systemsKey, state.systems) &&
      cache.filterKey == filter &&
      cache.value != null) {
    return cache.value!;
  }

  final orchIds = filter.selectedOrchestrationIds;

  final elements = <String, RuntimeElement>{};
  for (final entry in state.entities.entries) {
    final v = entry.value;
    final kindVisible = switch (v.kind) {
      EntityKindDto.component || EntityKindDto.dependency => filter.showComponents,
      EntityKindDto.event || EntityKindDto.dataEvent => filter.showEvents,
    };
    if (!kindVisible) continue;
    if (orchIds.isNotEmpty && !orchIds.contains(v.orchestrationId)) continue;
    elements[entry.key] = RuntimeElement(
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

  final systems = <String, RuntimeSystem>{};
  if (filter.showSystems) {
    for (final entry in state.systems.entries) {
      final v = entry.value;
      if (orchIds.isNotEmpty && !orchIds.contains(v.orchestrationId)) continue;
      systems[entry.key] = RuntimeSystem(
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
  }

  final graph = buildTopology(
    elements: elements,
    systems: systems,
  );
  cache.entitiesKey = state.entities;
  cache.systemsKey = state.systems;
  cache.filterKey = filter;
  cache.value = graph;
  return graph;
}
