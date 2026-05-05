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
  group('OrchestraWidget Integration Tests', () {
    testWidgets('should build with Orchestra', (WidgetTester tester) async {
      final orchestration = TestOrchestration();
      OrchestraHandle? capturedOrchestra;

      await tester.pumpWidget(
        MaterialApp(
          home: OrchestraScope(
            orchestrations: {orchestration},
            child: TestOrchestraWidget(
              onBuild: (orchestra) {
                capturedOrchestra = orchestra;
              },
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(capturedOrchestra, isNotNull);
      expect(capturedOrchestra!.orchestrator, isA<Orchestrator>());
    });

    testWidgets('should rebuild when watched entity changes',
        (WidgetTester tester) async {
      final orchestration = TestOrchestration();

      await tester.pumpWidget(
        MaterialApp(
          home: OrchestraScope(
            orchestrations: {orchestration},
            child: TestOrchestraWidget(),
          ),
        ),
      );

      await Future.microtask(tester.pumpAndSettle);

      // Change the counter value
      final counter = orchestration.get<TestCounterComponent>();
      counter.update(42);

      await Future.microtask(tester.pumpAndSettle);

      // Verify the widget rebuilt with new value
      expect(find.text('Counter: 42'), findsOneWidget);
      expect(find.text('Counter: 0'), findsNothing);
    });

    testWidgets('should handle onEnter and onExit lifecycle',
        (WidgetTester tester) async {
      final orchestration = TestOrchestration();
      bool onEnterCalled = false;
      bool onExitCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: OrchestraScope(
            orchestrations: {orchestration},
            child: TestOrchestraWidget(
              customBuilder: (context, orchestra) {
                orchestra.onEnter(() {
                  onEnterCalled = true;
                });

                orchestra.onExit(() {
                  onExitCalled = true;
                });

                return const Text('Test');
              },
            ),
          ),
        ),
      );

      // Wait for post-frame callback
      await tester.pump();

      expect(onEnterCalled, isTrue);
      expect(onExitCalled, isFalse);

      // Remove the widget to trigger onExit
      await tester.pumpWidget(
        const MaterialApp(
          home: Text('Different Widget'),
        ),
      );

      await tester.pump();

      expect(onExitCalled, isTrue);
    });

    testWidgets('should handle listen callbacks', (WidgetTester tester) async {
      final orchestration = TestOrchestration();
      int listenerCallCount = 0;
      TestCounterComponent? receivedEntity;

      await tester.pumpWidget(
        MaterialApp(
          home: OrchestraScope(
            orchestrations: {orchestration},
            child: TestOrchestraWidget(
              customBuilder: (context, orchestra) {
                orchestra.listen<TestCounterComponent>((entity) {
                  listenerCallCount++;
                  receivedEntity = entity;
                });

                final counter = orchestra.watch<TestCounterComponent>();
                return Text('Counter: ${counter.value}');
              },
            ),
          ),
        ),
      );

      await tester.pump();

      expect(listenerCallCount, equals(0));

      // Change the counter
      final counter = orchestration.get<TestCounterComponent>();
      counter.update(25);

      await tester.pump();

      expect(listenerCallCount, equals(1));
      expect(receivedEntity, equals(counter));
      expect(receivedEntity!.value, equals(25));
    });

    testWidgets('should not rebuild after disposal',
        (WidgetTester tester) async {
      final orchestration = TestOrchestration();

      await tester.pumpWidget(
        MaterialApp(
          home: OrchestraScope(
            orchestrations: {orchestration},
            child: TestOrchestraWidget(),
          ),
        ),
      );

      // Get orchestra access to counter before disposal
      final counter = orchestration.get<TestCounterComponent>();

      // Remove the widget (this should dispose the orchestra binding)
      await tester.pumpWidget(
        const MaterialApp(
          home: Text('Different Widget'),
        ),
      );

      await tester.pumpAndSettle();

      // Try to change the counter after disposal
      counter.update(99);

      // Pump again to see if any rebuilds happen (they shouldn't)
      await tester.pump();

      // Verify the old widget is gone
      expect(find.text('Counter: 99'), findsNothing);
    });

    testWidgets('should handle multiple OrchestraWidgets independently',
        (WidgetTester tester) async {
      final orchestration = TestOrchestration();

      await tester.pumpWidget(
        MaterialApp(
          home: OrchestraScope(
            orchestrations: {orchestration},
            child: Column(
              children: [
                TestOrchestraWidget(
                  key: const Key('widget1'),
                ),
                TestOrchestraWidget(
                  key: const Key('widget2'),
                ),
              ],
            ),
          ),
        ),
      );

      // Both widgets should show the same initial value
      expect(find.text('Counter: 0'), findsNWidgets(2));

      // Change the counter
      final counter = orchestration.get<TestCounterComponent>();
      counter.update(15);

      await tester.pump();

      // Both widgets should update
      expect(find.text('Counter: 15'), findsNWidgets(2));
      expect(find.text('Counter: 0'), findsNothing);
    });
  });
}
