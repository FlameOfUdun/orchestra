import 'package:orchestra/inspector_export.dart';

import '../domain/log_entry.dart';
import '../domain/nodes.dart';

final class EntityFilter {
  final String searchQuery;
  final String? orchestrationId;
  final EntityKindDto? kind;

  const EntityFilter({
    this.searchQuery = '',
    this.orchestrationId,
    this.kind,
  });

  EntityFilter copyWith({
    String? searchQuery,
    String? orchestrationId,
    EntityKindDto? kind,
    bool clearOrchestration = false,
    bool clearKind = false,
  }) {
    return EntityFilter(
      searchQuery: searchQuery ?? this.searchQuery,
      orchestrationId: clearOrchestration ? null : (orchestrationId ?? this.orchestrationId),
      kind: clearKind ? null : (kind ?? this.kind),
    );
  }

  bool matches(EntityNode entity) {
    if (orchestrationId != null && entity.orchestrationId != orchestrationId) return false;
    if (kind != null && entity.kind != kind) return false;
    if (searchQuery.isNotEmpty) {
      final query = searchQuery.toLowerCase();
      if (!entity.name.toLowerCase().contains(query) &&
          !entity.id.toLowerCase().contains(query)) {
        return false;
      }
    }
    return true;
  }
}

final class LogFilter {
  final String searchQuery;
  final Set<LogLevelDto> levels;
  final String? orchestrationId;
  final int? clearedBeforeMicros;
  final bool onlySelectedNodeContext;

  const LogFilter({
    this.searchQuery = '',
    this.levels = const {},
    this.orchestrationId,
    this.clearedBeforeMicros,
    this.onlySelectedNodeContext = false,
  });

  LogFilter copyWith({
    String? searchQuery,
    Set<LogLevelDto>? levels,
    String? orchestrationId,
    int? clearedBeforeMicros,
    bool? onlySelectedNodeContext,
    bool clearOrchestration = false,
    bool clearClearedBefore = false,
  }) {
    return LogFilter(
      searchQuery: searchQuery ?? this.searchQuery,
      levels: levels ?? this.levels,
      orchestrationId: clearOrchestration ? null : (orchestrationId ?? this.orchestrationId),
      clearedBeforeMicros: clearClearedBefore ? null : (clearedBeforeMicros ?? this.clearedBeforeMicros),
      onlySelectedNodeContext: onlySelectedNodeContext ?? this.onlySelectedNodeContext,
    );
  }

  bool matches(LogEntry log) {
    final clearedBefore = clearedBeforeMicros;
    if (clearedBefore != null && log.tsMicros < clearedBefore) return false;
    if (orchestrationId != null && log.orchestrationId != orchestrationId) return false;
    if (levels.isNotEmpty && !levels.contains(log.level)) return false;
    if (searchQuery.isNotEmpty) {
      final query = searchQuery.toLowerCase();
      if (!log.message.toLowerCase().contains(query)) return false;
    }
    return true;
  }
}

final class GraphFilter {
  final String searchQuery;
  final Set<String> selectedOrchestrationIds;
  final bool showComponents;
  final bool showEvents;
  final bool showSystems;
  final bool showLifecycle;

  const GraphFilter({
    this.searchQuery = '',
    this.selectedOrchestrationIds = const {},
    this.showComponents = true,
    this.showEvents = true,
    this.showSystems = true,
    this.showLifecycle = true,
  });

  GraphFilter copyWith({
    String? searchQuery,
    Set<String>? selectedOrchestrationIds,
    bool? showComponents,
    bool? showEvents,
    bool? showSystems,
    bool? showLifecycle,
  }) {
    return GraphFilter(
      searchQuery: searchQuery ?? this.searchQuery,
      selectedOrchestrationIds: selectedOrchestrationIds ?? this.selectedOrchestrationIds,
      showComponents: showComponents ?? this.showComponents,
      showEvents: showEvents ?? this.showEvents,
      showSystems: showSystems ?? this.showSystems,
      showLifecycle: showLifecycle ?? this.showLifecycle,
    );
  }
}
