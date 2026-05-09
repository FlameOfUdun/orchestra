part of 'export.dart';

/// Context for accessing orchestra from widgets.
final class OrchestraHandle implements EntityListener {
  /// The orchestrator instance.
  @visibleForTesting
  final Orchestrator orchestrator;

  /// Callback for notifying changes in the context.
  @visibleForTesting
  final void Function() callback;

  /// Map of entity listeners.
  @visibleForTesting
  final Map<ListenableEntity, void Function()> listeners = {};

  /// Set of entities being watched.
  @visibleForTesting
  final Set<ListenableEntity> watchers = {};

  /// Optional listeners for enter event.
  @visibleForTesting
  void Function()? onEnterListener;

  /// Optional listeners for exit event.
  @visibleForTesting
  void Function()? onExitListener;

  /// Indicates if the context has been disposed.
  @visibleForTesting
  bool disposed = false;

  /// Indicates if the context is currently locked for rebuilding.
  @visibleForTesting
  bool locked = false;

  /// Cache of entities accessed through this context.
  @visibleForTesting
  Map<Type, Entity> entities = {};

  /// Indicates if listener callbacks are currently scheduled for next frame.
  @visibleForTesting
  bool listenerLocked = false;

  /// Pending listener callbacks to execute on next frame.
  @visibleForTesting
  List<void Function()> pendingListeners = [];

  /// Indicates if onEnter has been set.
  @visibleForTesting
  bool onEnterSet = false;

  /// Indicates if onExit has been set.
  @visibleForTesting
  bool onExitSet = false;

  OrchestraHandle(this.orchestrator, this.callback);

  /// Retrieves an entity of type [TEntity].
  ///
  /// This function will search the cached entities set first.
  /// If the entity is not found, it will be fetched from the orchestrator and added
  /// to the entities set. Otherwise, it will return the existing entity from the set.
  TEntity _fetch<TEntity extends Entity>() {
    final cached = entities[TEntity];
    if (cached != null) {
      return cached as TEntity;
    }
    final entity = orchestrator.get<TEntity>();
    entities[TEntity] = entity;
    return entity;
  }

  /// Retrieves an entity of type [TEntity].
  ///
  /// This function will search the cached entities set first.
  /// If the entity is not found, it will be fetched from the orchestrator and added
  /// to the entities set. Otherwise, it will return the existing entity from the set.
  Entity _fetchType(Type type) {
    final cached = entities[type];
    if (cached != null) {
      return cached;
    }
    final entity = orchestrator.getType(type);
    entities[type] = entity;
    return entity;
  }

  /// Gets an entity of type [TEntity] from the orchestrator.
  ///
  /// Entities are cached for performance. Subsequent calls for the same type
  /// will return the cached instance.
  ///
  /// Throws [StateError] if called on a disposed context.
  TEntity get<TEntity extends Entity>() {
    if (disposed) {
      throw StateError('Cannot get entity on disposed context');
    }
    return _fetch<TEntity>();
  }

  /// Gets an entity of a specific type from the orchestrator.
  ///
  /// Entities are cached for performance. Subsequent calls for the same type
  /// will return the cached instance.
  ///
  /// Throws [StateError] if called on a disposed context.
  Entity getType(Type type) {
    if (disposed) {
      throw StateError('Cannot get entity on disposed context');
    }
    return _fetchType(type);
  }

  /// Watches an entity of type [TEntity] for changes.
  ///
  /// When the entity changes, the widget will rebuild automatically.
  ///
  /// Multiple calls with the same entity type will not create duplicate subscriptions.
  ///
  /// Throws [StateError] if called on a disposed context.
  TEntity watch<TEntity extends Entity>() {
    if (disposed) {
      throw StateError('Cannot watch entity on disposed context');
    }
    final entity = _fetch<TEntity>();
    if (entity is! ListenableEntity) {
      return entity;
    }
    if (watchers.add(entity)) {
      entity.addListener(this);
    }
    return entity;
  }

  /// Watches an entity of a specific type for changes.
  ///
  /// When the entity changes, the widget will rebuild automatically.
  ///
  /// Multiple calls with the same entity type will not create duplicate subscriptions.
  ///
  /// Throws [StateError] if called on a disposed context.
  Entity watchType(Type type) {
    if (disposed) {
      throw StateError('Cannot watch entity on disposed context');
    }
    final entity = _fetchType(type);
    if (entity is! ListenableEntity) {
      return entity;
    }
    if (watchers.add(entity)) {
      entity.addListener(this);
    }
    return entity;
  }

  /// Listens to changes in an entity of type [TEntity].
  ///
  /// The listener will be called at the next frame boundary when the entity changes.
  /// Unlike [watch], this does not trigger widget rebuilds.
  ///
  /// Callbacks are executed via frame callbacks and are batched together.
  /// Multiple calls with the same entity type will override the previous listener.
  ///
  /// If called on a disposed context, the operation is silently ignored.
  ///
  /// Throws [StateError] if called on a disposed context.
  void listen<TEntity extends Entity>(void Function(TEntity entity) listener) {
    if (disposed) {
      throw StateError('Cannot listen to entity on disposed context');
    }
    final entity = _fetch<TEntity>();
    if (entity is! ListenableEntity) {
      return;
    }
    if (!listeners.containsKey(entity)) entity.addListener(this);
    listeners[entity] = () => listener(entity);
  }

  /// Listens to changes in an entity of a specific type.
  ///
  /// The listener will be called at the next frame boundary when the entity changes.
  /// Unlike [watch], this does not trigger widget rebuilds.
  ///
  /// Callbacks are executed via frame callbacks and are batched together.
  /// Multiple calls with the same entity type will override the previous listener.
  ///
  /// If called on a disposed context, the operation is silently ignored.
  ///
  /// Throws [StateError] if called on a disposed context.
  void listenType(Type type, void Function(ListenableEntity entity) listener) {
    if (disposed) {
      throw StateError('Cannot listen to entity on disposed context');
    }
    final entity = _fetchType(type);
    if (entity is! ListenableEntity) {
      return;
    }
    if (!listeners.containsKey(entity)) entity.addListener(this);
    listeners[entity] = () => listener(entity);
  }

  /// Unlistens to changes in an entity of type [TEntity].
  ///
  /// If the entity is being listened to, the listener will be removed and the entity
  /// will no longer trigger listener callbacks. This does not affect [watch] subscriptions.
  /// 
  /// Throws [StateError] if called on a disposed context.
  void unlisten<TEntity extends Entity>() {
    if (disposed) {
      throw StateError('Cannot unlisten to entity on disposed context');
    }
    final entity = _fetch<TEntity>();
    if (entity is! ListenableEntity) {
      return;
    }
    if (listeners.containsKey(entity)) {
      entity.removeListener(this);
      listeners.remove(entity);
    }
  }

  /// Unlistens to changes in an entity of a specific type.
  ///
  /// If the entity is being listened to, the listener will be removed and the entity
  /// will no longer trigger listener callbacks. This does not affect [watch] subscriptions.
  /// 
  /// Throws [StateError] if called on a disposed context.
  void unlistenType(Type type) {
    if (disposed) {
      throw StateError('Cannot unlisten to entity on disposed context');
    }
    final entity = _fetchType(type);
    if (entity is! ListenableEntity) {
      return;
    }
    if (listeners.containsKey(entity)) {
      entity.removeListener(this);
      listeners.remove(entity);
    }
  }

  /// Initializes the Orchestra.
  ///
  /// This is called automatically by the orchestra widget after the first frame.
  /// If an [onEnter] callback was registered, it will be scheduled to run
  /// at the next frame boundary to avoid setState during build.
  void initialize() {
    if (onEnterListener != null) {
      SchedulerBinding.instance.scheduleFrameCallback((_) {
        if (!disposed) {
          guard(onEnterListener!, description: 'Orchestra onEnter callback');
        }
      });
    }
  }

  /// Disposes the Orchestra.
  ///
  /// Disposal sequence:
  /// 1. Sets [disposed] flag to prevent new operations
  /// 2. Executes [onExit] callback synchronously (can still access entities)
  /// 3. Clears entity cache and pending listener callbacks
  /// 4. Removes all entity listeners and clears subscriptions
  ///
  /// After disposal, [get] and [watch] will throw [StateError], while [listen]
  /// will silently ignore new calls.
  void dispose() {
    disposed = true;

    if (onExitListener != null) {
      guard(onExitListener!, description: 'Orchestra onExit callback');
    }

    entities.clear();
    pendingListeners.clear();

    for (final entity in watchers) {
      entity.removeListener(this);
    }
    watchers.clear();

    for (final entity in listeners.keys) {
      entity.removeListener(this);
    }
    listeners.clear();
  }

  /// Rebuilds the Orchestra.
  ///
  /// This method is used to trigger a rebuild of the context.
  ///
  /// Rebuilds are coalesced - multiple rebuild requests within the same
  /// frame will result in only one actual rebuild at the next frame boundary.
  @visibleForTesting
  void rebuild() {
    if (locked || disposed) {
      return;
    }
    locked = true;

    SchedulerBinding.instance.scheduleFrameCallback((_) {
      if (!disposed) {
        guard(callback, description: 'Orchestra rebuild callback');
      }
      locked = false;
    });
  }

  /// Registers a callback to be executed when the context is initialized.
  ///
  /// The callback is executed at the next frame boundary after initialization
  /// to avoid setState during build. This ensures the widget is fully initialized
  /// before the callback runs.
  ///
  /// Can only be set once - subsequent calls are ignored.
  void onEnter(void Function() function) {
    if (onEnterSet) {
      return;
    }
    onEnterSet = true;
    onEnterListener = function;
  }

  /// Registers a callback to be executed when the context is disposed.
  ///
  /// The callback is executed synchronously during disposal, after the [disposed]
  /// flag is set but before resources are cleared. This allows the callback to
  /// access entities and perform cleanup.
  ///
  /// Can only be set once - subsequent calls are ignored.
  void onExit(void Function() function) {
    if (onExitSet) {
      return;
    }
    onExitSet = true;
    onExitListener = function;
  }

  @override
  @visibleForTesting
  void onEntityChanged(Entity entity) {
    if (disposed) {
      return;
    }
    if (watchers.contains(entity)) {
      rebuild();
    }

    if (listeners.containsKey(entity)) {
      final callback = listeners[entity]!;
      if (!pendingListeners.contains(callback)) {
        pendingListeners.add(callback);
      }
      _scheduleListeners();
    }
  }

  /// Schedules pending listener callbacks to execute at the next frame boundary.
  ///
  /// Multiple listener callbacks are batched together and executed in a single frame.
  /// Callbacks are coalesced - multiple schedule requests within the same frame
  /// result in only one execution at the next frame boundary.
  void _scheduleListeners() {
    if (listenerLocked || disposed) {
      return;
    }
    listenerLocked = true;

    SchedulerBinding.instance.scheduleFrameCallback((_) {
      if (!disposed && pendingListeners.isNotEmpty) {
        final callbacks = List<void Function()>.from(pendingListeners);
        pendingListeners.clear();

        for (final callback in callbacks) {
          guard(callback, description: 'Orchestra listener callback');
        }
      }
      listenerLocked = false;
    });
  }

  /// Runs a function safely, catching and reporting any errors.
  @visibleForTesting
  void guard(void Function() function, {required String description}) {
    try {
      function();
    } catch (error, stack) {
      FlutterError.reportError(FlutterErrorDetails(exception: error, stack: stack, library: 'Orchestra', context: ErrorDescription(description)));
    }
  }
}
