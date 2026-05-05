# Orchestra

[![pub package](https://img.shields.io/pub/v/orchestra.svg)](https://pub.dev/packages/orchestra)
[![Apache 2.0 License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](https://www.apache.org/licenses/LICENSE-2.0)
[![Flutter](https://img.shields.io/badge/Flutter-02569B?logo=flutter&logoColor=white)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-0175C2?logo=dart&logoColor=white)](https://dart.dev)

A reactive state management library for Dart and Flutter. Promotes clean architecture, deterministic business logic, and scalable application design through strict separation of data, behavior, and events.

---

## Why Orchestra

| Concern | Traditional approach | Orchestra |
|---|---|---|
| State | Scattered across notifiers / blocs | Typed `Component<T>` entities |
| Logic | Coupled to widgets or providers | Stateless `System` classes |
| Events | Callbacks / streams passed through the tree | First-class `Event` / `DataEvent` entities |
| Modules | Global providers or nested scopes | Self-contained `Orchestration` |
| Debugging | Ad-hoc logging | Built-in Inspector DevTools extension |

---

## Core Concepts

### Entities

Everything that holds data or represents an occurrence is an entity.

| Type | Description |
|---|---|
| `Component<T>` | Holds mutable state. Notifies listeners on change. |
| `Event` | A trigger with no payload. |
| `DataEvent<T>` | A trigger that carries typed data. |
| `Dependency<T>` | An immutable value injected into systems. |

### Systems

Systems contain all business logic. They are stateless and operate on entities.

| Type | When it runs |
|---|---|
| `InitializeSystem` | Once, after the orchestration activates |
| `ReactiveSystem` | When a watched entity changes or an event fires |
| `ExecuteSystem` | Every frame (ticker-driven) |
| `CleanupSystem` | After every execute pass |
| `TeardownSystem` | Once, when the orchestration is deactivated |

### Orchestration

Groups related entities and systems into a cohesive, self-contained module.

### Orchestrator

Central coordinator. Manages one or more orchestrations, drives system execution, and provides type-based entity lookup across the whole graph.

---

## Installation

```yaml
dependencies:
  orchestra: ^1.0.0

# Optional: add if you want to use the Composer declarative API
dev_dependencies:
  orchestra_generator: ^1.0.0
  build_runner: ^2.0.0
```

---

## Quick Start

There are two ways to use Orchestra:

- **Manual** — subclass `Component`, `Event`, `System`, and `Orchestration` directly (shown below).
- **Code generation** — declare everything with `Composer` and let `orchestra_generator` generate the classes. See [Code Generation](#code-generation-recommended).

### 1. Define entities

```dart
// Component — holds state
class CounterComponent extends Component<int> {
  CounterComponent() : super(0);
}

// Event — parameterless trigger
class IncrementEvent extends Event {}

// DataEvent — trigger with payload
class SetCounterEvent extends DataEvent<int> {}
```

### 2. Write systems

```dart
class IncrementSystem extends ReactiveSystem {
  @override
  Set<Type> get reactsTo => {IncrementEvent};

  @override
  Set<Type> get interactsWith => {CounterComponent};

  @override
  void react() {
    final counter = get<CounterComponent>();
    counter.update(counter.value + 1);
  }
}

class SetCounterSystem extends ReactiveSystem {
  @override
  Set<Type> get reactsTo => {SetCounterEvent};

  @override
  Set<Type> get interactsWith => {CounterComponent};

  @override
  void react() {
    final event = get<SetCounterEvent>();
    final counter = get<CounterComponent>();
    counter.update(event.data);
  }
}
```

### 3. Bundle into an orchestration

```dart
class CounterOrchestration extends Orchestration {
  CounterOrchestration() {
    add(CounterComponent());
    add(IncrementEvent());
    add(SetCounterEvent());
    add(IncrementSystem());
    add(SetCounterSystem());
  }
}
```

### 4. Wire up the orchestrator

```dart
final orchestrator = Orchestrator(
  orchestrations: {CounterOrchestration()},
);

// Trigger events
orchestrator.get<IncrementEvent>().trigger();
orchestrator.get<SetCounterEvent>().trigger(42);

// Read state
print(orchestrator.get<CounterComponent>().value); // 42 + 1 = 43
```

---

## Entity API

### Component

```dart
final counter = orchestrator.get<CounterComponent>();

counter.update(10);         // update + notify listeners
counter.update(10, notify: false); // silent update
counter.update(10, force: true);   // update even if value is equal
counter.value = 20;         // shorthand for update(20)

print(counter.value);       // current value
print(counter.previous);    // previous value after last update
print(counter.updatedAt);   // DateTime of last update
```

### Event

```dart
final increment = orchestrator.get<IncrementEvent>();
increment.trigger();
print(increment.triggeredAt); // DateTime of last trigger
```

### DataEvent

```dart
final setCounter = orchestrator.get<SetCounterEvent>();
setCounter.trigger(99);

print(setCounter.data);       // 99 — throws if never triggered
print(setCounter.dataOrNull); // 99? — null if never triggered
print(setCounter.triggeredAt);
```

### Dependency

```dart
// Define
class ApiUrlDependency extends Dependency<String> {
  ApiUrlDependency(super.value);
}

// Register in an orchestration
add(ApiUrlDependency('https://api.example.com'));

// Access in a system
final url = get<ApiUrlDependency>().value;
```

---

## System API

### ReactiveSystem

```dart
class UpdateCacheSystem extends ReactiveSystem {
  @override
  Set<Type> get reactsTo => {UserComponent, AuthEvent};

  @override
  Set<Type> get interactsWith => {CacheComponent};

  // Optional guard — skip react() when false
  @override
  bool get reactsIf => get<AuthComponent>().value.isLoggedIn;

  @override
  void react() {
    // called once per qualifying entity change
  }
}
```

### ExecuteSystem

```dart
class AnimationSystem extends ExecuteSystem {
  @override
  Set<Type> get interactsWith => {AnimationComponent};

  @override
  bool get executesIf => get<AnimationComponent>().value.isPlaying;

  @override
  void execute(Duration elapsed) {
    final anim = get<AnimationComponent>();
    anim.update(anim.value.advance(elapsed));
  }
}
```

### InitializeSystem / TeardownSystem

```dart
class DatabaseInitSystem extends InitializeSystem {
  @override
  Set<Type> get interactsWith => {DatabaseComponent};

  @override
  void initialize() {
    get<DatabaseComponent>().update(Database.open());
  }
}

class DatabaseTeardownSystem extends TeardownSystem {
  @override
  void teardown() {
    get<DatabaseComponent>().value.close();
  }
}
```

### Logging from systems and entities

```dart
// Inside any System
log('Processing user data');
log('Entity null — skipping', level: LogLevel.warning);

// Inside any Entity
log('Value sanitized before update');
```

---

## Code Generation (Recommended)

Orchestra includes a declarative API via `Composer` that eliminates boilerplate. Instead of writing entity and system classes by hand, you declare your orchestration inline and let `orchestra_generator` generate all the class definitions at build time.

> **`Composer` is a code-generation DSL, not a runtime API.** It requires `orchestra_generator` and `build_runner` to produce the actual Dart classes. See the [orchestra_generator README](https://github.com/FlameOfUdun/orchestra/tree/main/generator) for full documentation.

```dart
// counter_feature.dart
import 'package:orchestra/orchestra.dart';

part 'counter_feature.g.dart'; // generated output

final counterFeature = Composer.createOrchestration();

final counter   = counterFeature.addComponent(0);
final increment = counterFeature.addEvent();
final setTo     = counterFeature.addDataEvent<int>();

final onIncrement = counterFeature.addReactiveSystem(
  reactsTo: {increment},
  react: () {
    counter.value = counter.value + 1;
  },
);

final onSetTo = counterFeature.addReactiveSystem(
  reactsTo: {setTo},
  react: () {
    counter.value = setTo.data;
  },
);
```

Run the generator, and `counter_feature.g.dart` is produced with all entity classes, system classes, and the `CounterFeatureOrchestration` wired up automatically.

```bash
dart run build_runner build
```

---

## Orchestration Lifecycle

![Lifecycle diagram](https://raw.githubusercontent.com/FlameOfUdun/orchestra/main/assets/lifecycle_diagram.png)

---

## Testing

### Unit-testing a system

```dart
test('IncrementSystem increments counter', () {
  final orchestration = CounterOrchestration();
  final orchestrator = Orchestrator(orchestrations: {orchestration});

  orchestrator.get<IncrementEvent>().trigger();

  expect(orchestrator.get<CounterComponent>().value, 1);
});
```

### Testing reactive behavior

```dart
test('system reacts to event', () {
  final orchestration = CounterOrchestration();
  final orchestrator = Orchestrator(orchestrations: {orchestration});
  orchestrator.initialize();

  orchestrator.get<SetCounterEvent>().trigger(55);

  expect(orchestrator.get<CounterComponent>().value, 55);
});
```

### Testing components in isolation

```dart
test('component tracks previous value', () {
  final component = CounterComponent();

  component.update(10);
  component.update(20);

  expect(component.value, 20);
  expect(component.previous, 10);
});

test('component skips equal values', () {
  final component = CounterComponent();
  int notifyCount = 0;

  component.addListener(TestListener(() => notifyCount++));
  component.update(0); // equal — skipped

  expect(notifyCount, 0);
});
```

---

## Inspector DevTools Extension

Orchestra ships with a built-in DevTools extension. When running in debug mode, open Flutter DevTools and navigate to the **Orchestra** tab to inspect:

- All active orchestrators and orchestrations
- Live entity state and change history
- System execution logs and timing
- Reactive dependency graph

No setup required — the extension registers automatically on first `Orchestrator` construction.

---

## License

Apache License 2.0 — see the [LICENSE](LICENSE) file for details.

Copyright 2026 Ehsan Rashidi

---

**Issues**: [github.com/FlameOfUdun/orchestra/issues](https://github.com/FlameOfUdun/orchestra/issues)
**Discussions**: [github.com/FlameOfUdun/orchestra/discussions](https://github.com/FlameOfUdun/orchestra/discussions)
