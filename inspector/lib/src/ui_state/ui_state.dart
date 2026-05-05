import 'filters.dart';

enum InspectorView { graph, entities, logs }

final class InspectorUiState {
  final InspectorView currentView;
  final String? selectedNodeId;
  final EntityFilter entityFilter;
  final LogFilter logFilter;
  final GraphFilter graphFilter;

  const InspectorUiState({
    this.currentView = InspectorView.graph,
    this.selectedNodeId,
    this.entityFilter = const EntityFilter(),
    this.logFilter = const LogFilter(),
    this.graphFilter = const GraphFilter(),
  });

  static const initial = InspectorUiState();

  InspectorUiState copyWith({
    InspectorView? currentView,
    String? selectedNodeId,
    bool clearSelectedNodeId = false,
    EntityFilter? entityFilter,
    LogFilter? logFilter,
    GraphFilter? graphFilter,
  }) {
    return InspectorUiState(
      currentView: currentView ?? this.currentView,
      selectedNodeId: clearSelectedNodeId ? null : (selectedNodeId ?? this.selectedNodeId),
      entityFilter: entityFilter ?? this.entityFilter,
      logFilter: logFilter ?? this.logFilter,
      graphFilter: graphFilter ?? this.graphFilter,
    );
  }
}
