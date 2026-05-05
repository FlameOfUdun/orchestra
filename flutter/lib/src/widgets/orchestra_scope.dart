part of 'export.dart';

/// A widget that provides an Orchestrator scope to its descendants.
///
/// This widget manages the lifecycle of the orchestrations in its scope,
/// including initialization, execution, cleanup, and teardown.
///
/// Orchestrations added to this scope will be automatically initialized when the
/// widget is inserted into the widget tree, and torn down when the widget is
/// removed from the tree.
///
/// After disposal, the orchestrations will also be removed from the Orchestrator.
final class OrchestraScope extends StatefulWidget {
  /// An optional name for this Orchestra scope.
  /// This can be useful particularly for debugging and using inspector devtools extension.
  final String? name;

  /// Set of orchestrations to be managed by this Orchestra scope.
  final Set<Orchestration> orchestrations;

  /// The child widget to be rendered within this Orchestra scope.
  final Widget child;

  const OrchestraScope({
    super.key,
    this.name,
    required this.orchestrations,
    required this.child,
  });

  @override
  @protected
  State<OrchestraScope> createState() => _OrchestraScopeState();

  /// Gets the Orchestrator from the nearest OrchestraScope ancestor.
  static Orchestrator of(BuildContext context) {
    final manager = maybeOf(context);
    if (manager == null) {
      throw FlutterError('OrchestraScope not found in context');
    }
    return manager;
  }

  /// Gets the Orchestrator from the nearest OrchestraScope ancestor, or null if not found.
  static Orchestrator? maybeOf(BuildContext context) {
    return context.findAncestorStateOfType<_OrchestraScopeState>()?.manager;
  }
}

final class _OrchestraScopeState extends State<OrchestraScope>
    with SingleTickerProviderStateMixin {
  /// The Orchestrator for this scope.
  late final manager = Orchestrator(
    name: widget.name,
    orchestrations: widget.orchestrations,
  );

  /// Ticker for driving the execution loop.
  Ticker? ticker;

  /// Duration tracker for ticker elapsed time calculation.
  Duration duration = Duration.zero;

  @override
  void initState() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      manager.initialize();
      if (manager.hasExecuteOrCleanupSystems) {
        startTicker();
      }
    });

    super.initState();
  }

  /// Calculates the elapsed duration since the last call.
  Duration calculateElapsed(Duration duration) {
    final elapsed = duration - this.duration;
    this.duration = duration;
    return elapsed;
  }

  /// Starts the ticker to drive the execution loop.
  void startTicker() {
    ticker = createTicker((duration) {
      final elapsed = calculateElapsed(duration);
      manager
        ..execute(elapsed)
        ..cleanup();
    })..start();
  }

  @override
  void dispose() {
    ticker?.stop();
    manager
      ..teardown()
      ..deactivate();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
