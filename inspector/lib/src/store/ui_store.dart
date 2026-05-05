import 'package:flutter/foundation.dart';

import '../ui_state/filters.dart';
import '../ui_state/ui_state.dart';

final class InspectorUiStore extends ChangeNotifier implements ValueListenable<InspectorUiState> {
  InspectorUiState _state = InspectorUiState.initial;

  @override
  InspectorUiState get value => _state;

  void _set(InspectorUiState next) {
    if (identical(next, _state)) return;
    _state = next;
    notifyListeners();
  }

  void setView(InspectorView view) {
    if (_state.currentView == view) return;
    _set(_state.copyWith(currentView: view));
  }

  void selectNode(String? nodeId) {
    if (_state.selectedNodeId == nodeId) return;
    _set(_state.copyWith(
      selectedNodeId: nodeId,
      clearSelectedNodeId: nodeId == null,
    ));
  }

  void setEntityFilter(EntityFilter filter) {
    _set(_state.copyWith(entityFilter: filter));
  }

  void setLogFilter(LogFilter filter) {
    _set(_state.copyWith(logFilter: filter));
  }

  void setGraphFilter(GraphFilter filter) {
    _set(_state.copyWith(graphFilter: filter));
  }
}
