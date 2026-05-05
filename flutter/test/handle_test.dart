import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orchestra/orchestra.dart';
import 'package:orchestra_flutter/orchestra_flutter.dart';

// Test entities
class TestCounterComponent extends Component<int> {
  TestCounterComponent([super.value = 0]);
}

class TestStringComponent extends Component<String> {
  TestStringComponent([super.value = 'initial']);
}

class TestToggleEvent extends Event {
  TestToggleEvent();
}

class TestIncrementEvent extends Event {
  TestIncrementEvent();
}

// Test orchestration that includes entities and a system
class TestOrchestration extends Orchestration {
  TestOrchestration() {
    add(TestCounterComponent());
    add(TestStringComponent());
    add(TestToggleEvent());
    add(TestIncrementEvent());
    add(TestReactiveSystem());
  }
}

// Empty orchestration for testing edge cases
class EmptyTestOrchestration extends Orchestration {
  EmptyTestOrchestration();
}

// Test system
class TestReactiveSystem extends ReactiveSystem {
  @override
  Set<Type> get interactsWith => {};
  @override
  Set<Type> get reactsTo => {TestIncrementEvent};
  @override
  void react() {
    // This would normally interact with components
  }
}

// Test widget that uses Orchestra
class TestOrchestraWidget extends OrchestraWidget {
  final Function(OrchestraHandle)? onBuild;
  final Widget Function(BuildContext, OrchestraHandle)? customBuilder;

  const TestOrchestraWidget({
    super.key,
    this.onBuild,
    this.customBuilder,
  });

  @override
  Widget build(BuildContext context, OrchestraHandle handle) {
    onBuild?.call(handle);

    if (customBuilder != null) {
      return customBuilder!(context, handle);
    }

    final counter = handle.watch<TestCounterComponent>();
    final stringComponent = handle.watch<TestStringComponent>();

    return Column(
      children: [
        Text('Counter: ${counter.value}'),
        Text('String: ${stringComponent.value}'),
      ],
    );
  }
}

void main() {
  group('Orchestra Tests', () {
    late Orchestrator orchestrator;
    late TestOrchestration orchestration;
    late OrchestraHandle orchestra;
    int rebuildCount = 0;

    setUp(() {
      rebuildCount = 0;
      orchestrator = Orchestrator();
      orchestration = TestOrchestration();
      orchestrator.addOrchestration(orchestration);
      orchestrator.activate();

      orchestra = OrchestraHandle(orchestrator, () {
        rebuildCount++;
      });
    });

    tearDown(() {
      orchestra.dispose();
    });

    test('should get entities from manager', () {
      final counter = orchestra.get<TestCounterComponent>();
      final stringComponent = orchestra.get<TestStringComponent>();

      expect(counter, isA<TestCounterComponent>());
      expect(counter.value, equals(0));
      expect(stringComponent, isA<TestStringComponent>());
      expect(stringComponent.value, equals('initial'));
    });

    testWidgets('should watch entities and trigger rebuilds on change', (WidgetTester tester) async {
      final counter = orchestra.watch<TestCounterComponent>();

      expect(rebuildCount, equals(0));

      // Change the watched entity
      counter.update(5);

      // Pump frame to trigger callback
      await tester.pump();

      expect(rebuildCount, equals(1));
    });

    testWidgets('should not trigger rebuild when locked', (WidgetTester tester) async {
      final counter = orchestra.watch<TestCounterComponent>();

      // Simulate locked state
      orchestra.locked = true;

      counter.update(10);
      await tester.pump();

      expect(rebuildCount, equals(0));
    });

    testWidgets('should handle multiple watchers correctly', (WidgetTester tester) async {
      final counter = orchestra.watch<TestCounterComponent>();
      final stringComponent = orchestra.watch<TestStringComponent>();

      expect(rebuildCount, equals(0));

      // Change first watched entity
      counter.update(3);
      await tester.pump();
      expect(rebuildCount, equals(1));

      // Change second watched entity
      stringComponent.update('changed');
      await tester.pump();
      expect(rebuildCount, equals(2));
    });

    testWidgets('should call listeners when entity changes', (WidgetTester tester) async {
      bool listenerCalled = false;
      TestCounterComponent? receivedEntity;

      orchestra.listen<TestCounterComponent>((entity) {
        listenerCalled = true;
        receivedEntity = entity;
      });

      final counter = orchestra.get<TestCounterComponent>();
      counter.update(7);

      await tester.pump();

      expect(listenerCalled, isTrue);
      expect(receivedEntity, equals(counter));
      expect(receivedEntity!.value, equals(7));
    });

    testWidgets('should call onEnter callback when initialized', (WidgetTester tester) async {
      bool onEnterCalled = false;

      orchestra.onEnter(() {
        onEnterCalled = true;
      });

      orchestra.initialize();
      await tester.pump();

      expect(onEnterCalled, isTrue);
    });

    test('should call onExit callback when disposed', () {
      bool onExitCalled = false;

      orchestra.onExit(() {
        onExitCalled = true;
      });

      orchestra.dispose();

      expect(onExitCalled, isTrue);
    });

    test('should only set onEnter callback once', () {
      orchestra.onEnter(() {
        // First callback
      });

      orchestra.onEnter(() {
        // Second callback should be ignored
      });

      expect(orchestra.onEnterListener, isNotNull);
      // Second callback should be ignored - the listener should not change
    });

    test('should clean up listeners on dispose', () async {
      final counter = orchestra.watch<TestCounterComponent>();

      // Verify listener is added
      expect(counter.listeners.length, equals(1));

      orchestra.dispose();

      // Verify listener is removed
      expect(counter.listeners.length, equals(0));
    });

    test('should handle disposed state correctly', () {
      orchestra.dispose();

      expect(orchestra.disposed, isTrue);
    });
  });

  group('Edge Cases and Error Handling', () {
    testWidgets('should handle rapid entity changes', (WidgetTester tester) async {
      final orchestrator = Orchestrator();
      final orchestration = TestOrchestration();
      orchestrator.addOrchestration(orchestration);
      orchestrator.activate();

      int rebuildCount = 0;
      final orchestra = OrchestraHandle(orchestrator, () {
        rebuildCount++;
      });

      final counter = orchestra.watch<TestCounterComponent>();

      // Rapid changes
      counter.update(1);
      counter.update(2);
      counter.update(3);
      counter.update(4);
      counter.update(5);

      await tester.pump();

      // Should still only rebuild once due to frame callback batching
      expect(rebuildCount, equals(1));

      orchestra.dispose();
    });

    testWidgets('should prevent multiple builds when previous build is not completed', (WidgetTester tester) async {
      final orchestrator = Orchestrator();
      final orchestration = TestOrchestration();
      orchestrator.addOrchestration(orchestration);
      orchestrator.activate();

      int rebuildCount = 0;

      final orchestra = OrchestraHandle(orchestrator, () {
        rebuildCount++;
      });

      final counter = orchestra.watch<TestCounterComponent>();

      // Trigger first build
      counter.update(1);

      // Immediately trigger more changes while first build is in progress
      counter.update(2);
      counter.update(3);
      counter.update(4);

      // Verify orchestra is locked during build
      expect(orchestra.locked, isTrue);

      await tester.pump();

      // Should only rebuild once despite multiple changes
      expect(rebuildCount, equals(1));

      // After frame callback, orchestra should be unlocked
      expect(orchestra.locked, isFalse);

      orchestra.dispose();
    });

    test('should handle watching same entity multiple times', () {
      final orchestrator = Orchestrator();
      final orchestration = TestOrchestration();
      orchestrator.addOrchestration(orchestration);
      orchestrator.activate();

      final orchestra = OrchestraHandle(orchestrator, () {});

      final counter1 = orchestra.watch<TestCounterComponent>();
      final counter2 = orchestra.watch<TestCounterComponent>();

      expect(counter1, equals(counter2));
      expect(orchestra.watchers.length, equals(1));

      orchestra.dispose();
    });
  });
}
