import 'package:devtools_extensions/devtools_extensions.dart';
import 'package:flutter/material.dart';

import '../application/controllers/inspector_controller.dart';
import '../store/ui_store.dart';
import '../theme/theme.dart';
import '../transport/devtools_runtime_client.dart';
import 'inspector_shell.dart';

/// Root widget for the Orchestra inspector DevTools extension.
///
/// Owns the [InspectorController] lifetime and provides the Material theme.
class InspectorApp extends StatefulWidget {
  const InspectorApp({super.key});

  @override
  State<InspectorApp> createState() => _InspectorAppState();
}

class _InspectorAppState extends State<InspectorApp> {
  late final InspectorController _controller;
  final _uiStore = InspectorUiStore();

  @override
  void initState() {
    super.initState();
    _controller = InspectorController(
      DevToolsRuntimeClient(serviceManager),
    );
    _controller.connect();
  }

  @override
  void dispose() {
    _controller.dispose();
    _uiStore.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Orchestra Inspector',
      theme: InspectorTheme.darkTheme,
      debugShowCheckedModeBanner: false,
      home: InspectorShell(controller: _controller, uiStore: _uiStore),
    );
  }
}
