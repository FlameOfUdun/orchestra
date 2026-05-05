import 'package:flutter/material.dart';

import '../../selectors/related_log_ids_selector.dart';
import '../../selectors/topology_selector.dart';
import '../../theme/tokens.dart';
import '../../ui_state/ui_state.dart';
import '../common/json_value_view.dart';
import '../inspector_scope.dart';

class SelectionPanel extends StatelessWidget {
  const SelectionPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final scope = InspectorScope.of(context);
    return ListenableBuilder(
      listenable: Listenable.merge([scope.store, scope.uiStore]),
      builder: (context, _) {
        final state = scope.store.value;
        final ui = scope.uiStore.value;
        final id = ui.selectedNodeId;
        if (id == null) return const SizedBox.shrink();

        final topology = topologySelector(state);
        final node = topology.nodesById[id];
        if (node == null) return const SizedBox.shrink();

        final outgoing = topology.outgoingEdges[id] ?? const [];
        final incoming = topology.incomingEdges[id] ?? const [];
        final cascade = topology.cascadeFrom(id);
        final relatedLogs = relatedLogIdsSelector(state, id);
        final entity = state.entities[id];

        return Container(
          color: Tokens.card,
          padding: const EdgeInsets.all(Tokens.spaceLg),
          child: ListView(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text('Selection', style: Theme.of(context).textTheme.titleMedium),
                  ),
                  IconButton(
                    onPressed: () => scope.uiStore.selectNode(null),
                    icon: const Icon(Icons.close, size: 18),
                    tooltip: 'Clear selection',
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
              const SizedBox(height: Tokens.spaceMd),
              _Section(title: node.name, children: [
                _Line(label: 'Identifier', child: SelectableText(node.id, style: const TextStyle(fontFamily: Tokens.fontMono, fontSize: 12))),
                _Line(label: 'Kind', child: Text(node.kind.name)),
                if (node.orchestrationId != null)
                  _Line(label: 'Orchestration', child: Text(node.orchestrationId!)),
                if (node.subtitle != null) _Line(label: 'Subtype', child: Text(node.subtitle!)),
                if (entity != null) _Line(label: 'Value', child: JsonValueView(value: entity.value)),
                if (entity?.previous != null)
                  _Line(label: 'Previous', child: JsonValueView(value: entity!.previous)),
              ]),
              const SizedBox(height: Tokens.spaceLg),
              Wrap(
                spacing: Tokens.spaceSm,
                runSpacing: Tokens.spaceSm,
                children: [
                  OutlinedButton.icon(
                    onPressed: ui.currentView == InspectorView.graph
                        ? null
                        : () => scope.uiStore.setView(InspectorView.graph),
                    icon: const Icon(Icons.account_tree_outlined, size: 16),
                    label: const Text('Open in Graph'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => scope.uiStore.setView(InspectorView.entities),
                    icon: const Icon(Icons.inventory_2_outlined, size: 16),
                    label: const Text('Open in Elements'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () {
                      scope.uiStore.setView(InspectorView.logs);
                      scope.uiStore.setLogFilter(ui.logFilter.copyWith(onlySelectedNodeContext: true));
                    },
                    icon: const Icon(Icons.article_outlined, size: 16),
                    label: const Text('Show Related Logs'),
                  ),
                ],
              ),
              const SizedBox(height: Tokens.spaceLg),
              _Section(title: 'Connections', children: [
                _Line(label: 'Cascade', child: Text('${cascade.length} nodes')),
                _Line(label: 'Outgoing', child: Text('${outgoing.length}')),
                _Line(label: 'Incoming', child: Text('${incoming.length}')),
                _Line(label: 'Related logs', child: Text('${relatedLogs.length}')),
              ]),
              if (outgoing.isNotEmpty) ...[
                const SizedBox(height: Tokens.spaceLg),
                _Section(
                  title: 'Downstream',
                  children: outgoing.take(8).map((edge) {
                    final dest = topology.nodesById[edge.destinationId];
                    if (dest == null) return const SizedBox.shrink();
                    return _LinkRow(
                      label: edge.kind.name,
                      name: dest.name,
                      subtitle: dest.kind.name,
                      onTap: () => scope.uiStore.selectNode(dest.id),
                    );
                  }).toList(),
                ),
              ],
              if (incoming.isNotEmpty) ...[
                const SizedBox(height: Tokens.spaceLg),
                _Section(
                  title: 'Upstream',
                  children: incoming.take(8).map((edge) {
                    final src = topology.nodesById[edge.sourceId];
                    if (src == null) return const SizedBox.shrink();
                    return _LinkRow(
                      label: edge.kind.name,
                      name: src.name,
                      subtitle: src.kind.name,
                      onTap: () => scope.uiStore.selectNode(src.id),
                    );
                  }).toList(),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _Section({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        const SizedBox(height: Tokens.spaceSm),
        ...children,
      ],
    );
  }
}

class _Line extends StatelessWidget {
  final String label;
  final Widget child;
  const _Line({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Tokens.spaceSm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Tokens.textMuted, fontSize: 11)),
          const SizedBox(height: 2),
          child,
        ],
      ),
    );
  }
}

class _LinkRow extends StatelessWidget {
  final String label;
  final String name;
  final String subtitle;
  final VoidCallback onTap;

  const _LinkRow({
    required this.label,
    required this.name,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Tokens.spaceSm, vertical: Tokens.spaceXs),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 96,
              child: Text(label, style: const TextStyle(color: Tokens.textMuted, fontSize: 11)),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  Text(subtitle, style: const TextStyle(color: Tokens.textSecondary, fontSize: 11)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, size: 12, color: Tokens.textMuted),
          ],
        ),
      ),
    );
  }
}
