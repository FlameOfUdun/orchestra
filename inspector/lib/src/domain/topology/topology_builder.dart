import 'package:orchestra/inspector_export.dart';

import '../snapshot/runtime_element.dart';
import '../snapshot/runtime_system.dart';
import 'topology_graph.dart';
import 'topology_node.dart';

/// Builds a [TopologyGraph] from a set of runtime elements and systems.
/// This is a pure function with no side-effects or UI dependencies.
TopologyGraph buildTopology({
  required Map<String, RuntimeElement> elements,
  required Map<String, RuntimeSystem> systems,
}) {
  final nodes = <TopologyNode>[];
  final edges = <TopologyEdge>[];
  final nodesById = <String, TopologyNode>{};

  void add(TopologyNode node) {
    nodes.add(node);
    nodesById[node.id] = node;
  }

  for (final lid in TopologyGraph.lifecycleIds) {
    add(TopologyNode(
      id: lid,
      name: lid.split('.').last,
      kind: TopologyNodeKind.lifecycle,
    ));
  }

  for (final element in elements.values) {
    add(TopologyNode(
      id: element.id,
      name: element.name,
      kind: switch (element.kind) {
        EntityKindDto.component => TopologyNodeKind.component,
        EntityKindDto.event => TopologyNodeKind.event,
        EntityKindDto.dataEvent => TopologyNodeKind.dataEvent,
        EntityKindDto.dependency => TopologyNodeKind.dependency,
      },
      orchestrationId: element.orchestrationId,
      subtitle: element.typeName,
    ));
  }

  for (final system in systems.values) {
    add(TopologyNode(
      id: system.id,
      name: system.name,
      kind: TopologyNodeKind.system,
      orchestrationId: system.orchestrationId,
      subtitle: system.kind.name,
    ));

    final lifecycleId = _lifecycleIdFor(system.kind);
    if (lifecycleId != null) {
      edges.add(TopologyEdge(
        sourceId: lifecycleId,
        destinationId: system.id,
        kind: TopologyEdgeKind.lifecycleEntry,
      ));
    }

    for (final eid in system.reactsToElementIds) {
      if (nodesById.containsKey(eid)) {
        edges.add(TopologyEdge(
          sourceId: eid,
          destinationId: system.id,
          kind: TopologyEdgeKind.reactsTo,
        ));
      }
    }

    for (final eid in system.interactsWithElementIds) {
      if (nodesById.containsKey(eid)) {
        edges.add(TopologyEdge(
          sourceId: system.id,
          destinationId: eid,
          kind: TopologyEdgeKind.interactsWith,
        ));
      }
    }
  }

  final outgoing = <String, List<TopologyEdge>>{};
  final incoming = <String, List<TopologyEdge>>{};
  for (final edge in edges) {
    (outgoing[edge.sourceId] ??= <TopologyEdge>[]).add(edge);
    (incoming[edge.destinationId] ??= <TopologyEdge>[]).add(edge);
  }

  return TopologyGraph(
    nodes: List.unmodifiable(nodes),
    edges: List.unmodifiable(edges),
    nodesById: Map.unmodifiable(nodesById),
    outgoingEdges: Map.unmodifiable(outgoing.map((k, v) => MapEntry(k, List.unmodifiable(v)))),
    incomingEdges: Map.unmodifiable(incoming.map((k, v) => MapEntry(k, List.unmodifiable(v)))),
  );
}

String? _lifecycleIdFor(SystemKindDto kind) {
  return switch (kind) {
    SystemKindDto.initialize => 'lifecycle.initialize',
    SystemKindDto.execute => 'lifecycle.execute',
    SystemKindDto.cleanup => 'lifecycle.cleanup',
    SystemKindDto.teardown => 'lifecycle.teardown',
    SystemKindDto.reactive => null,
  };
}
