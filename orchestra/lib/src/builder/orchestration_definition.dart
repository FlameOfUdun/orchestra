part of 'export.dart';

final class OrchestrationDefinition {
  OrchestrationDefinition._();

  ComponentDefinition<T> addComponent<T>(T initialValue) {
    return ComponentDefinition<T>._(initialValue);
  }

  EventDefinition addEvent() {
    return EventDefinition._();
  }

  DataEventDefinition<T> addDataEvent<T>() {
    return DataEventDefinition<T>._();
  }

  DependencyDefinition<T> addDependency<T>(T value) {
    return DependencyDefinition<T>._(value);
  }

  ReactiveSystemDefinition addReactiveSystem({
    bool Function()? reactsIf,
    required Set<ListenableEntityDefinition> reactsTo,
    required void Function() react,
  }) {
    return ReactiveSystemDefinition._(
      reactsIf: reactsIf,
      reactsTo: reactsTo,
      react: react,
    );
  }

  ExecuteSystemDefinition addExecuteSystem({
    bool Function()? executesIf,
    required void Function(Duration elapsed) execute,
  }) {
    return ExecuteSystemDefinition._(
      executesIf: executesIf,
      execute: execute,
    );
  }

  CleanupSystemDefinition addCleanupSystem({
    bool Function()? cleansIf,
    required void Function() cleanup,
  }) {
    return CleanupSystemDefinition._(
      cleansIf: cleansIf,
      cleanup: cleanup,
    );
  }

  TeardownSystemDefinition addTeardownSystem({
    bool Function()? teardownsIf,
    required void Function() teardown,
  }) {
    return TeardownSystemDefinition._(
      teardownsIf: teardownsIf,
      teardown: teardown,
    );
  }

  InitializeSystemDefinition addInitializeSystem({
    required void Function() initialize,
  }) {
    return InitializeSystemDefinition._(
      initialize: initialize,
    );
  }
}
