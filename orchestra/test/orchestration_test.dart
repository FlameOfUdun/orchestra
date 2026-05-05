import 'package:test/test.dart';
import 'package:orchestra/src/base/export.dart';

class DummyComponent extends Component<int> {
  DummyComponent([super.value = 0]);
}

class DummyEvent extends Event {}

class DummyInitSystem extends InitializeSystem {
  bool initialized = false;
  @override
  Set<Type> get interactsWith => {};
  @override
  void initialize() => initialized = true;
}

class DummyTeardownSystem extends TeardownSystem {
  bool tornDown = false;
  @override
  Set<Type> get interactsWith => {};
  @override
  void teardown() => tornDown = true;
}

class DummyCleanupSystem extends CleanupSystem {
  bool cleaned = false;
  @override
  Set<Type> get interactsWith => {};
  @override
  void cleanup() => cleaned = true;
}

class DummyExecuteSystem extends ExecuteSystem {
  Duration? lastElapsed;
  @override
  Set<Type> get interactsWith => {};
  @override
  void execute(Duration elapsed) => lastElapsed = elapsed;
}

class DummyReactiveSystem extends ReactiveSystem {
  bool reacted = false;
  @override
  Set<Type> get interactsWith => {};
  @override
  Set<Type> get reactsTo => {DummyEvent};
  @override
  void react() => reacted = true;
}

class TestFeature extends Orchestration {
  TestFeature();
}

class MultiReactiveSystem extends ReactiveSystem {
  bool reacted = false;
  @override
  Set<Type> get interactsWith => {};
  @override
  Set<Type> get reactsTo => {DummyEvent, DummyComponent};
  @override
  void react() => reacted = true;
}

void main() {
  group('Orchestration', () {
    test('add and get', () {
      final feature = TestFeature();
      feature.add(DummyComponent());
      feature.add(DummyEvent());
      expect(feature.get<DummyComponent>(), isA<DummyComponent>());
      expect(feature.get<DummyEvent>(), isA<DummyEvent>());
    });

    test('add registers all system types', () {
      final feature = TestFeature();
      final init = DummyInitSystem();
      final teardown = DummyTeardownSystem();
      final cleanup = DummyCleanupSystem();
      final execute = DummyExecuteSystem();
      final reactive = DummyReactiveSystem();
      feature.add(init);
      feature.add(teardown);
      feature.add(cleanup);
      feature.add(execute);
      feature.add(reactive);
      expect(feature.initializeSystems, contains(init));
      expect(feature.teardownSystems, contains(teardown));
      expect(feature.cleanupSystems, contains(cleanup));
      expect(feature.executeSystems, contains(execute));
      expect(feature.reactiveSystems, contains(reactive));
    });

    test('initialize calls all InitializeSystems', () {
      final feature = TestFeature();
      final init = DummyInitSystem();
      feature.add(init);
      feature.initialize();
      expect(init.initialized, isTrue);
    });

    test('teardown calls all TeardownSystems', () {
      final feature = TestFeature();
      final teardown = DummyTeardownSystem();
      feature.add(teardown);
      feature.teardown();
      expect(teardown.tornDown, isTrue);
    });

    test('cleanup calls all CleanupSystems', () {
      final feature = TestFeature();
      final cleanup = DummyCleanupSystem();
      feature.add(cleanup);
      feature.cleanup();
      expect(cleanup.cleaned, isTrue);
    });

    test('execute calls all ExecuteSystems', () {
      final feature = TestFeature();
      final execute = DummyExecuteSystem();
      feature.add(execute);
      final duration = Duration(milliseconds: 123);
      feature.execute(duration);
      expect(execute.lastElapsed, duration);
    });

    test('reactiveSystems map is correct', () {
      final feature = TestFeature();
      final reactive = DummyReactiveSystem();
      feature.add(reactive);
      expect(feature.reactiveSystems, contains(reactive));
    });

    test('systemsCount returns correct total', () {
      final feature = TestFeature();
      feature.add(DummyInitSystem());
      feature.add(DummyTeardownSystem());
      feature.add(DummyCleanupSystem());
      feature.add(DummyExecuteSystem());
      feature.add(DummyReactiveSystem());
      expect(feature.systemsCount, 5);
    });

    test('get throws StateError for non-existent entity type', () {
      final feature = TestFeature();
      expect(() => feature.get<DummyComponent>(), throwsStateError);
    });

    test('multiple entities of same type returns first', () {
      final feature = TestFeature();
      final component1 = DummyComponent(10);
      final component2 = DummyComponent(20);
      feature.add(component1);
      feature.add(component2);
      final retrieved = feature.get<DummyComponent>();
      expect(retrieved, equals(component1));
    });

    test('multiple systems of same type are all registered', () {
      final feature = TestFeature();
      final init1 = DummyInitSystem();
      final init2 = DummyInitSystem();
      feature.add(init1);
      feature.add(init2);
      expect(feature.initializeSystems.length, 2);
      expect(feature.initializeSystems, contains(init1));
      expect(feature.initializeSystems, contains(init2));
    });

    test('multiple reactive systems for same event type', () {
      final feature = TestFeature();
      final reactive1 = DummyReactiveSystem();
      final reactive2 = DummyReactiveSystem();
      feature.add(reactive1);
      feature.add(reactive2);
      expect(feature.reactiveSystems.length, 2);
      expect(feature.reactiveSystems, contains(reactive1));
      expect(feature.reactiveSystems, contains(reactive2));
    });

    test('lifecycle methods work with multiple systems', () {
      final feature = TestFeature();
      final init1 = DummyInitSystem();
      final init2 = DummyInitSystem();
      final teardown1 = DummyTeardownSystem();
      final teardown2 = DummyTeardownSystem();
      feature.add(init1);
      feature.add(init2);
      feature.add(teardown1);
      feature.add(teardown2);

      feature.initialize();
      expect(init1.initialized, isTrue);
      expect(init2.initialized, isTrue);

      feature.teardown();
      expect(teardown1.tornDown, isTrue);
      expect(teardown2.tornDown, isTrue);
    });

    test('empty feature lifecycle methods work', () {
      final feature = TestFeature();
      expect(() => feature.initialize(), returnsNormally);
      expect(() => feature.teardown(), returnsNormally);
      expect(() => feature.cleanup(), returnsNormally);
      expect(() => feature.execute(Duration.zero), returnsNormally);
    });

    test('systemsCount is zero for empty feature', () {
      final feature = TestFeature();
      expect(feature.systemsCount, 0);
    });

    test('entities set contains all added entities', () {
      final feature = TestFeature();
      final component = DummyComponent();
      final event = DummyEvent();
      feature.add(component);
      feature.add(event);
      expect(feature.entities.length, 2);
      expect(feature.entities, contains(component));
      expect(feature.entities, contains(event));
    });

    test('reactive system with multiple reactsTo types', () {
      final feature = TestFeature();
      final multiReactiveSystem = MultiReactiveSystem();
      feature.add(multiReactiveSystem);
      expect(feature.reactiveSystems, contains(multiReactiveSystem));
      expect(feature.reactiveSystems, contains(multiReactiveSystem));
    });

    test('add registers CleanupSystem', () {
      final feature = TestFeature();
      final cleanup = DummyCleanupSystem();
      feature.add(cleanup);
      expect(feature.cleanupSystems, contains(cleanup));
    });

    test('add does not throw for a single ReactiveSystem', () {
      final feature = TestFeature();
      final reactive = DummyReactiveSystem();
      expect(() => feature.add(reactive), returnsNormally);
      expect(feature.reactiveSystems, contains(reactive));
    });
  });
}
