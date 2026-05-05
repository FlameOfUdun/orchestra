# Orchestra Generator

[![pub package](https://img.shields.io/pub/v/orchestra_generator.svg)](https://pub.dev/packages/orchestra_generator)
[![Apache 2.0 License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](https://www.apache.org/licenses/LICENSE-2.0)
[![Flutter](https://img.shields.io/badge/Flutter-02569B?logo=flutter&logoColor=white)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-0175C2?logo=dart&logoColor=white)](https://dart.dev)

A `build_runner` code generator for the [`orchestra`](https://pub.dev/packages/orchestra) package. Write your orchestrations declaratively using plain Dart and let the generator produce all the boilerplate class definitions automatically.

---

## Table of Contents

- [Overview](#overview)
- [How It Works](#how-it-works)
- [Installation](#installation)
- [Setup](#setup)
- [Quick Start](#quick-start)
- [Entity Types](#entity-types)
- [System Types](#system-types)
- [Guard Conditions](#guard-conditions)
- [Helper Functions](#helper-functions)
- [Cross-File Orchestrations](#cross-file-orchestrations)
- [Generated Output](#generated-output)
- [Running the Generator](#running-the-generator)
- [Rules & Constraints](#rules--constraints)

---

## Overview

The `orchestra_generator` package analyses your orchestra declaration files using the Dart analyzer and generates fully-typed, boilerplate-free orchestration classes. All entity variables, component mutations, event triggers, and system logic you write declaratively are automatically translated into proper class definitions that extend the base classes from `orchestra`.

Instead of writing:

```dart
// Manually written boilerplate
final class IsLoadingComponent extends Component<bool> {
  IsLoadingComponent() : super(false);
}

final class DataFetchedEvent extends Event {}

final class LoadingReactiveSystem extends ReactiveSystem {
  @override
  Set get reactsTo {
    return const {DataFetchedEvent};
  }

  @override
  Set get interactsWith {
    return const {IsLoadingComponent};
  }

  @override
  void react() {
    get<IsLoadingComponent>().value = false;
  }
}

final class AuthFeatureOrchestration extends Orchestration {
  AuthFeatureOrchestration() {
    add(IsLoadingComponent());
    add(DataFetchedEvent());
    add(LoadingReactiveSystem());
  }
}
```

You simply write:

```dart
// Declarative definition — generator handles everything else
final authFeature = Composer.createOrchestration();
final isLoading = authFeature.addComponent(false);
final dataFetched = authFeature.addEvent();

final onDataFetched = authFeature.addReactiveSystem(
  reactsTo: {dataFetched},
  react: () {
    isLoading.value = false;
  },
);
```

---

## How It Works

The generator runs as a `build_runner` builder and processes each `.dart` file in your project:

1. **Feature discovery** — `OrchestrationVisitor` finds every `Composer.createOrchestration()` call and registers it.
2. **Entity discovery** — `EntityVisitor` finds all `addComponent`, `addEvent`, `addDataEvent`, and `addDependency` calls attached to a known feature.
3. **System discovery** — `SystemVisitor` finds all `addReactiveSystem`, `addExecuteSystem`, `addCleanupSystem`, `addTeardownSystem`, and `addInitializeSystem` calls.
4. **AST rewriting** — All expression bodies are rewritten using the Dart AST, replacing local variable references with proper `get<Type>()` calls.
5. **`interactsWith` inference** — The generator automatically detects which entities each system mutates (via `.value =`, `.update()`, or `.trigger()`) and populates the `interactsWith` set.
6. **Code generation** — A formatted `.g.dart` `part` file is written alongside each source file.

---

## Installation

Add both the runtime package and this generator to your `pubspec.yaml`:

```yaml
dependencies:
  orchestra: ^<latest_version>

dev_dependencies:
  orchestra_generator: ^<latest_version>
  build_runner: ^<compatible_version>
```

---

## Setup

### 1. Register the builder

Create a `build.yaml` file at the root of your project:

```yaml
targets:
  $default:
    builders:
      orchestra_generator:
        enabled: true
```

### 2. Add the `part` directive

In every file where you declare a feature, add a `part` directive pointing to the generated file:

```dart
// my_feature.dart
part 'my_feature.g.dart';
```

---

## Quick Start

```dart
// user_profile_feature.dart
import 'package:orchestra/orchestra.dart';

part 'user_profile_feature.g.dart';

// 1. Create a feature (one per file)
final userProfileFeature = Composer.createOrchestration();

// 2. Declare entities
final username      = userProfileFeature.addComponent('');
final isLoggedIn    = userProfileFeature.addComponent(false);
final loggedIn      = userProfileFeature.addEvent();
final errorOccurred = userProfileFeature.addDataEvent<String>();

// 3. Declare systems
final onLogin = userProfileFeature.addReactiveSystem(
  reactsTo: {loggedIn},
  react: () {
    isLoggedIn.value = true;
  },
);

final onError = userProfileFeature.addReactiveSystem(
  reactsTo: {errorOccurred},
  react: () {
    isLoggedIn.value = false;
    _logError(errorOccurred.data);
  },
);

void _logError(String message) {
  // handle error
}

final sessionTimer = userProfileFeature.addExecuteSystem(
  executesIf: () {
    return isLoggedIn.value;
  },
  execute: (Duration elapsed) {
    sessionDuration.value += elapsed.inSeconds;
  },
);
```

Run the generator (see [Running the Generator](#running-the-generator)) and `user_profile_feature.g.dart` will contain all the concrete class definitions.

---

## Entity Types

| Method | Generated Base Class | Description |
| - | - | - |
| `addComponent<T>(defaultValue)` | `Component<T>` | Stateful data holder with `.value`, `.previous`, `.updatedAt` |
| `addEvent()` | `Event` | Signal with no payload; carries a `.triggeredAt` timestamp |
| `addDataEvent<T>()` | `DataEvent<T>` | Signal that carries a typed `.data` payload |
| `addDependency<T>(value)` | `Dependency<T>` | Externally injected value, accessible across systems |

### Component

```dart
final pageIndex    = myFeature.addComponent(0);
final searchQuery  = myFeature.addComponent('');
final currentUser  = myFeature.addComponent<User?>(null);
```

Accessing component state in a system body:

```dart
react: () {
  pageIndex.value;                                // current value
  pageIndex.previous;                             // value before last update
  pageIndex.updatedAt;                            // DateTime of last update
  pageIndex.value = 2;                            // direct assignment
  pageIndex.update(2, notify: true, force: false); // explicit update with options
},
```

### Events

```dart
final formSubmitted  = myFeature.addEvent();                  // no payload
final userSelected   = myFeature.addDataEvent<String>();      // carries a String id

// In a system body:
react: () {
  formSubmitted.trigger();                // fire the event
  userSelected.trigger('user-123');       // fire with payload
  userSelected.data;                      // read the payload
  userSelected.triggeredAt;              // DateTime last triggered
},
```

### Dependency

```dart
final apiService = myFeature.addDependency<ApiService>(ApiService());
```

---

## System Types

### Reactive System

Triggers in response to one or more entities changing (component updated or event fired).

```dart
final onSubmit = myFeature.addReactiveSystem(
  reactsTo: {formSubmitted},
  react: () {
    isLoading.value = true;
    submitForm.trigger();
  },
);
```

### Execute System

Runs every tick/frame. Receives the `Duration` elapsed since the last tick.

```dart
final countdownSystem = myFeature.addExecuteSystem(
  execute: (Duration elapsed) {
    timeRemaining.value -= elapsed.inSeconds;
  },
);
```

### Cleanup System

Runs to reset or flush transient per-frame state.

```dart
final clearNotifications = myFeature.addCleanupSystem(
  cleanup: () {
    pendingNotificationCount.value = 0;
  },
);
```

### Initialize System

Runs once when the feature is first initialized.

```dart
final setup = myFeature.addInitializeSystem(
  initialize: () {
    pageIndex.value = 0;
    isLoading.value = false;
  },
);
```

### Teardown System

Runs when the feature is being disposed.

```dart
final dispose = myFeature.addTeardownSystem(
  teardown: () {
    currentUser.value = null;
    isLoggedIn.value = false;
  },
);
```

---

## Guard Conditions

Every system type (except teardown) supports an optional guard. The system only executes when the guard returns `true`.

| System | Guard Parameter |
| - | - |
| `addReactiveSystem` | `reactsIf` |
| `addExecuteSystem` | `executesIf` |
| `addCleanupSystem` | `cleansIf` |

```dart
final onUserSelected = myFeature.addReactiveSystem(
  reactsTo: {userSelected},
  reactsIf: () {
    return isLoggedIn.value;
  },   // only react when authenticated
  react: () {
    activeUserId.value = userSelected.data;
  },
);

final countdownSystem = myFeature.addExecuteSystem(
  executesIf: () {
    return timeRemaining.value > 0;
  },  // stop when timer reaches zero
  execute: (Duration elapsed) {
    timeRemaining.value -= elapsed.inSeconds;
  },
);
```

---

## Helper Functions

You can call top-level helper functions from within system bodies. The generator resolves them automatically — including transitive call chains — and rewrites all entity references before inlining them into the generated class.

```dart
final onSubmit = myFeature.addReactiveSystem(
  reactsTo: {formSubmitted},
  react: () {
    _processForm();
  },
);

void _processForm() {
  final sanitized = _sanitizeInput(inputText.value);
  inputText.value = sanitized;
}

String _sanitizeInput(String raw) {
  return raw.trim().toLowerCase();
}
```

The generator walks the call graph from `_processForm`, discovers `_sanitizeInput`, rewrites all entity accesses (e.g. `inputText` → `get<InputTextComponent>()`), and includes both helpers in the generated system class.

---

## Cross-File Orchestrations

Entities declared in imported files are fully resolved. When feature B imports feature A, the generator scans all transitive imports and resolves entity references across file boundaries.

```dart
// session_feature.dart
import 'package:orchestra/orchestra.dart';

part 'session_feature.g.dart';

final sessionFeature = Composer.createOrchestration();
final authToken = sessionFeature.addComponent<String?>(null);
```

```dart
// settings_feature.dart
import 'package:orchestra/orchestra.dart';
import 'session_feature.dart';

part 'settings_feature.g.dart';

final settingsFeature = Composer.createOrchestration();
final settingsSaved = settingsFeature.addEvent();

final onSettingsSaved = settingsFeature.addReactiveSystem(
  reactsTo: {settingsSaved},
  react: () {
    // cross-file entity reference — fully supported
    if (authToken.value == null) return;
    syncSettings.trigger();
  },
);
```

---

## Generated Output

For the quick-start example, the generator produces `user_profile_feature.g.dart`:

```dart
// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_profile_feature.dart';

final class UsernameComponent extends Component<String> {
  UsernameComponent() : super('');
}

final class IsLoggedInComponent extends Component<bool> {
  IsLoggedInComponent() : super(false);
}

final class LoggedInEvent extends Event {}

final class ErrorOccurredEvent extends DataEvent<String> {}

final class OnLoginReactiveSystem extends ReactiveSystem {
  @override
  Set get reactsTo {
    return const {LoggedInEvent};
  }

  @override
  Set get interactsWith {
    return const {IsLoggedInComponent};
  }

  @override
  void react() {
    get<IsLoggedInComponent>().value = true;
  }
}

final class OnErrorReactiveSystem extends ReactiveSystem {
  @override
  Set get reactsTo {
    return const {ErrorOccurredEvent};
  }

  @override
  Set get interactsWith {
    return const {IsLoggedInComponent};
  }

  @override
  void react() {
    get<IsLoggedInComponent>().value = false;
    _logError(get<ErrorOccurredEvent>().data);
  }

  void _logError(String message) {
    // handle error
  }
}

final class UserProfileFeatureOrchestration extends Orchestration {
  UserProfileFeatureOrchestration() {
    add(UsernameComponent());
    add(IsLoggedInComponent());
    add(LoggedInEvent());
    add(ErrorOccurredEvent());
    add(OnLoginReactiveSystem());
    add(OnErrorReactiveSystem());
  }
}
```

Key things to note in the generated output:

- All local variable references (e.g. `isLoggedIn`, `errorOccurred`) are rewritten to `get<Type>()` calls.
- The `interactsWith` set is **automatically inferred** — you never write it manually.
- Guard conditions become getter overrides on the generated class.
- Helper functions are resolved, rewritten, and inlined into the system class.
- The feature class registers all entities and systems in its constructor.

---

## Running the Generator

**One-time build:**

```bash
dart run build_runner build
```

**Watch mode** (re-generates on every file save):

```bash
dart run build_runner watch
```

**Clean conflicting outputs first:**

```bash
dart run build_runner build --delete-conflicting-outputs
```

Generated `.g.dart` files are deterministic and should be **committed to version control**.

---

## Rules & Constraints

- **One orchestration per file** — each `.dart` file must contain exactly one `Composer.createOrchestration()` call. Files with more than one orchestration log a warning and produce no output.
- **Function body required** — `react`, `execute`, `cleanup`, `initialize`, `teardown`, and guard parameters must be function body expressions, not references to named functions and not lambdas.
- **Top-level declarations only** — orchestrations, entities, and systems must be top-level variables, not members of a class or locals inside a function.
- **`part` directive required** — the source file must include `part '<filename>.g.dart';` to use the generated code.
- **Auto-naming** — missing suffixes are appended automatically: `isLoading` → `IsLoadingComponent`, `formSubmitted` → `FormSubmittedEvent`, `onLogin` → `OnLoginReactiveSystem`.
