part of 'export.dart';

/// Orchestrations can contain entities and systems, and they provide a way to organize
/// and manage different parts of the architecture.
abstract class Orchestration {
  /// Map of entities in this orchestration, keyed by their type.
  final Map<Type, Entity> entities = {};

  /// Set of initialize systems in this orchestration.
  final Set<InitializeSystem> initializeSystems = {};

  /// Set of teardown systems in this orchestration.
  final Set<TeardownSystem> teardownSystems = {};

  /// Set of cleanup systems in this orchestration.
  final Set<CleanupSystem> cleanupSystems = {};

  /// Set of execute systems in this orchestration.
  final Set<ExecuteSystem> executeSystems = {};

  /// Map of reactive systems by entity type.
  final Set<ReactiveSystem> reactiveSystems = {};

  /// The orchestrator that this orchestration is associated with.
  Orchestrator? orchestrator;

  /// Indicates whether this orchestration is active.
  bool _isActive = false;
  bool get isActive => _isActive;

  Orchestration();

  /// Indicates whether this orchestration is attached to an orchestrator.
  bool get isAttached => orchestrator != null;

  /// Unique identifier for this orchestration.
  String get identifier => orchestrator != null
      ? "${orchestrator!.identifier}.$runtimeType"
      : "$runtimeType";

  /// Number of systems in this orchestration.
  int get systemsCount {
    return initializeSystems.length +
        teardownSystems.length +
        reactiveSystems.length +
        cleanupSystems.length +
        executeSystems.length;
  }

  /// Indicates whether this orchestration has execute or cleanup systems.
  bool get hasExecuteOrCleanupSystems {
    return executeSystems.isNotEmpty || cleanupSystems.isNotEmpty;
  }

  /// Attaches this orchestration to an orchestrator.
  void attach(Orchestrator orchestrator) {
    this.orchestrator = orchestrator;
    InspectorBridge.instance.orchestrationAttached(this);
  }

  /// Adds an element to this orchestration.
  void add(Element element) {
    if (element is Entity) {
      _addEntity(element);
    } else if (element is System) {
      _addSystem(element);
    } else {
      throw ArgumentError(
          "Element of type ${element.runtimeType} is not supported");
    }
  }

  /// Add an entity to this orchestration.
  ///
  /// This method is protected and should be used by subclasses to add entities.
  ///
  /// If the entity is already added, it will not be added again.
  ///
  /// Throws a [StateError] if the orchestration is already active.
  void _addEntity(Entity entity) {
    final existing = entities[entity.runtimeType];
    if (existing != null) {
      throw StateError(
          "Entity of type ${entity.runtimeType} already exists in this orchestration");
    }
    entities[entity.runtimeType] = entity;
    entity.attach(this);
    entity._inspectorId ??= InspectorBridge.instance.allocEntityId();
    InspectorBridge.instance.entityAdded(entity);
  }

  /// Adds a system to this orchestration.
  ///
  /// This method is protected and should be used by subclasses to add systems.
  ///
  /// If the system is already added, it will not be added again.
  ///
  /// Throws a [StateError] if the orchestration is already active.
  void _addSystem(System system) {
    bool registered = false;
    if (system is InitializeSystem) {
      if (!initializeSystems.add(system)) {
        throw StateError(
            "System of type ${system.runtimeType} is already added to this orchestration");
      }
      registered = true;
    }
    if (system is TeardownSystem) {
      if (!teardownSystems.add(system)) {
        throw StateError(
            "System of type ${system.runtimeType} is already added to this orchestration");
      }
      registered = true;
    }
    if (system is CleanupSystem) {
      if (!cleanupSystems.add(system)) {
        throw StateError(
            "System of type ${system.runtimeType} is already added to this orchestration");
      }
      registered = true;
    }
    if (system is ExecuteSystem) {
      if (!executeSystems.add(system)) {
        throw StateError(
            "System of type ${system.runtimeType} is already added to this orchestration");
      }
      registered = true;
    }
    if (system is ReactiveSystem) {
      if (!reactiveSystems.add(system)) {
        throw StateError(
            "System of type ${system.runtimeType} is already added to this orchestration");
      }
      registered = true;
    }
    if (!registered) {
      throw ArgumentError(
          "System of type ${system.runtimeType} is not supported");
    }
    system.attach(this);
    system.inspectorId ??= InspectorBridge.instance.allocSystemId();
    InspectorBridge.instance.systemAdded(system);
  }

  /// Activates all systems in this orchestration.
  void activate() {
    if (_isActive) return;
    for (final system in reactiveSystems) {
      system.activate();
    }
    _isActive = true;
  }

  /// Deactivates all systems in this orchestration.
  void deactivate() {
    if (!_isActive) return;
    for (final system in reactiveSystems) {
      system.deactivate();
    }
    _isActive = false;
  }

  /// Triggers all the initialize systems in this orchestration.
  ///
  /// Throws a [StateError] if the orchestration is not active.
  void initialize() {
    for (final system in initializeSystems) {
      _invokeSystem(system, system.initialize);
    }
  }

  /// Triggers all the teardown systems in this orchestration.
  void teardown() {
    for (final system in teardownSystems) {
      if (system.teardownsIf) {
        _invokeSystem(system, system.teardown);
      }
    }
  }

  /// Triggers all the cleanup systems in this orchestration.
  void cleanup() {
    for (final system in cleanupSystems) {
      if (system.cleansIf) {
        _invokeSystem(system, system.cleanup);
      }
    }
  }

  /// Executes the features.
  void execute(Duration elapsed) {
    for (final system in executeSystems) {
      if (system.executesIf) {
        _invokeSystem(system, () => system.execute(elapsed));
      }
    }
  }

  /// Wraps a system invocation with inspector timing + emit.
  void _invokeSystem(System system, void Function() body,
      {String? triggerEntityId}) {
    if (!InspectorBridge.instance.enabled) {
      body();
      return;
    }
    final id = system.inspectorId;
    if (id == null) {
      body();
      return;
    }
    final start = DateTime.now().microsecondsSinceEpoch;
    bool succeeded = true;
    try {
      body();
    } catch (_) {
      succeeded = false;
      rethrow;
    } finally {
      InspectorBridge.instance.systemFired(
        systemId: id,
        triggerEntityId: triggerEntityId,
        durationMicros: DateTime.now().microsecondsSinceEpoch - start,
        succeeded: succeeded,
      );
    }
  }

  /// Gets an entity of type [TEntity] from this orchestration if it exists.
  ///
  /// Throws a [StateError] if the entity is not found.
  TEntity get<TEntity extends Entity>() {
    final entity = entities[TEntity];
    if (entity == null) {
      throw StateError("Entity of type $TEntity not found");
    }
    return entity as TEntity;
  }

  /// Gets an entity of the specified [type].
  ///
  /// Throws a [StateError] if the entity is not found.
  Entity getType(Type type) {
    final entity = entities[type];
    if (entity == null) {
      throw StateError("Entity of type $type not found");
    }
    return entity;
  }
}
