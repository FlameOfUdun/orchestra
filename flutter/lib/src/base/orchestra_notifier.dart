part of 'export.dart';

/// A [ValueNotifier] that listens to changes in a specific [Entity]
/// and notifies listeners when it changes.
///
/// The notifier automatically subscribes to the entity when created and unsubscribes when disposed.
class EntityNotifier<TEntity extends Entity> extends ValueNotifier<TEntity> implements EntityListener {
  final Orchestrator orchestrator;

  EntityNotifier(this.orchestrator) : super(orchestrator.get<TEntity>()) {
    if (value is ListenableEntity) {
      (value as ListenableEntity).addListener(this);
    }
  }

  @override
  @mustCallSuper
  void dispose() {
    if (value is ListenableEntity) {
      (value as ListenableEntity).removeListener(this);
    }
    super.dispose();
  }

  @override
  @visibleForTesting
  void onEntityChanged(Entity entity) {
    notifyListeners();
  }
}

/// A helper class to access multiple entities from a [MultiEntityNotifier] value.
class MultiEntityNotifierValue {
  /// A map of entity types to their corresponding entities.
  final Map<Type, Entity> entities;

  const MultiEntityNotifierValue(this.entities);

  /// Retrieves the entity of the specified type from the notifier value.
  ///
  /// Throws an [ArgumentError] if the entity of the specified type is not found in the notifier value.
  TEntity get<TEntity extends Entity>() {
    final entity = entities[TEntity];
    if (entity == null) {
      throw ArgumentError('Entity of type $TEntity not found in MultiEntityNotifierValue');
    }
    return entity as TEntity;
  }

  /// Creates a copy of this [MultiEntityNotifierValue] with the specified entities replaced.
  MultiEntityNotifierValue copyWith({Map<Type, Entity>? entities}) {
    return MultiEntityNotifierValue(entities ?? this.entities);
  }
}

/// A [ValueNotifier] that listens to changes in multiple [Entity] types
/// and notifies listeners when any of them changes.
///
/// The notifier automatically subscribes to the entities when created and unsubscribes when disposed.
class MultiEntityNotifier extends ValueNotifier<MultiEntityNotifierValue> implements EntityListener {
  final Orchestrator orchestrator;
  final Set<Type> types;

  MultiEntityNotifier(this.orchestrator, this.types) : super(MultiEntityNotifierValue(Map.fromEntries(types.map((type) => MapEntry(type, orchestrator.getType(type)))))) {
    for (final entity in value.entities.values) {
      if (entity is ListenableEntity) {
        entity.addListener(this);
      }
    }
  }

  @override
  @mustCallSuper
  void dispose() {
    for (final entity in value.entities.values) {
      if (entity is ListenableEntity) {
        entity.removeListener(this);
      }
    }
    super.dispose();
  }

  @override
  @visibleForTesting
  void onEntityChanged(Entity entity) {
    notifyListeners();
  }
}
