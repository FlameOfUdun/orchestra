import 'package:flutter_test/flutter_test.dart';
import 'package:orchestra/src/base/export.dart';

class TestComponent extends Component<int> {
  TestComponent([super.value = 0]);
}

class TestEvent extends Event {
  TestEvent() : super();
}

class DummyDependency extends Dependency<int> {
  DummyDependency() : super(42);
}

class DummyDataEvent extends DataEvent<String> {}

class DummyOrchestrationForDep extends Orchestration {
  DummyOrchestrationForDep() {
    add(DummyDependency());
  }
}

class TestListener implements EntityListener {
  final void Function() onChanged;

  TestListener(this.onChanged);

  @override
  void onEntityChanged(Entity entity) => onChanged();
}

void main() {
  group('Component', () {
    test('notifies listeners on change', () {
      final component = TestComponent();
      bool notified = false;
      final listener = TestListener(() => notified = true);
      component.addListener(listener);
      component.update(1);
      expect(notified, isTrue);
    });

    test('does not notify if value unchanged', () {
      final component = TestComponent(5);
      bool notified = false;
      final listener = TestListener(() => notified = true);
      component.addListener(listener);
      component.update(5);
      expect(notified, isFalse);
    });

    test('removes listener', () {
      final component = TestComponent();
      bool notified = false;
      final listener = TestListener(() => notified = true);
      component.addListener(listener);
      component.removeListener(listener);
      component.update(2);
      expect(notified, isFalse);
    });
  });

  group('Event', () {
    test('notifies listeners on trigger', () {
      final event = TestEvent();
      bool notified = false;
      final listener = TestListener(() => notified = true);
      event.addListener(listener);
      event.trigger();
      expect(notified, isTrue);
    });

    test('can trigger multiple times', () {
      final event = TestEvent();
      int notificationCount = 0;
      final listener = TestListener(() => notificationCount++);
      event.addListener(listener);
      event.trigger();
      event.trigger();
      event.trigger();
      expect(notificationCount, 3);
    });

    test('notifies multiple listeners', () {
      final event = TestEvent();
      bool listener1Notified = false;
      bool listener2Notified = false;
      final listener1 = TestListener(() => listener1Notified = true);
      final listener2 = TestListener(() => listener2Notified = true);
      event.addListener(listener1);
      event.addListener(listener2);
      event.trigger();
      expect(listener1Notified, isTrue);
      expect(listener2Notified, isTrue);
    });
  });

  group('Component Additional Tests', () {
    test('notifies multiple listeners', () {
      final component = TestComponent();
      bool listener1Notified = false;
      bool listener2Notified = false;
      final listener1 = TestListener(() => listener1Notified = true);
      final listener2 = TestListener(() => listener2Notified = true);
      component.addListener(listener1);
      component.addListener(listener2);
      component.update(10);
      expect(listener1Notified, isTrue);
      expect(listener2Notified, isTrue);
    });

    test('can handle rapid value changes', () {
      final component = TestComponent();
      int notificationCount = 0;
      final listener = TestListener(() => notificationCount++);
      component.addListener(listener);
      component.update(1);
      component.update(2);
      component.update(3);
      component.update(4);
      expect(notificationCount, 4);
    });

    test('getter returns correct value', () {
      final component = TestComponent(42);
      expect(component.value, 42);
      component.update(100);
      expect(component.value, 100);
    });

    test('removing non-existent listener does not throw', () {
      final component = TestComponent();
      final listener = TestListener(() {});
      expect(() => component.removeListener(listener), returnsNormally);
    });

    test('adding same listener multiple times only adds once', () {
      final component = TestComponent();
      int notificationCount = 0;
      final listener = TestListener(() => notificationCount++);
      component.addListener(listener);
      component.addListener(listener);
      component.update(5);
      expect(notificationCount, 1);
    });
  });

  group('Dependency', () {
    test('is attached to orchestration after addEntity', () {
      final orchestration = DummyOrchestrationForDep();
      final dep = orchestration.getType(DummyDependency) as DummyDependency;
      expect(dep.orchestration, isNotNull);
      expect(dep.isAttached, isTrue);
      expect(dep.orchestration, same(orchestration));
      expect(dep.identifier, contains('DummyOrchestrationForDep'));
    });
  });

  group('Entity Base Tests', () {
    test('listeners set is properly managed', () {
      final component = TestComponent();
      final listener1 = TestListener(() {});
      final listener2 = TestListener(() {});

      expect(component.listeners.length, 0);

      component.addListener(listener1);
      expect(component.listeners.length, 1);
      expect(component.listeners, contains(listener1));

      component.addListener(listener2);
      expect(component.listeners.length, 2);

      component.removeListener(listener1);
      expect(component.listeners.length, 1);
      expect(component.listeners, isNot(contains(listener1)));
      expect(component.listeners, contains(listener2));
    });
  });
}
