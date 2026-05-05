import 'package:flutter/material.dart';
import 'package:graphview/GraphView.dart' as gv;

import '../../domain/inspector_state.dart';
import '../../selectors/topology_selector.dart';
import '../../store/inspector_store.dart';
import '../../store/ui_store.dart';
import '../../theme/tokens.dart';
import '../../ui_state/filters.dart';
import '../../ui_state/ui_state.dart';
import '../common/chip_row.dart';
import '../common/search_field.dart';
import '../inspector_scope.dart';

class GraphView extends StatefulWidget {
  const GraphView({super.key});

  @override
  State<GraphView> createState() => _GraphViewState();
}

class _GraphViewState extends State<GraphView> {
  gv.Graph _gvGraph = gv.Graph();
  final _config = gv.SugiyamaConfiguration()
    ..nodeSeparation = 50
    ..levelSeparation = 100
    ..orientation = gv.SugiyamaConfiguration.ORIENTATION_LEFT_RIGHT;
  final _transform = TransformationController();
  Map<String, TopologyEdgeKind> _edgeKinds = {};

  TopologyGraph? _builtFor;
  Set<String> _searchHits = const {};

  @override
  void dispose() {
    _transform.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scope = InspectorScope.of(context);
    return ListenableBuilder(
      listenable: Listenable.merge([scope.store, scope.uiStore]),
      builder: (context, _) {
        final state = scope.store.value;
        final ui = scope.uiStore.value;
        final topology = filteredTopologySelector(state, ui.graphFilter);

        if (!identical(topology, _builtFor)) {
          _rebuildGraph(topology);
          _builtFor = topology;
          _transform.value = Matrix4.identity();
        }

        return Column(
          children: [
            _Toolbar(
              state: state,
              ui: ui,
              uiStore: scope.uiStore,
              store: scope.store,
              onSearchChanged: (q) {
                _searchHits = q.isEmpty
                    ? const {}
                    : topology.nodes
                        .where((n) =>
                            n.name.toLowerCase().contains(q.toLowerCase()) ||
                            n.id.toLowerCase().contains(q.toLowerCase()))
                        .map((n) => n.id)
                        .toSet();
                setState(() {});
              },
              onZoom: (factor) {
                final m = _transform.value.clone();
                m.scaleByDouble(factor, factor, 1, 1);
                _transform.value = m;
              },
              onFit: () => _transform.value = Matrix4.identity(),
            ),
            const Divider(height: 1),
            Expanded(child: _buildGraphArea(topology, ui)),
            _Legend(),
          ],
        );
      },
    );
  }

  Widget _buildGraphArea(TopologyGraph topology, InspectorUiState ui) {
    if (_gvGraph.nodeCount() == 0) {
      return const Center(child: Text('No data', style: TextStyle(color: Tokens.textSecondary)));
    }
    final cascade = topology.cascadeFrom(ui.selectedNodeId);
    _applyEdgeStyling(cascade);

    return InteractiveViewer(
      constrained: false,
      boundaryMargin: const EdgeInsets.all(double.infinity),
      minScale: 0.1,
      maxScale: 5,
      transformationController: _transform,
      child: gv.GraphView(
        key: ObjectKey(_gvGraph),
        graph: _gvGraph,
        algorithm: gv.SugiyamaAlgorithm(_config),
        animated: false,
        paint: Paint()
          ..color = Tokens.edgeDefault
          ..strokeWidth = 1.5
          ..style = PaintingStyle.stroke,
        builder: (gvNode) => _buildNodeWidget(topology, ui, cascade, gvNode),
      ),
    );
  }

  Widget _buildNodeWidget(
    TopologyGraph topology,
    InspectorUiState ui,
    Set<String> cascade,
    gv.Node gvNode,
  ) {
    final id = gvNode.key?.value as String?;
    if (id == null) return const SizedBox.shrink();
    final node = topology.nodesById[id];
    if (node == null) return const SizedBox.shrink();

    final isSelected = ui.selectedNodeId == id;
    final inCascade = cascade.contains(id);
    final inSearch = _searchHits.isEmpty || _searchHits.contains(id);

    final color = _colorOf(node.kind);
    final body = Container(
      padding: const EdgeInsets.all(Tokens.spaceSm),
      decoration: BoxDecoration(
        color: inSearch ? color : Tokens.textMuted,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: inCascade ? Tokens.selected : Colors.grey.shade700,
          width: inCascade ? 3 : 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isSelected && node.orchestrationId != null)
            Text(node.orchestrationId!,
                style: const TextStyle(color: Colors.white70, fontSize: 10)),
          Text(node.name,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
          if (isSelected && node.subtitle != null)
            Text(node.subtitle!, style: const TextStyle(color: Colors.white70, fontSize: 10)),
        ],
      ),
    );

    return GestureDetector(
      onTap: () {
        final scope = InspectorScope.of(context);
        scope.uiStore.selectNode(isSelected ? null : id);
      },
      child: body,
    );
  }

  void _rebuildGraph(TopologyGraph topology) {
    final graph = gv.Graph();
    final nodes = <String, gv.Node>{};
    final edgeKinds = <String, TopologyEdgeKind>{};

    for (final n in topology.nodes) {
      final node = gv.Node.Id(n.id);
      graph.addNode(node);
      nodes[n.id] = node;
    }
    for (final e in topology.edges) {
      final src = nodes[e.sourceId];
      final dst = nodes[e.destinationId];
      if (src != null && dst != null) {
        graph.addEdge(src, dst);
        edgeKinds['${e.sourceId}->${e.destinationId}'] = e.kind;
      }
    }

    _gvGraph = graph;
    _edgeKinds = edgeKinds;
  }

  void _applyEdgeStyling(Set<String> cascade) {
    for (final edge in _gvGraph.edges) {
      final src = edge.source.key?.value as String?;
      final dst = edge.destination.key?.value as String?;
      final highlighted = src != null && dst != null && cascade.contains(src) && cascade.contains(dst);
      final kind = (src != null && dst != null) ? _edgeKinds['$src->$dst'] : null;
      edge.paint = Paint()
        ..color = highlighted ? Tokens.selected : _edgeColorFor(kind)
        ..strokeWidth = highlighted ? 3 : 1.5
        ..style = PaintingStyle.stroke;
    }
  }

  static Color _edgeColorFor(TopologyEdgeKind? kind) => switch (kind) {
        TopologyEdgeKind.reactsTo => Tokens.edgeReactsTo,
        TopologyEdgeKind.interactsWith => Tokens.edgeInteractsWith,
        TopologyEdgeKind.lifecycleEntry => Tokens.edgeLifecycle,
        null => Tokens.edgeDefault,
      };

  static Color _colorOf(TopologyNodeKind k) => switch (k) {
        TopologyNodeKind.component => Tokens.component,
        TopologyNodeKind.event => Tokens.event,
        TopologyNodeKind.dataEvent => Tokens.dataEvent,
        TopologyNodeKind.dependency => Tokens.dependency,
        TopologyNodeKind.system => Tokens.system,
        TopologyNodeKind.lifecycle => Tokens.lifecycle,
      };
}

class _Toolbar extends StatelessWidget {
  final InspectorState state;
  final InspectorUiState ui;
  final InspectorUiStore uiStore;
  final InspectorStore store;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<double> onZoom;
  final VoidCallback onFit;

  const _Toolbar({
    required this.state,
    required this.ui,
    required this.uiStore,
    required this.store,
    required this.onSearchChanged,
    required this.onZoom,
    required this.onFit,
  });

  @override
  Widget build(BuildContext context) {
    final orchestrationIds = state.orchestrations.values.map((o) => o.id).toList()..sort();
    return Padding(
      padding: const EdgeInsets.all(Tokens.spaceMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: SearchField(hintText: 'Filter nodes…', onChanged: onSearchChanged)),
              const SizedBox(width: Tokens.spaceMd),
              IconButton(onPressed: () => onZoom(1.2), icon: const Icon(Icons.zoom_in, size: 20)),
              IconButton(onPressed: onFit, icon: const Icon(Icons.fit_screen, size: 20)),
              IconButton(onPressed: () => onZoom(0.8), icon: const Icon(Icons.zoom_out, size: 20)),
            ],
          ),
          const SizedBox(height: Tokens.spaceMd),
          if (orchestrationIds.isNotEmpty)
            MultiChipRow<String>(
              label: 'Orchestrations',
              options: orchestrationIds,
              selected: ui.graphFilter.selectedOrchestrationIds,
              labelOf: (id) => state.orchestrations[id]?.name ?? id,
              onChanged: (sel) => uiStore.setGraphFilter(
                ui.graphFilter.copyWith(selectedOrchestrationIds: sel),
              ),
            ),
          const SizedBox(height: Tokens.spaceSm),
          MultiChipRow<_VisOpt>(
            label: 'Visible',
            options: _VisOpt.values,
            selected: _selectedVisibility(ui.graphFilter),
            labelOf: (o) => o.label,
            onChanged: (sel) => uiStore.setGraphFilter(ui.graphFilter.copyWith(
              showComponents: sel.contains(_VisOpt.components),
              showEvents: sel.contains(_VisOpt.events),
              showSystems: sel.contains(_VisOpt.systems),
            )),
          ),
        ],
      ),
    );
  }

  Set<_VisOpt> _selectedVisibility(GraphFilter f) {
    return {
      if (f.showComponents) _VisOpt.components,
      if (f.showEvents) _VisOpt.events,
      if (f.showSystems) _VisOpt.systems,
    };
  }
}

enum _VisOpt {
  components('Components'),
  events('Events'),
  systems('Systems');

  final String label;
  const _VisOpt(this.label);
}

class _Legend extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Tokens.spaceLg, vertical: Tokens.spaceMd),
      decoration: const BoxDecoration(
        color: Tokens.card,
        border: Border(top: BorderSide(color: Tokens.elevated)),
      ),
      child: Row(
        children: [
          _Swatch(color: Tokens.component, label: 'Component'),
          const SizedBox(width: Tokens.spaceLg),
          _Swatch(color: Tokens.event, label: 'Event'),
          const SizedBox(width: Tokens.spaceLg),
          _Swatch(color: Tokens.system, label: 'System'),
          const SizedBox(width: Tokens.spaceLg),
          _Swatch(color: Tokens.lifecycle, label: 'Lifecycle'),
          const SizedBox(width: Tokens.spaceLg),
          _Swatch(color: Tokens.dependency, label: 'Dependency'),
        ],
      ),
    );
  }
}

class _Swatch extends StatelessWidget {
  final Color color;
  final String label;
  const _Swatch({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4)),
        ),
        const SizedBox(width: Tokens.spaceSm),
        Text(label, style: const TextStyle(color: Tokens.textSecondary, fontSize: 12)),
      ],
    );
  }
}
