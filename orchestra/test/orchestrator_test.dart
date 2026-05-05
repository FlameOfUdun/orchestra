import 'package:test/test.dart';
import 'package:orchestra/src/base/export.dart';

class DummyComponent extends Component<int> {
  DummyComponent([super.value = 0]);
}

class DummyEvent extends Event {}

class DummyReactiveSystem extends ReactiveSystem {
  bool reacted = false;
  @override
  Set<Type> get interactsWith => {};
  @override
  Set<Type> get reactsTo => {DummyEvent};
  @override
  void react() => reacted = true;
}

class DummyOrchestration extends Orchestration {
  DummyOrchestration({
    Set<System>? systems,
  }) {
    add(DummyComponent());
    add(DummyEvent());
    systems?.forEach(add);
  }
}

class AnotherDummyOrchestration extends Orchestration {
  bool initialized = false;
  bool tornDown = false;
  bool cleaned = false;
  bool executed = false;

  AnotherDummyOrchestration({
    Set<System>? systems,
  }) {
    systems?.forEach(add);
    add(DummyReactiveSystem());
  }

  @override
  void initialize() {
    initialized = true;
  }

  @override
  void teardown() {
    tornDown = true;
  }

  @override
  void cleanup() {
    cleaned = true;
  }

  @override
  void execute(Duration elapsed) {
    executed = true;
  }
}

class ComponentReactiveSystem extends ReactiveSystem {
  bool reacted = false;
  @override
  Set<Type> get interactsWith => {};
  @override
  Set<Type> get reactsTo => {DummyComponent};
  @override
  void react() => reacted = true;
}

class LoggingSystem extends ReactiveSystem {
  @override
  Set<Type> get interactsWith => {};
  @override
  Set<Type> get reactsTo => {DummyEvent};
  @override
  void react() {
    log('system reacted');
  }
}

class LoggingOrchestration extends Orchestration {
  LoggingOrchestration() {
    add(DummyComponent());
    add(DummyEvent());
    add(LoggingSystem());
  }
}

void main() {
  group('Orchestrator', () {
    test('addOrchestration adds orchestration and entities', () {
      final orchestrator = Orchestrator(orchestrations: {});
      final orchestration = DummyOrchestration();
      orchestrator.addOrchestration(orchestration);
      expect(orchestrator.orchestrations, contains(orchestration));
      expect(orchestrator.entities.whereType<DummyComponent>().length, 1);
      expect(orchestrator.entities.whereType<DummyEvent>().length, 1);
    });

    test('get returns correct entity', () {
      final orchestrator = Orchestrator(orchestrations: {});
      final orchestration = DummyOrchestration();
      orchestrator.addOrchestration(orchestration);
      orchestrator.activate();
      final component = orchestrator.get<DummyComponent>();
      expect(component, isA<DummyComponent>());
    });

    test('get returns entity if found', () {
      final orchestrator = Orchestrator(orchestrations: {});
      final orchestration = DummyOrchestration();
      orchestrator.addOrchestration(orchestration);
      orchestrator.activate();
      final component = orchestrator.get<DummyComponent>();
      expect(component, isA<DummyComponent>());
    });

    test('onEntityChanged triggers reactive systems', () {
      final reactive = DummyReactiveSystem();
      final orchestration = DummyOrchestration(systems: {reactive});
      final orchestrator = Orchestrator(orchestrations: {orchestration});
      orchestrator.activate();
      orchestration.get<DummyEvent>().trigger();
      expect(reactive.reacted, isTrue);
    });

    test('entities and get work across multiple orchestrations', () {
      final orchestrator = Orchestrator(orchestrations: {});
      final orchestration1 = DummyOrchestration();
      final orchestration2 = DummyOrchestration();
      orchestrator.addOrchestration(orchestration1);
      orchestrator.addOrchestration(orchestration2);
      orchestrator.activate();
      expect(orchestrator.entities.whereType<DummyComponent>().length, 2);
      expect(orchestrator.get<DummyComponent>(), isA<DummyComponent>());
    });

    test('get returns first found for duplicate types', () {
      final orchestrator = Orchestrator(orchestrations: {});
      final orchestration1 = DummyOrchestration();
      final orchestration2 = DummyOrchestration();
      orchestrator.addOrchestration(orchestration1);
      orchestrator.addOrchestration(orchestration2);
      orchestrator.activate();
      final entity = orchestrator.get<DummyComponent>();
      expect(
          entity,
          anyOf(orchestration1.get<DummyComponent>(),
              orchestration2.get<DummyComponent>()));
    });

    test('multiple reactive systems for same entity type are triggered', () {
      final reactive1 = DummyReactiveSystem();
      final reactive2 = DummyReactiveSystem();
      final orchestration = DummyOrchestration(systems: {reactive1, reactive2});
      final orchestrator = Orchestrator(orchestrations: {orchestration});
      orchestrator.activate();
      orchestration.get<DummyEvent>().trigger();
      expect(reactive1.reacted, isTrue);
      expect(reactive2.reacted, isTrue);
    });

    test('reactive systems only trigger for correct entity types', () {
      final eventReactiveSystem = DummyReactiveSystem();
      final componentReactiveSystem = ComponentReactiveSystem();
      final orchestration =
          DummyOrchestration(systems: {eventReactiveSystem, componentReactiveSystem});
      final orchestrator = Orchestrator(orchestrations: {orchestration});
      orchestrator.activate();

      // Trigger event - only event reactive system should react
      orchestration.get<DummyEvent>().trigger();
      expect(eventReactiveSystem.reacted, isTrue);
      expect(componentReactiveSystem.reacted, isFalse);

      // Reset and trigger component
      eventReactiveSystem.reacted = false;
      orchestration.get<DummyComponent>().update(42);
      expect(eventReactiveSystem.reacted, isFalse);
      expect(componentReactiveSystem.reacted, isTrue);
    });

    test('orchestrator tracks entities from multiple orchestrations correctly', () {
      final orchestrator = Orchestrator(orchestrations: {});
      final orchestration1 = DummyOrchestration();
      final orchestration2 = AnotherDummyOrchestration();
      orchestrator.addOrchestration(orchestration1);
      orchestrator.addOrchestration(orchestration2);
      orchestrator.activate();

      final allEntities = orchestrator.entities;
      expect(allEntities.whereType<DummyComponent>().length, 1);
      expect(allEntities.whereType<DummyEvent>().length, 1);
      expect(allEntities.length, 2);
    });

    test('get searches orchestrations in order', () {
      final orchestrator = Orchestrator(orchestrations: {});
      final orchestration1 = DummyOrchestration();
      final orchestration2 = DummyOrchestration();
      orchestrator.addOrchestration(orchestration1);
      orchestrator.addOrchestration(orchestration2);
      orchestrator.activate();

      final component = orchestrator.get<DummyComponent>();
      expect(component, equals(orchestration1.get<DummyComponent>()));
    });

    test('entity change triggers systems across all orchestrations', () {
      final reactive1 = DummyReactiveSystem();
      final reactive2 = DummyReactiveSystem();

      final orchestration1 = DummyOrchestration(systems: {reactive1});
      final orchestration2 = AnotherDummyOrchestration(systems: {reactive2});

      final orchestrator = Orchestrator(orchestrations: {orchestration1, orchestration2});
      orchestrator.activate();

      orchestration1.get<DummyEvent>().trigger();
      expect(reactive1.reacted, isTrue);
      expect(reactive2.reacted, isTrue);
    });

    test('orchestrations property returns unmodifiable set', () {
      final orchestrator = Orchestrator(orchestrations: {});
      final orchestration = DummyOrchestration();
      orchestrator.addOrchestration(orchestration);
      orchestrator.activate();

      final orchestrations = orchestrator.orchestrations;
      expect(orchestrations, contains(orchestration));
      expect(orchestrations.length, 1);
    });
  });

  group('log context', () {
    test('log from system includes orchestrationName and systemName', () {
      final orchestrator = Orchestrator(orchestrations: {LoggingOrchestration()});
      // Orchestrator constructor calls activate() — reactive systems are already registered
      final event = orchestrator.get<DummyEvent>();
      orchestrator.initialize();
      event.trigger();

      final logs = orchestrator.logs;
      expect(logs, isNotEmpty);

      final systemLog = logs.firstWhere(
        (l) => l.message == 'system reacted',
        orElse: () => throw StateError('log not found'),
      );
      expect(systemLog.orchestrationName, equals('LoggingOrchestration'));
      expect(systemLog.systemName, equals('LoggingSystem'));

      orchestrator.deactivate();
    });

    test('log from entity includes orchestrationName but not systemName', () {
      final orchestrator = Orchestrator(orchestrations: {DummyOrchestration()});
      // Orchestrator constructor calls activate() — reactive systems are already registered
      final event = orchestrator.get<DummyEvent>();
      event.trigger();

      final logs = orchestrator.logs;
      expect(logs, isNotEmpty);

      // Event.trigger() calls log() on the entity, which should carry orchestrationName
      final triggerLog = logs.firstWhere(
        (l) => l.message.contains('triggered'),
        orElse: () => throw StateError('trigger log not found'),
      );
      expect(triggerLog.orchestrationName, equals('DummyOrchestration'));
      expect(triggerLog.systemName, isNull);

      orchestrator.deactivate();
    });
  });
}
