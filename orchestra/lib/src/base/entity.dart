part of 'export.dart';

/// Base entity.
sealed class Entity extends Element {
  /// The orchestration this entity belongs to.
  Orchestration? _orchestration;
  Orchestration? get orchestration => _orchestration;

  /// Stable id for the inspector wire protocol; assigned at registration time.
  String? _inspectorId;
  String? get inspectorId => _inspectorId;

  /// Indicates whether this entity is active (i.e., has a parent feature).
  bool get isAttached => _orchestration != null;

  /// Unique identifier for this entity.
  String get identifier => '${_orchestration?.identifier}.$runtimeType';

  /// Attaches this entity to an orchestration.
  void attach(Orchestration orchestration) {
    _orchestration = orchestration;
  }

  /// Logs a message to logging system.
  void log(String message, {LogLevel level = LogLevel.info}) {
    _orchestration?.orchestrator?.log(
      message,
      level: level,
      orchestrationId: _orchestration?.identifier,
      orchestrationName: _orchestration?.runtimeType.toString(),
      entityRefs: _inspectorId == null ? const [] : <String>[_inspectorId!],
    );
  }

  /// Builds a string descriptor for this entity in inspector.
  String describe() {
    return identifier;
  }
}

/// Interface for listening to changes in entities.
abstract interface class EntityListener {
  /// Called when an entity changes.
  void onEntityChanged(Entity entity);
}

/// Represents a listenable entity that can notify listeners of changes.
sealed class ListenableEntity extends Entity {
  /// Set of listeners for this entity.
  final Set<EntityListener> listeners = {};

  /// Adds a listener to this entity.
  void addListener(EntityListener listener) {
    listeners.add(listener);
  }

  /// Removes a listener from this entity.
  void removeListener(EntityListener listener) {
    listeners.remove(listener);
  }

  void notifyListeners() {
    final temp = listeners.toList();
    for (final listener in temp) {
      listener.onEntityChanged(this);
    }
  }
}

/// Represents an event that can be triggered to notify listeners.
abstract class Event extends ListenableEntity {
  /// The last triggered timestamp of the event.
  DateTime? _triggeredAt;

  /// The last triggered timestamp of the event, or null if never triggered.
  DateTime? get triggeredAt => _triggeredAt;

  /// Triggers the event, notifying all listeners.
  void trigger() {
    _triggeredAt = DateTime.now();
    log('$identifier triggered');
    InspectorBridge.instance.eventFired(this, null);
    notifyListeners();
  }
}

/// Data events are events that can be triggered with associated data to notify listeners.
///
/// When triggered, the event holds the data temporarily during notification. Notice
/// that you should not use the [data] property asynchronously after triggering because
/// next time the event is triggered, the data will be overridden and may cause unexpected
/// results. If you need to keep the data for later use, consider copying it before use
/// or using a component instead.
abstract class DataEvent<TData> extends ListenableEntity {
  /// The current data of the event.
  TData? _data;

  /// The last triggered timestamp of the event.
  DateTime? _triggeredAt;

  /// The current data of the event.
  ///
  /// Throws a [StateError] if the event has not been triggered yet or if the data is null.
  TData get data {
    final current = _data;
    if (current == null) {
      throw StateError('No data available.');
    }
    return current;
  }

  /// The current data of the event, or null if none.
  TData? get dataOrNull => _data;

  /// The last triggered timestamp of the event, or null if never triggered.
  DateTime? get triggeredAt => _triggeredAt;

  /// Triggers the event with associated [data], notifying all listeners.
  void trigger(TData data) {
    _data = data;
    _triggeredAt = DateTime.now();
    log('$identifier triggered with data: ${describe(_data)}');
    InspectorBridge.instance.eventFired(this, data);
    notifyListeners();
  }

  @override
  String describe([TData? data]) {
    return data.toString();
  }
}

/// Represents a component that hold data and can be updated and
/// will notify listeners when their value changes.
abstract class Component<TValue> extends ListenableEntity {
  /// The current value of the component.
  TValue _value;

  /// The previous value of the component.
  TValue? _previous;

  /// The last updated timestamp of the component.
  DateTime? _updatedAt;

  Component(this._value);

  /// The current value of the component.
  TValue get value => _value;

  /// The previous value of the component, or null if never set.
  TValue? get previous => _previous;

  /// The last updated timestamp of the component, or null if never updated.
  DateTime? get updatedAt => _updatedAt;

  /// Updates the component's value.
  ///
  /// If [notify] is `true`, listeners will be notified of the change. Default
  /// is `true`.
  ///
  /// If the [value] is equal to the current value, no change will be made
  /// unless [force] is `true`, then update will be applied anyways. Defaults is
  /// `false`.
  void update(
    TValue value, {
    bool notify = true,
    bool force = false,
  }) {
    if (force == false) {
      if (_value == value) {
        return;
      }
    }
    _previous = _value;
    _value = value;
    _updatedAt = DateTime.now();
    InspectorBridge.instance.componentUpdated(this, _value, _previous);
    if (notify) {
      log('$identifier updated from ${describe(_previous)} to ${describe(_value)}');
      notifyListeners();
    }
  }

  /// Fast setter for updating the component's value.
  ///
  /// This is equivalent to calling [update] with default parameters.
  set value(TValue value) {
    update(value);
  }

  @override
  String describe([TValue? value]) {
    return value.toString();
  }
}

/// Represents a dependency that hold a value and can be injected into features or systems.
abstract class Dependency<TValue> extends Entity {
  /// The value of the dependency.
  final TValue value;

  Dependency(this.value);
}
