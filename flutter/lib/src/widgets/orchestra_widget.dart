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
    return widget.build(context, handle);
  }
}

/// Base class for stateful orchestra widgets.
abstract class OrchestraStatefulWidget extends StatefulWidget {
  const OrchestraStatefulWidget({super.key});

  @override
  OrchestraState<OrchestraStatefulWidget> createState();
}

abstract class OrchestraState<TWidget extends OrchestraStatefulWidget> extends State<TWidget> with _OrchestraProvider {}

// Internal mixin for providing OrchestraHandle to the widget tree.
mixin _OrchestraProvider<T extends StatefulWidget> on State<T> {
  OrchestraHandle? _handle;

  @protected
  OrchestraHandle get handle {
    return _handle ??= OrchestraHandle(OrchestraScope.of(context), _rebuild);
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
        handle.initialize();
      }
    });
  }

  @override
  void dispose() {
    _handle?.dispose();
    super.dispose();
  }
}

/// A widget that builds itself based on the orchestra context.
final class OrchestraBuilder extends OrchestraWidget {
  /// The builder function that creates the widget tree based on the orchestra context.
  final Widget Function(BuildContext context, OrchestraHandle handle) builder;

  const OrchestraBuilder({super.key, required this.builder});

  @override
  Widget build(BuildContext context, OrchestraHandle handle) {
    return builder(context, handle);
  }
}

/// A widget that listens to changes in a [Entity] and rebuilds when it changes.
///
/// Optionally, a listener can be provided to perform side effects when the entity changes.
final class EntityWatcher<TEntity extends Entity> extends OrchestraWidget {
  final void Function(BuildContext context, TEntity)? listener;
  final Widget Function(BuildContext context, TEntity entity) builder;

  const EntityWatcher({super.key, required this.builder, this.listener});

  @override
  Widget build(BuildContext context, OrchestraHandle handle) {
    if (listener != null) {
      handle.listen<TEntity>((entity) {
        listener!(context, entity);
      });
    }

    final entity = handle.watch<TEntity>();
    return builder(context, entity);
  }
}

/// Helper class to expose multiple entities to the builder and listener of [MultiEntityWatcher].
final class MultiEntityWatcherValue {
  /// A map of entity types to their corresponding entities.
  final Map<Type, Entity> entities;

  const MultiEntityWatcherValue(this.entities);

  /// Retrieves the entity of the specified type from the builder value.
  /// 
  /// Throws an [ArgumentError] if the entity of the specified type is not found in the builder value.
  TEntity get<TEntity extends Entity>() {
    final entity = entities[TEntity];
    if (entity == null) {
      throw ArgumentError('Entity of type $TEntity not found in MultiEntityBuilderValue');
    }
    return entity as TEntity;
  }
}

/// A widget that listens to changes in multiple [Entity] types and rebuilds when any of them changes.
/// 
/// Optionally, a listener can be provided to perform side effects when any of the entities changes.
final class MultiEntityWatcher extends OrchestraWidget {
  final Set<Type> entities;
  final void Function(BuildContext context, MultiEntityWatcherValue)? listener;
  final Widget Function(BuildContext context, MultiEntityWatcherValue value) builder;

  const MultiEntityWatcher({super.key, required this.entities, required this.builder, this.listener});

  @override
  Widget build(BuildContext context, OrchestraHandle handle) {
    if (listener != null) {
      for (final entity in entities) {
        handle.listenType(entity, (_) {
          final map = Map<Type, Entity>.fromEntries(entities.map((type) => MapEntry(type, handle.getType(type))));
          listener!(context, MultiEntityWatcherValue(map));
        });
      }
    }
    final map = Map<Type, Entity>.fromEntries(entities.map((type) => MapEntry(type, handle.watchType(type))));
    return builder(context, MultiEntityWatcherValue(map));
  }
}
