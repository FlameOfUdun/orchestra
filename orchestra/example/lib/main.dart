import 'package:orchestra/orchestra.dart';

import 'features/counter_feature.dart';

void main() async {
  // Create the orchestrator with the counter orchestration.
  final orchestrator = Orchestrator(
    name: 'CounterApp',
    orchestrations: {CounterOrchestration()},
  );

  // Activate the orchestrator to start the orchestration and systems.
  orchestrator.activate();

  // Retrieve the shared entities from the orchestrator.
  final counter = orchestrator.get<CounterValue>();
  final increment = orchestrator.get<IncrementEvent>();
  final decrement = orchestrator.get<DecrementEvent>();
  final reset = orchestrator.get<ResetEvent>();

  // Print current counter value whenever it changes.
  counter.addListener(_CounterPrinter());

  print('Orchestra core example — interactive counter');
  print('Commands:  +  increment   -  decrement   r  reset   q  quit\n');

  print('Counter will be incremented in 2 seconds...');
  await Future.delayed(const Duration(seconds: 2));
  increment.trigger();
  print('Counter incremented!');

  print('Counter will be reset in 2 seconds...');
  await Future.delayed(const Duration(seconds: 2));
  reset.trigger();
  print('Counter reset!');

  print('Counter will be decremented in 2 seconds...');
  await Future.delayed(const Duration(seconds: 2));
  decrement.trigger();
  print('Counter decremented!');
}

final class _CounterPrinter implements EntityListener {
  @override
  void onEntityChanged(Entity entity) {
    final counter = entity as CounterValue;
    print('Counter: ${counter.value}');
  }
}
