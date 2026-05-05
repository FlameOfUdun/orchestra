import 'package:flutter/material.dart';

import '../application/controllers/inspector_controller.dart';
import '../domain/connection_state.dart';
import '../store/ui_store.dart';
import '../theme/tokens.dart';
import '../ui_state/ui_state.dart';
import '../widgets/connection_banner.dart';
import '../widgets/entities/entity_browser.dart';
import '../widgets/graph/graph_view.dart';
import '../widgets/inspector_scope.dart';
import '../widgets/logs/log_viewer.dart';

/// Persistent inspection workspace shell.
///
/// Wires [InspectorController] and [InspectorUiStore] into [InspectorScope]
/// so that all child widgets can reach the data they need.
class InspectorShell extends StatelessWidget {
  final InspectorController controller;
  final InspectorUiStore uiStore;

  const InspectorShell({
    super.key,
    required this.controller,
    required this.uiStore,
  });

  @override
  Widget build(BuildContext context) {
    return InspectorScope(
      controller: controller,
      uiStore: uiStore,
      child: ListenableBuilder(
        listenable: Listenable.merge([controller, uiStore]),
        builder: (context, _) {
          final snapshot = controller.value;
          final ui = uiStore.value;
          return Scaffold(
            backgroundColor: Tokens.surface,
            body: Column(
              children: [
                ConnectionBanner(
                  state: snapshot.connection,
                  onRetry: _shouldOfferRetry(snapshot.connection)
                      ? controller.resync
                      : null,
                ),
                _TabBar(ui: ui, uiStore: uiStore, snapshot: snapshot),
                const Divider(height: 1),
                Expanded(child: _buildView(ui.currentView)),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildView(InspectorView view) {
    return switch (view) {
      InspectorView.graph => const GraphView(),
      InspectorView.entities => const EntityBrowser(),
      InspectorView.logs => const LogViewer(),
    };
  }

  static bool _shouldOfferRetry(InspectorConnectionState state) {
    return state is Errored || state is Stale || state is Disconnected;
  }
}

class _TabBar extends StatelessWidget {
  final InspectorUiState ui;
  final InspectorUiStore uiStore;
  final dynamic snapshot;

  const _TabBar({
    required this.ui,
    required this.uiStore,
    required this.snapshot,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      color: Tokens.card,
      padding: const EdgeInsets.symmetric(horizontal: Tokens.spaceLg),
      child: Row(
        children: [
          _Tab(
            icon: Icons.account_tree_outlined,
            label: 'Topology',
            selected: ui.currentView == InspectorView.graph,
            onTap: () => uiStore.setView(InspectorView.graph),
          ),
          _Tab(
            icon: Icons.inventory_2_outlined,
            label: 'Explorer',
            selected: ui.currentView == InspectorView.entities,
            onTap: () => uiStore.setView(InspectorView.entities),
          ),
          _Tab(
            icon: Icons.article_outlined,
            label: 'Activity',
            selected: ui.currentView == InspectorView.logs,
            onTap: () => uiStore.setView(InspectorView.logs),
          ),
        ],
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _Tab({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? Tokens.system : Tokens.textSecondary;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: Tokens.spaceMd, vertical: Tokens.spaceSm),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: selected ? Tokens.system : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: Tokens.spaceSm),
            Text(label, style: TextStyle(color: color, fontSize: 13)),
          ],
        ),
      ),
    );
  }
}
