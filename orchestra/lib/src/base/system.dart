part of 'export.dart';

/// Base class for systems.
sealed class System extends Element {
  /// Cached entities that this system interacts with.
  Map<Type, Entity> entities = {};

  /// The parent orchestration of this system.
  Orchestration? orchestration;

  /// Stable id for the inspector wire protocol; assigned at registration time.
  String? inspectorId;

  System();

  /// Set of types that this system interacts with.
  ///
  /// This set should be overridden in subclasses to specify the types of
  /// entities that this system can interact with.
  ///
  /// This is used to optimize the system's execution by filtering entities
  /// that are relevant to the system and avoid unnecessary processing.
  ///
  /// This is also used for debugging purposes to understand which entities
  /// are being processed by the system.
  Set<Type> get interactsWith => const {};

  /// Unique identifier for this system.
  String get identifier => '${orchestration?.identifier}.$runtimeType';

  /// Indicates whether this system is active.
  bool get isAttached => orchestration != null;

  /// Attaches this system to an orchestration.
  void attach(Orchestration orchestration) {
    this.orchestration = orchestration;
  }

  /// Logs a message to the logging system.
  void log(String message, {LogLevel level = LogLevel.info}) {
    orchestration?.orchestrator?.log(
      message,
      level: level,
      orchestrationId: orchestration?.identifier,
      systemId: inspectorId,
      orchestrationName: orchestration?.runtimeType.toString(),
      systemName: runtimeType.toString(),
    );
  }

  /// Gets an entity of type [TEntity]
  ///
  /// This function will search the internal cahced entities set first. If the entity
  /// is not found, it will be fetched from the parent orchestration. If the entity is not found
  /// in the parent orchestration, it will be fetched from the orchestrator and added to the
  /// internal cached entities set.
  ///
  /// Throws a [StateError] if the entity is not found in both the parent orchestration
  /// and the orchestrator.
  TEntity get<TEntity extends Entity>() {
    final cached = entities[TEntity];
    if (cached != null) {
      return cached as TEntity;
    }
    TEntity entity;
    try {
      entity = orchestration!.get<TEntity>();
    } catch (_) {
      entity = orchestration!.orchestrator!.get<TEntity>();
    }
    entities[TEntity] = entity;
    return entity;
  }
}

/// Base class for initialize systems.
///
/// Initialize systems are used to perform setup tasks.
///
/// The [initialize] method should be overridden in subclasses to perform
/// the actual initialization logic.
///
/// The [initialize] method is called once after the first frame is rendered and
/// before any other systems are executed.
abstract class InitializeSystem extends System {
  /// Initialize logic for the system.
  void initialize();
}

/// Base class for cleanup systems.
///
/// Cleanup systems are used to perform cleanup tasks.
///
/// The [cleanup] method should be overridden in subclasses to perform the
/// actual cleanup logic.
///
/// The [cleanup] method is called after all [ExecuteSystem]s have been executed
/// and before the next frame is rendered.
abstract class CleanupSystem extends System {
  /// Whether the system should be executed or not.
  ///
  /// This is used to determine whether the system should be executed on every
  /// frame.
  ///
  /// If this is set to `false`, the system will not be executed on each frame.
  bool get cleansIf => true;

  /// Cleanup logic for the system.
  void cleanup();
}

/// Base class for teardown systems.
///
/// Teardown systems are used to perform teardown tasks.
///
/// The [teardown] method should be overridden in subclasses to perform the
/// actual teardown logic.
///
/// The [teardown] method is called once after the last frame is rendered and
/// before the application is disposed.
abstract class TeardownSystem extends System {
  /// Whether the system should be torn down or not.
  ///
  /// If this is set to `false`, the system will not be torn down when the
  /// application is disposed.
  bool get teardownsIf => true;

  /// Teardown logic for the system.
  void teardown();
}

/// Base class for execute systems.
///
/// Execute systems are used to perform tasks that need to be executed
/// periodically, such as updating the state of entities or processing events.
///
/// The [execute] method should be overridden in subclasses to perform the
/// actual execution logic.
///
/// The [execute] method is called every frame.
abstract class ExecuteSystem extends System {
  /// Whether the system should be executed or not.
  ///
  /// This is used to determine whether the system should be executed on every
  /// frame.
  ///
  /// If this is set to `false`, the system will not be executed on each frame.
  bool get executesIf => true;

  /// Execute logic for the system.
  void execute(Duration elapsed);
}

/// Base class for reactive systems.
///
/// Reactive systems are used to react to changes in entities.
///
/// The [react] method should be overridden in subclasses to perform the
/// actual reaction logic.
abstract class ReactiveSystem extends System implements EntityListener {
  /// Indicates whether this system is active.
  bool _isActive = false;
  bool get isActive => _isActive;

  /// The set of entity types that this system reacts to.
  ///
  /// This set should be overridden in subclasses to specify the types of
  /// entities that this system reacts to.
  ///
  /// This is used to optimize the system's reaction by filtering entities
  /// that are relevant to the system and avoid unnecessary processing.
  ///
  /// This is also used for debugging purposes to understand which entities
  /// are being processed by the system.
  Set<Type> get reactsTo;

  /// Whether the system reacts to changes in entities.
  ///
  /// This is used to determine whether the system should be executed
  /// when an entity changes.
  ///
  /// If this is set to `false`, the system will not be executed
  /// when an entity changes, even if it is being watched.
  bool get reactsIf => true;

  /// Activates this system by adding listeners to the entities it reacts to.
  ///
  /// If the system is already active, this method does nothing.
  void activate() {
    if (_isActive) return;
    for (final type in reactsTo) {
      final entity = orchestration!.orchestrator!.getType(type);
      if (entity is ListenableEntity) {
        entity.addListener(this);
      } else {
        log('Entity of type $type is not listenable and cannot be reacted to', level: LogLevel.warning);
      }
    }
    _isActive = true;
  }

  /// Deactivates this system by removing listeners from the entities it reacts to.
  ///
  /// If the system is not active, this method does nothing.
  void deactivate() {
    if (!_isActive) return;
    for (final type in reactsTo) {
      final entity = orchestration!.orchestrator!.getType(type);
      if (entity is ListenableEntity) {
        entity.removeListener(this);
      } else {
        log('Entity of type $type is not listenable and cannot be reacted to', level: LogLevel.warning);
      }
    }
    _isActive = false;
  }

  @override
  void onEntityChanged(Entity entity) {
    if (!reactsIf) return;
    if (entity is Component) {
      log('$identifier reacted to changes in ${entity.identifier}');
    } else if (entity is DataEvent) {
      log('$identifier reacted to trigger of ${entity.identifier}');
    } else if (entity is Event) {
      log('$identifier reacted to trigger of ${entity.identifier}');
    }
    if (!InspectorBridge.instance.enabled || inspectorId == null) {
      react();
      return;
    }
    final start = DateTime.now().microsecondsSinceEpoch;
    bool succeeded = true;
    try {
      react();
    } catch (_) {
      succeeded = false;
      rethrow;
    } finally {
      InspectorBridge.instance.systemFired(
        systemId: inspectorId!,
        triggerEntityId: entity._inspectorId,
        durationMicros: DateTime.now().microsecondsSinceEpoch - start,
        succeeded: succeeded,
      );
    }
  }

  void react();
}
