part of 'export.dart';

/// Base class for orchestra widgets.
abstract class OrchestraWidget extends StatefulWidget {
  const OrchestraWidget({super.key});

  @override
  @visibleForTesting
  State<OrchestraWidget> createState() {
    return _OrchestraWidgetState();
  }

  Widget build(BuildContext context, OrchestraHandle handle);
}

final class _OrchestraWidgetState extends State<OrchestraWidget> with _OrchestraProvider<OrchestraWidget> {
  @override
  Widget build(BuildContext context) {
    return widget.build(context, orchestra);
  }
}

/// Base class for stateful orchestra widgets.
abstract class OrchestraStatefulWidget extends StatefulWidget {
  const OrchestraStatefulWidget({super.key});

  @override
  OrchestraState<OrchestraStatefulWidget> createState();
}

abstract class OrchestraState<TWidget extends OrchestraStatefulWidget> extends State<TWidget> with _OrchestraProvider {}

mixin _OrchestraProvider<T extends StatefulWidget> on State<T> {
  OrchestraHandle? _orchestra;

  @protected
  OrchestraHandle get orchestra {
    return _orchestra ??= OrchestraHandle(
      OrchestraScope.of(context),
      _rebuild,
    );
  }

  void _rebuild() {
    if (!mounted) return;
    setState(() {});
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        orchestra.initialize();
      }
    });
  }

  @override
  void dispose() {
    _orchestra?.dispose();
    super.dispose();
  }
}

/// A widget that builds itself based on the orchestra context.
final class OrchestraBuilder extends OrchestraWidget {
  /// The builder function that creates the widget tree based on the orchestra context.
  final Widget Function(BuildContext context, OrchestraHandle orchestra) builder;

  const OrchestraBuilder({
    super.key,
    required this.builder,
  });

  @override
  Widget build(BuildContext context, OrchestraHandle handle) {
    return builder(context, handle);
  }
}
