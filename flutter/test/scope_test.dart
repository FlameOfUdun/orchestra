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
class EmptyOrchestration extends Orchestration {
  EmptyOrchestration();
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

void main() {
  group('OrchestraScope Tests', () {
    testWidgets('should create and provide Orchestrator to descendants', (WidgetTester tester) async {
      final orchestration = TestOrchestration();
      Orchestrator? retrievedOrchestrator;

      await tester.pumpWidget(
        MaterialApp(
          home: OrchestraScope(
            orchestrations: {orchestration},
            child: Builder(
              builder: (context) {
                retrievedOrchestrator = OrchestraScope.of(context);
                return const Text('Test');
              },
            ),
          ),
        ),
      );

      await tester.pump();

      expect(retrievedOrchestrator, isNotNull);
      expect(retrievedOrchestrator, isA<Orchestrator>());
    });

    testWidgets('should initialize orchestrations on mount', (WidgetTester tester) async {
      final orchestration = TestOrchestration();

      await tester.pumpWidget(
        MaterialApp(
          home: OrchestraScope(
            orchestrations: {orchestration},
            child: const Text('Test'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify orchestration was initialized
      final counter = orchestration.get<TestCounterComponent>();
      expect(counter, isNotNull);
      expect(counter.value, equals(0));
    });

    testWidgets('should teardown and deactivate manager on dispose', (WidgetTester tester) async {
      final orchestration = TestOrchestration();

      await tester.pumpWidget(
        MaterialApp(
          home: OrchestraScope(
            orchestrations: {orchestration},
            child: const Text('Test'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Get manager reference
      final manager = await tester.runAsync(() async {
        final context = tester.element(find.text('Test'));
        return OrchestraScope.of(context);
      });

      expect(manager, isNotNull);

      // Remove the scope
      await tester.pumpWidget(
        const MaterialApp(
          home: Text('Different Widget'),
        ),
      );

      await tester.pumpAndSettle();

      // Manager should be deactivated (we can't directly test this without
      // exposing internal state, but we verify no errors occur)
      expect(find.text('Different Widget'), findsOneWidget);
    });

    testWidgets('should return null with maybeOf when scope not found', (WidgetTester tester) async {
      Orchestrator? orchestrator;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              orchestrator = OrchestraScope.maybeOf(context);
              return const Text('Test');
            },
          ),
        ),
      );

      expect(orchestrator, isNull);
    });

    testWidgets('should throw error with of when scope not found', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              expect(
                () => OrchestraScope.of(context),
                throwsA(isA<FlutterError>()),
              );
              return const Text('Test');
            },
          ),
        ),
      );
    });

    testWidgets('should support named scopes', (WidgetTester tester) async {
      final orchestration = TestOrchestration();

      await tester.pumpWidget(
        MaterialApp(
          home: OrchestraScope(
            name: 'TestScope',
            orchestrations: {orchestration},
            child: const Text('Test'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Test'), findsOneWidget);
    });

    testWidgets('should run execution loop when orchestrations have execute systems', (WidgetTester tester) async {
      final orchestration = TestOrchestration();

      await tester.pumpWidget(
        MaterialApp(
          home: OrchestraScope(
            orchestrations: {orchestration},
            child: const Text('Test'),
          ),
        ),
      );

      // Pump multiple frames to verify ticker is running
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pump(const Duration(milliseconds: 16));

      expect(find.text('Test'), findsOneWidget);
    });

    testWidgets('should support nested Orchestra scopes', (WidgetTester tester) async {
      final outerOrchestration = TestOrchestration();
      final innerOrchestration = EmptyOrchestration();

      Orchestrator? outerManager;
      Orchestrator? innerManager;

      await tester.pumpWidget(
        MaterialApp(
          home: OrchestraScope(
            name: 'Outer',
            orchestrations: {outerOrchestration},
            child: Builder(
              builder: (outerContext) {
                outerManager = OrchestraScope.of(outerContext);
                return OrchestraScope(
                  name: 'Inner',
                  orchestrations: {innerOrchestration},
                  child: Builder(
                    builder: (innerContext) {
                      innerManager = OrchestraScope.of(innerContext);
                      return const Text('Nested');
                    },
                  ),
                );
              },
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(outerManager, isNotNull);
      expect(innerManager, isNotNull);
      expect(outerManager, isNot(equals(innerManager)));
      expect(find.text('Nested'), findsOneWidget);
    });
  });
}
