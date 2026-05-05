import 'package:flutter/material.dart';
import 'package:orchestra/inspector_export.dart';

import '../../selectors/filtered_logs_selector.dart';
import '../../selectors/related_log_ids_selector.dart';
import '../../theme/tokens.dart';
import '../common/chip_row.dart';
import '../common/search_field.dart';
import '../inspector_scope.dart';
import 'log_row.dart';

class LogViewer extends StatelessWidget {
  const LogViewer({super.key});

  @override
  Widget build(BuildContext context) {
    final scope = InspectorScope.of(context);
    return ListenableBuilder(
      listenable: Listenable.merge([scope.store, scope.uiStore]),
      builder: (context, _) {
        final state = scope.store.value;
        final ui = scope.uiStore.value;
        final logs = filteredLogsSelector(state, ui.logFilter, selectedNodeId: ui.selectedNodeId);
        final relatedIds = relatedLogIdsSelector(state, ui.selectedNodeId);
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(Tokens.spaceMd),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: SearchField(
                          hintText: 'Search logs…',
                          onChanged: (q) => scope.uiStore.setLogFilter(
                            ui.logFilter.copyWith(searchQuery: q),
                          ),
                        ),
                      ),
                      const SizedBox(width: Tokens.spaceMd),
                      OutlinedButton.icon(
                        onPressed: () => scope.uiStore.setLogFilter(
                          ui.logFilter.copyWith(
                            clearedBeforeMicros: DateTime.now().microsecondsSinceEpoch,
                          ),
                        ),
                        icon: const Icon(Icons.clear_all, size: 18),
                        label: const Text('Clear'),
                        style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact),
                      ),
                    ],
                  ),
                  const SizedBox(height: Tokens.spaceMd),
                  MultiChipRow<LogLevelDto>(
                    label: 'Level',
                    options: LogLevelDto.values,
                    selected: ui.logFilter.levels,
                    labelOf: (l) => l.name.toUpperCase(),
                    onChanged: (set) => scope.uiStore.setLogFilter(ui.logFilter.copyWith(levels: set)),
                  ),
                  if (ui.selectedNodeId != null) ...[
                    const SizedBox(height: Tokens.spaceSm),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Selection: ${ui.selectedNodeId} (${relatedIds.length} related)',
                            style: const TextStyle(color: Tokens.textSecondary, fontSize: 12),
                          ),
                        ),
                        FilterChip(
                          label: const Text('Related Only'),
                          selected: ui.logFilter.onlySelectedNodeContext,
                          onSelected: (sel) => scope.uiStore.setLogFilter(
                            ui.logFilter.copyWith(onlySelectedNodeContext: sel),
                          ),
                          visualDensity: VisualDensity.compact,
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: logs.isEmpty
                  ? const Center(
                      child: Text('No logs', style: TextStyle(color: Tokens.textSecondary)),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(Tokens.spaceMd),
                      itemCount: logs.length,
                      itemBuilder: (context, i) {
                        final log = logs[i];
                        return LogRow(
                          log: log,
                          related: relatedIds.contains(log.id),
                          onSystemTap: log.systemId == null
                              ? null
                              : () => scope.uiStore.selectNode(log.systemId),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}
