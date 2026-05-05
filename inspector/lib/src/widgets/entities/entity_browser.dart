import 'package:flutter/material.dart';
import 'package:orchestra/inspector_export.dart';

import '../../domain/inspector_state.dart';
import '../../domain/nodes.dart';
import '../../selectors/filtered_entities_selector.dart';
import '../../store/inspector_store.dart';
import '../../store/ui_store.dart';
import '../../theme/tokens.dart';
import '../../ui_state/ui_state.dart';
import '../common/chip_row.dart';
import '../common/json_value_view.dart';
import '../common/search_field.dart';
import '../inspector_scope.dart';

class EntityBrowser extends StatelessWidget {
  const EntityBrowser({super.key});

  @override
  Widget build(BuildContext context) {
    final scope = InspectorScope.of(context);
    return ListenableBuilder(
      listenable: Listenable.merge([scope.store, scope.uiStore]),
      builder: (context, _) {
        final state = scope.store.value;
        final ui = scope.uiStore.value;
        final entities = filteredEntitiesSelector(state, ui.entityFilter);
        return Column(
          children: [
            _Toolbar(store: scope.store, uiStore: scope.uiStore, state: state, ui: ui),
            const Divider(height: 1),
            Expanded(
              child: entities.isEmpty
                  ? const _Empty()
                  : ListView.builder(
                      padding: const EdgeInsets.all(Tokens.spaceMd),
                      itemCount: entities.length,
                      itemBuilder: (context, i) => _EntityCard(
                        entity: entities[i],
                        selected: ui.selectedNodeId == entities[i].id,
                        onTap: () => scope.uiStore.selectNode(
                          ui.selectedNodeId == entities[i].id ? null : entities[i].id,
                        ),
                      ),
                    ),
            ),
          ],
        );
      },
    );
  }
}

class _Toolbar extends StatelessWidget {
  final InspectorStore store;
  final InspectorUiStore uiStore;
  final InspectorState state;
  final InspectorUiState ui;

  const _Toolbar({required this.store, required this.uiStore, required this.state, required this.ui});

  @override
  Widget build(BuildContext context) {
    final orchestrationOptions = state.orchestrations.values.map((o) => o.id).toList()..sort();
    return Padding(
      padding: const EdgeInsets.all(Tokens.spaceMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SearchField(
            hintText: 'Search elements…',
            onChanged: (q) => uiStore.setEntityFilter(ui.entityFilter.copyWith(searchQuery: q)),
          ),
          const SizedBox(height: Tokens.spaceMd),
          if (orchestrationOptions.isNotEmpty)
            SingleChipRow<String>(
              label: 'Orchestration',
              options: orchestrationOptions,
              selected: ui.entityFilter.orchestrationId,
              labelOf: (id) => state.orchestrations[id]?.name ?? id,
              onSelected: (id) => uiStore.setEntityFilter(
                id == null
                    ? ui.entityFilter.copyWith(clearOrchestration: true)
                    : ui.entityFilter.copyWith(orchestrationId: id),
              ),
            ),
          const SizedBox(height: Tokens.spaceSm),
          SingleChipRow<EntityKindDto>(
            label: 'Kind',
            options: EntityKindDto.values,
            selected: ui.entityFilter.kind,
            labelOf: (k) => switch (k) {
              EntityKindDto.component => 'Components',
              EntityKindDto.event => 'Events',
              EntityKindDto.dataEvent => 'Data Events',
              EntityKindDto.dependency => 'Dependencies',
            },
            onSelected: (k) => uiStore.setEntityFilter(
              k == null ? ui.entityFilter.copyWith(clearKind: true) : ui.entityFilter.copyWith(kind: k),
            ),
          ),
        ],
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text('No elements match', style: TextStyle(color: Tokens.textSecondary)),
    );
  }
}

class _EntityCard extends StatelessWidget {
  final EntityNode entity;
  final bool selected;
  final VoidCallback onTap;

  const _EntityCard({required this.entity, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = _colorOf(entity.kind);
    return Card(
      margin: const EdgeInsets.only(bottom: Tokens.spaceSm),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: selected ? Tokens.selectionBorder : Colors.transparent,
          width: selected ? 1.5 : 0,
        ),
      ),
      child: ExpansionTile(
        onExpansionChanged: (expanded) {
          if (expanded && !selected) onTap();
        },
        initiallyExpanded: selected,
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(_iconOf(entity.kind), color: color, size: 20),
        ),
        title: Text(entity.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        subtitle: Row(
          children: [
            _Badge(label: _kindLabel(entity.kind), color: color),
            const SizedBox(width: Tokens.spaceSm),
            _Badge(label: entity.typeName, color: Tokens.textSecondary),
            if (entity.updateCount > 0) ...[
              const SizedBox(width: Tokens.spaceSm),
              _Badge(label: '${entity.updateCount} updates', color: Tokens.textMuted),
            ],
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              Tokens.spaceLg,
              0,
              Tokens.spaceLg,
              Tokens.spaceLg,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Row(label: 'Identifier', child: SelectableText(entity.id, style: const TextStyle(fontFamily: Tokens.fontMono, fontSize: 12))),
                _Row(label: 'Value', child: JsonValueView(value: entity.value)),
                if (entity.previous != null)
                  _Row(label: 'Previous', child: JsonValueView(value: entity.previous)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static Color _colorOf(EntityKindDto k) => switch (k) {
        EntityKindDto.component => Tokens.component,
        EntityKindDto.event => Tokens.event,
        EntityKindDto.dataEvent => Tokens.dataEvent,
        EntityKindDto.dependency => Tokens.dependency,
      };

  static IconData _iconOf(EntityKindDto k) => switch (k) {
        EntityKindDto.component => Icons.inventory_2_outlined,
        EntityKindDto.event => Icons.bolt_outlined,
        EntityKindDto.dataEvent => Icons.data_object_outlined,
        EntityKindDto.dependency => Icons.link_outlined,
      };

  static String _kindLabel(EntityKindDto k) => switch (k) {
        EntityKindDto.component => 'Component',
        EntityKindDto.event => 'Event',
        EntityKindDto.dataEvent => 'Data Event',
        EntityKindDto.dependency => 'Dependency',
      };
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  const _Badge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w500),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final String label;
  final Widget child;
  const _Row({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Tokens.spaceSm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 96,
            child: Text(label, style: const TextStyle(color: Tokens.textSecondary, fontSize: 12)),
          ),
          Expanded(child: child),
        ],
      ),
    );
  }
}
