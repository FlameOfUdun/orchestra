part of 'export.dart';

/// Base class for managing orchestrations.
final class Orchestrator with Logger {
  /// An optional name for this orchestrator.
  final String? name;

  /// The unique index for this orchestrator.
  late final int index;

  /// Static set of all orchestrators.
  static final Set<Orchestrator> _orchestrators = {};

  /// Internal set of orchestrations in this orchestrator instance.
  final Set<Orchestration> _orchestrations = {};

  /// Static flag that indicates if DevTools extensions have been registered.
  static bool _devtoolsRegistered = false;

  /// Static counter for generating unique orchestrator indexes.
  static int _nextIndex = 0;

  /// Indicates if the orchestrator is active.
  bool _isActive = false;

  Orchestrator({
    this.name,
    Set<Orchestration>? orchestrations,
  }) {
    _ensureDevtoolsRegistered();
    index = _nextIndex++;
    if (orchestrations != null) {
      addOrchestrations(orchestrations);
    }
    activate();
  }

  /// Indicates if the orchestrator is active.
  bool get isActive => _isActive;

  /// Indicates if any orchestration has execute or cleanup systems.
  bool get hasExecuteOrCleanupSystems => _orchestrations
      .any((orchestration) => orchestration.hasExecuteOrCleanupSystems);

  /// Unmodifiable set of orchestrations in the orchestrator.
  Set<Orchestration> get orchestrations => Set.unmodifiable(_orchestrations);

  /// Unmodifiable set of all entities across all orchestrations.
  Set<Entity> get entities => Set.unmodifiable(
      orchestrations.expand((orchestration) => orchestration.entities.values));

  /// Unique identifier for this orchestrator.
  String get identifier => name ?? 'Orchestrator_$index';

  /// Adds an orchestration to the orchestrator.
  void addOrchestration(Orchestration orchestration) {
    orchestration.attach(this);
    _orchestrations.add(orchestration);
  }

  /// Adds multiple orchestrations to the orchestrator.
  void addOrchestrations(Set<Orchestration> orchestrations) {
    for (final orchestration in orchestrations) {
      orchestration.attach(this);
      _orchestrations.add(orchestration);
    }
  }

  /// Registers DevTools extensions.
  void _ensureDevtoolsRegistered() {
    if (_devtoolsRegistered) {
      return;
    }
    InspectorBridge.instance.registerDevtools(() => _orchestrators);
    _devtoolsRegistered = true;
  }

  /// Activates the orchestrator and all its orchestrations.
  void activate() {
    if (_isActive) return;
    _orchestrators.add(this);
    for (final orchestration in _orchestrations) {
      orchestration.activate();
    }
    _isActive = true;
    InspectorBridge.instance.orchestratorActivated(this);
  }

  /// Deactivates this orchestrator and all its orchestrations.
  void deactivate() {
    if (!_isActive) return;
    for (final orchestration in _orchestrations) {
      orchestration.deactivate();
    }
    _orchestrators.remove(this);
    _isActive = false;
    InspectorBridge.instance.orchestratorDeactivated(this);
  }

  /// Calls initialize on all orchestrations.
  void initialize() {
    for (final orchestration in _orchestrations) {
      orchestration.initialize();
    }
  }

  /// Calls teardown on all orchestrations.
  void teardown() {
    for (final orchestration in _orchestrations) {
      orchestration.teardown();
    }
  }

  /// Calls cleanup on all orchestrations.
  void cleanup() {
    for (final orchestration in _orchestrations) {
      orchestration.cleanup();
    }
  }

  /// Calls execute on all orchestrations with the given [elapsed] duration.
  void execute(Duration elapsed) {
    for (final orchestration in _orchestrations) {
      orchestration.execute(elapsed);
    }
  }

  /// Gets an entity of type [TEntity] from all orchestrations.
  ///
  /// Throws a [StateError] if the entity is not found.
  ///
  /// Throws a [StateError] if the entity of type [TEntity] is not found.
  TEntity get<TEntity extends Entity>() {
    final current = _getFrom<TEntity>(this);
    if (current != null) {
      return current;
    }

    for (final orchestrator in _orchestrators) {
      if (orchestrator == this) {
        continue;
      }

      final entity = _getFrom<TEntity>(orchestrator);
      if (entity != null) {
        return entity;
      }
    }

    throw StateError("Entity of type $TEntity not found");
  }

  /// Helper function to get an entity of type [TEntity] from a specific [orchestrator].
  TEntity? _getFrom<TEntity extends Entity>(Orchestrator orchestrator) {
    for (final orchestration in orchestrator._orchestrations) {
      final entity = orchestration.entities[TEntity];
      if (entity != null) {
        return entity as TEntity;
      }
    }
    return null;
  }

  /// Gets an entity of the specified [type] from all orchestrations.
  ///
  /// Throws a [StateError] if the entity of the specified [type] is not found.
  Entity getType(Type type) {
    final current = _getTypeFrom(this, type);
    if (current != null) {
      return current;
    }

    for (final orchestrator in _orchestrators) {
      if (orchestrator == this) {
        continue;
      }

      final entity = _getTypeFrom(orchestrator, type);
      if (entity != null) {
        return entity;
      }
    }

    throw StateError("Entity of type $type not found");
  }

  /// Helper function to get an entity of the specified [type] from a specific [orchestrator].
  Entity? _getTypeFrom(Orchestrator orchestrator, Type type) {
    for (final orchestration in orchestrator._orchestrations) {
      final entity = orchestration.entities[type];
      if (entity != null) {
        return entity;
      }
    }
    return null;
  }
}
