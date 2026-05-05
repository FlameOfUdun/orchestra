import 'topology_node.dart';

enum TopologyEdgeKind {
  reactsTo,
  interactsWith,
  lifecycleEntry,
}

final class TopologyEdge {
  final String sourceId;
  final String destinationId;
  final TopologyEdgeKind kind;

  const TopologyEdge({
    required this.sourceId,
    required this.destinationId,
    required this.kind,
  });
}

final class TopologyGraph {
  final List<TopologyNode> nodes;
  final List<TopologyEdge> edges;
  final Map<String, TopologyNode> nodesById;
  final Map<String, List<TopologyEdge>> outgoingEdges;
  final Map<String, List<TopologyEdge>> incomingEdges;

  const TopologyGraph({
    required this.nodes,
    required this.edges,
    required this.nodesById,
    required this.outgoingEdges,
    required this.incomingEdges,
  });

  static const lifecycleIds = <String>[
    'lifecycle.initialize',
    'lifecycle.execute',
    'lifecycle.cleanup',
    'lifecycle.teardown',
  ];

  bool containsNode(String id) => nodesById.containsKey(id);

  Set<String> cascadeFrom(String? nodeId) {
    if (nodeId == null || !nodesById.containsKey(nodeId)) return const {};
    final visited = <String>{};
    void visit(String id) {
      if (!visited.add(id)) return;
      for (final edge in outgoingEdges[id] ?? const <TopologyEdge>[]) {
        visit(edge.destinationId);
      }
    }
    visit(nodeId);
    return visited;
  }
}
