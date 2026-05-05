# orchestra_flutter

[![pub package](https://img.shields.io/pub/v/orchestra_flutter.svg)](https://pub.dev/packages/orchestra_flutter)
[![Apache 2.0 License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](https://www.apache.org/licenses/LICENSE-2.0)
[![Flutter](https://img.shields.io/badge/Flutter-02569B?logo=flutter&logoColor=white)](https://flutter.dev)

Flutter widget integration for [`orchestra`](https://pub.dev/packages/orchestra). Provides the scope, reactive widgets, and handle API that connect the Orchestra ECS state management layer to the Flutter widget tree.

---

## Packages

| Package | Description |
|---|---|
| [`orchestra`](https://pub.dev/packages/orchestra) | Core ECS runtime — entities, systems, orchestrations |
| **`orchestra_flutter`** | Flutter widget integration — scope, reactive widgets, handle |
| [`orchestra_generator`](https://pub.dev/packages/orchestra_generator) | `build_runner` code generator for the `Composer` DSL |

---

## Installation

```yaml
dependencies:
  orchestra: ^1.0.0
  orchestra_flutter: ^1.0.0
```

---

## Setup

Wrap your app (or a subtree) with `OrchestraScope`, providing the orchestrations that should be active for that subtree:

```dart
import 'package:orchestra_flutter/orchestra_flutter.dart';

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return OrchestraScope(
      orchestrations: {
        CounterOrchestration(),
        AuthOrchestration(),
      },
      child: MaterialApp(
        home: HomePage(),
      ),
    );
  }
}
```

`OrchestraScope` creates an `Orchestrator`, initializes all orchestrations, and tears everything down when the widget is removed from the tree. If any orchestration contains `ExecuteSystem` or `CleanupSystem` instances, a `Ticker` is started automatically to drive them each frame.

The optional `name` parameter is useful for debugging and the Inspector DevTools extension:

```dart
OrchestraScope(
  name: 'MainScope',
  orchestrations: { ... },
  child: ...,
)
```

---

## Reactive Widgets

### OrchestraWidget

Extend `OrchestraWidget` for stateless-style widgets that rebuild automatically when watched entities change. The `build` method receives an `OrchestraHandle` alongside the standard `BuildContext`.

```dart
class CounterPage extends OrchestraWidget {
  const CounterPage({super.key});

  @override
  Widget build(BuildContext context, OrchestraHandle handle) {
    final counter   = handle.watch<CounterComponent>();
    final increment = handle.get<IncrementEvent>();

    return Scaffold(
      appBar: AppBar(title: const Text('Counter')),
      body: Center(
        child: Text('${counter.value}'),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: increment.trigger,
        child: const Icon(Icons.add),
      ),
    );
  }
}
```

### OrchestraBuilder

Functional alternative — useful for scoping reactivity to a small part of an existing widget tree without creating a new class.

```dart
OrchestraBuilder(
  builder: (BuildContext context, OrchestraHandle handle) {
    final counter = handle.watch<CounterComponent>();
    return Text('${counter.value}');
  },
)
```

### OrchestraStatefulWidget

For widgets that need both Orchestra access and local `State`. Access the handle via the `orchestra` getter on the state.

```dart
class SearchPage extends OrchestraStatefulWidget {
  const SearchPage({super.key});

  @override
  OrchestraState<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends OrchestraState<SearchPage> {
  final _controller = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final results = orchestra.watch<SearchResultsComponent>();

    return Column(
      children: [
        TextField(controller: _controller),
        Expanded(child: ResultsList(results.value)),
      ],
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
```

---

## OrchestraHandle

Every reactive widget receives an `OrchestraHandle`. It provides three ways to interact with entities:

### `get<T>()` — read without subscribing

Retrieves an entity without subscribing. The widget does **not** rebuild when this entity changes. Use for write-only access (e.g. triggering events).

```dart
final increment = handle.get<IncrementEvent>();
ElevatedButton(onPressed: increment.trigger, child: const Text('Add'))
```

### `watch<T>()` — read and subscribe

Retrieves an entity and subscribes to it. The widget **rebuilds automatically** when the entity changes.

```dart
final counter = handle.watch<CounterComponent>();
Text('${counter.value}') // re-renders on every counter change
```

### `listen<T>(callback)` — side effects without rebuilding

Subscribes to an entity and runs a callback instead of rebuilding. Useful for showing snackbars, navigating, or any side effect in response to a state change.

Callbacks are executed at the next frame boundary and batched with other listeners.

```dart
handle.listen<ErrorComponent>((error) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(error.value.message)),
  );
});
```

> Multiple calls to `listen` with the same entity type override the previous listener — only the most recent callback is kept.

---

## Lifecycle Callbacks

### `onEnter`

Called once at the next frame boundary after the widget is first built. Safe to trigger events or mutate components here.

```dart
handle.onEnter(() {
  handle.get<LoadDataEvent>().trigger();
});
```

### `onExit`

Called synchronously when the widget is disposed. Entities are still accessible.

```dart
handle.onExit(() {
  handle.get<CancelRequestEvent>().trigger();
});
```

Both are one-shot — subsequent calls within the same widget instance are silently ignored.

---

## Full Example

```dart
// orchestration
class TodoOrchestration extends Orchestration {
  TodoOrchestration() {
    add(TodoListComponent());
    add(LoadTodosEvent());
    add(AddTodoEvent());       // DataEvent<String>
    add(LoadTodosSystem());
    add(AddTodoSystem());
  }
}

// app setup
class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return OrchestraScope(
      orchestrations: {TodoOrchestration()},
      child: MaterialApp(home: TodoPage()),
    );
  }
}

// reactive widget
class TodoPage extends OrchestraWidget {
  const TodoPage({super.key});

  @override
  Widget build(BuildContext context, OrchestraHandle handle) {
    final todos     = handle.watch<TodoListComponent>();
    final addTodo   = handle.get<AddTodoEvent>();
    final loadTodos = handle.get<LoadTodosEvent>();

    handle.onEnter(() => loadTodos.trigger());

    handle.listen<TodoListComponent>((_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('List updated')),
      );
    });

    return Scaffold(
      appBar: AppBar(title: const Text('Todos')),
      body: ListView(
        children: todos.value.map((t) => ListTile(title: Text(t))).toList(),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => addTodo.trigger('New todo'),
        child: const Icon(Icons.add),
      ),
    );
  }
}
```

---

## License

Apache License 2.0 — see the [LICENSE](LICENSE) file for details.

Copyright 2026 Ehsan Rashidi

---

**Issues**: [github.com/FlameOfUdun/orchestra/issues](https://github.com/FlameOfUdun/orchestra/issues)
**Discussions**: [github.com/FlameOfUdun/orchestra/discussions](https://github.com/FlameOfUdun/orchestra/discussions)
