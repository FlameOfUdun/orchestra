import 'package:orchestra/orchestra.dart';

// ---------------------------------------------------------------------------
// Entities
// ---------------------------------------------------------------------------

/// Holds the current counter value.
final class CounterValue extends Component<int> {
  CounterValue([super.value = 0]);
}

/// Fired when the user wants to increment the counter.
final class IncrementEvent extends Event {}

/// Fired when the user wants to decrement the counter.
final class DecrementEvent extends Event {}

/// Fired when the user wants to reset the counter to zero.
final class ResetEvent extends Event {}

// ---------------------------------------------------------------------------
// Systems
// ---------------------------------------------------------------------------

/// Logs a message when the orchestration starts.
final class CounterInitSystem extends InitializeSystem {
  @override
  Set<Type> get interactsWith => {CounterValue};

  @override
  void initialize() {
    final counter = get<CounterValue>();
    log('Counter initialized — starting value: ${counter.value}');
  }
}

/// Increments [CounterValue] by 1 when [IncrementEvent] is triggered.
final class IncrementSystem extends ReactiveSystem {
  @override
  Set<Type> get interactsWith => {CounterValue};

  @override
  Set<Type> get reactsTo => {IncrementEvent};

  @override
  void react() {
    get<CounterValue>().value++;
    log('Incremented → ${get<CounterValue>().value}');
  }
}

/// Decrements [CounterValue] by 1 when [DecrementEvent] is triggered.
final class DecrementSystem extends ReactiveSystem {
  @override
  Set<Type> get interactsWith => {CounterValue};

  @override
  Set<Type> get reactsTo => {DecrementEvent};

  @override
  void react() {
    get<CounterValue>().value--;
    log('Decremented → ${get<CounterValue>().value}');
  }
}

/// Resets [CounterValue] to zero when [ResetEvent] is triggered.
final class ResetSystem extends ReactiveSystem {
  @override
  Set<Type> get interactsWith => {CounterValue};

  @override
  Set<Type> get reactsTo => {ResetEvent};

  @override
  void react() {
    get<CounterValue>().value = 0;
    log('Reset → 0');
  }
}

// ---------------------------------------------------------------------------
// Orchestration
// ---------------------------------------------------------------------------

/// Bundles all counter entities and systems into one orchestration.
final class CounterOrchestration extends Orchestration {
  CounterOrchestration() {
    add(CounterValue());
    add(IncrementEvent());
    add(DecrementEvent());
    add(ResetEvent());

    add(CounterInitSystem());
    add(IncrementSystem());
    add(DecrementSystem());
    add(ResetSystem());
  }
}
