import 'package:flutter/material.dart';

import '../application/controllers/inspector_controller.dart';
import '../store/inspector_store.dart';
import '../store/ui_store.dart';

class InspectorScope extends InheritedWidget {
  /// High-level controller – use this in new code.
  final InspectorController controller;

  /// Low-level store – kept for backward compat with old UI widgets.
  final InspectorStore store;
  final InspectorUiStore uiStore;

  InspectorScope({
    super.key,
    required this.controller,
    required this.uiStore,
    required super.child,
  }) : store = controller.store;

  static InspectorScope of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<InspectorScope>();
    assert(scope != null, 'InspectorScope not found in widget tree');
    return scope!;
  }

  @override
  bool updateShouldNotify(InspectorScope old) =>
      controller != old.controller || uiStore != old.uiStore;
}
