import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orchestra/orchestra.dart';
import 'package:orchestra_flutter/orchestra_flutter.dart';

// ---------------------------------------------------------------------------
// Shared test doubles
// ---------------------------------------------------------------------------

class CounterComponent extends Component<int> {
  CounterComponent([super.value = 0]);
}

class LabelComponent extends Component<String> {
  LabelComponent([super.value = 'hello']);
}

class PingEvent extends Event {}

class TestOrchestration extends Orchestration {
  TestOrchestration() {
    add(CounterComponent());
    add(LabelComponent());
    add(PingEvent());
  }
}

final class TestEntityNotifier<TEntity extends Entity> extends EntityNotifier<TEntity> {
  TestEntityNotifier(super.orchestrator);
}

final class TestMultiEntityNotifier extends MultiEntityNotifier {
  TestMultiEntityNotifier(super.orchestrator, super.types);
}

// ---------------------------------------------------------------------------
// EntityNotifier tests
// ---------------------------------------------------------------------------

void main() {
  group('EntityNotifier', () {
    late Orchestrator orchestrator;
    late TestOrchestration orchestration;

    setUp(() {
      orchestrator = Orchestrator();
      orchestration = TestOrchestration();
      orchestrator.addOrchestration(orchestration);
      orchestrator.activate();
    });

    tearDown(() {
      orchestrator.deactivate();
    });

    test('initial value is read from the orchestrator', () {
      final notifier = TestEntityNotifier<CounterComponent>(orchestrator);
      expect(notifier.value, isA<CounterComponent>());
      expect(notifier.value.value, equals(0));
      notifier.dispose();
    });

    test('notifies listeners when entity changes', () {
      final notifier = TestEntityNotifier<CounterComponent>(orchestrator);
      int notifyCount = 0;
      notifier.addListener(() => notifyCount++);

      orchestration.get<CounterComponent>().update(42);

      expect(notifyCount, equals(1));
      expect(notifier.value.value, equals(42));
      notifier.dispose();
    });

    test('notifies on multiple successive changes', () {
      final notifier = TestEntityNotifier<CounterComponent>(orchestrator);
      final values = <int>[];
      notifier.addListener(() => values.add(notifier.value.value));

      orchestration.get<CounterComponent>().update(1);
      orchestration.get<CounterComponent>().update(2);
      orchestration.get<CounterComponent>().update(3);

      expect(values, equals([1, 2, 3]));
      notifier.dispose();
    });

    test('does not notify after dispose', () {
      final notifier = TestEntityNotifier<CounterComponent>(orchestrator);
      int notifyCount = 0;
      notifier.addListener(() => notifyCount++);

      notifier.dispose();
      orchestration.get<CounterComponent>().update(99);

      expect(notifyCount, equals(0));
    });

    test('works for Event entities', () {
      final notifier = TestEntityNotifier<PingEvent>(orchestrator);
      int notifyCount = 0;
      notifier.addListener(() => notifyCount++);

      orchestration.get<PingEvent>().trigger();

      expect(notifyCount, equals(1));
      notifier.dispose();
    });

    test('two independent notifiers on the same entity both receive updates', () {
      final n1 = TestEntityNotifier<CounterComponent>(orchestrator);
      final n2 = TestEntityNotifier<CounterComponent>(orchestrator);
      int count1 = 0, count2 = 0;
      n1.addListener(() => count1++);
      n2.addListener(() => count2++);

      orchestration.get<CounterComponent>().update(7);

      expect(count1, equals(1));
      expect(count2, equals(1));
      n1.dispose();
      n2.dispose();
    });

    test('disposing one notifier does not affect the other', () {
      final n1 = TestEntityNotifier<CounterComponent>(orchestrator);
      final n2 = TestEntityNotifier<CounterComponent>(orchestrator);
      int count1 = 0, count2 = 0;
      n1.addListener(() => count1++);
      n2.addListener(() => count2++);

      n1.dispose();
      orchestration.get<CounterComponent>().update(5);

      expect(count1, equals(0));
      expect(count2, equals(1));
      n2.dispose();
    });
  });

  // ---------------------------------------------------------------------------
  // MultiEntityNotifier tests
  // ---------------------------------------------------------------------------

  group('MultiEntityNotifier', () {
    late Orchestrator orchestrator;
    late TestOrchestration orchestration;

    setUp(() {
      orchestrator = Orchestrator();
      orchestration = TestOrchestration();
      orchestrator.addOrchestration(orchestration);
      orchestrator.activate();
    });

    tearDown(() {
      orchestrator.deactivate();
    });

    test('initial value contains all requested entity types', () {
      final notifier = TestMultiEntityNotifier(orchestrator, {CounterComponent, LabelComponent});

      expect(notifier.value.entities.keys, containsAll({CounterComponent, LabelComponent}));
      expect((notifier.value.get<CounterComponent>()).value, equals(0));
      expect((notifier.value.get<LabelComponent>()).value, equals('hello'));
      notifier.dispose();
    });

    test('notifies when first entity changes', () {
      final notifier = TestMultiEntityNotifier(orchestrator, {CounterComponent, LabelComponent});
      int notifyCount = 0;
      notifier.addListener(() => notifyCount++);

      orchestration.get<CounterComponent>().update(10);

      expect(notifyCount, equals(1));
      expect((notifier.value.get<CounterComponent>()).value, equals(10));
      notifier.dispose();
    });

    test('notifies when second entity changes', () {
      final notifier = TestMultiEntityNotifier(orchestrator, {CounterComponent, LabelComponent});
      int notifyCount = 0;
      notifier.addListener(() => notifyCount++);

      orchestration.get<LabelComponent>().update('world');

      expect(notifyCount, equals(1));
      expect((notifier.value.get<LabelComponent>()).value, equals('world'));
      notifier.dispose();
    });

    test('reflects independent changes for each entity', () {
      final notifier = TestMultiEntityNotifier(orchestrator, {CounterComponent, LabelComponent});

      orchestration.get<CounterComponent>().update(5);
      orchestration.get<LabelComponent>().update('changed');

      expect((notifier.value.get<CounterComponent>()).value, equals(5));
      expect((notifier.value.get<LabelComponent>()).value, equals('changed'));
      notifier.dispose();
    });

    test('does not notify after dispose', () {
      final notifier = TestMultiEntityNotifier(orchestrator, {CounterComponent, LabelComponent});
      int notifyCount = 0;
      notifier.addListener(() => notifyCount++);

      notifier.dispose();

      orchestration.get<CounterComponent>().update(1);
      orchestration.get<LabelComponent>().update('x');

      expect(notifyCount, equals(0));
    });

    test('works with a single type in the list', () {
      final notifier = TestMultiEntityNotifier(orchestrator, {CounterComponent});
      int notifyCount = 0;
      notifier.addListener(() => notifyCount++);

      orchestration.get<CounterComponent>().update(3);

      expect(notifyCount, equals(1));
      notifier.dispose();
    });
  });

  // ---------------------------------------------------------------------------
  // EntityBuilder widget tests
  // ---------------------------------------------------------------------------

  group('EntityBuilder', () {
    late TestOrchestration orchestration;

    setUp(() {
      orchestration = TestOrchestration();
    });

    testWidgets('renders initial entity value', (tester) async {
      await tester.pumpWidget(wrapWithScope(orchestration, EntityWatcher<CounterComponent>(builder: (context, counter) => Text('${counter.value}'))));
      await tester.pumpAndSettle();

      expect(find.text('0'), findsOneWidget);
    });

    testWidgets('rebuilds when entity changes', (tester) async {
      await tester.pumpWidget(wrapWithScope(orchestration, EntityWatcher<CounterComponent>(builder: (context, counter) => Text('${counter.value}'))));
      await tester.pumpAndSettle();

      orchestration.get<CounterComponent>().update(42);
      await tester.pump();

      expect(find.text('42'), findsOneWidget);
      expect(find.text('0'), findsNothing);
    });

    testWidgets('calls listener on entity change without extra rebuild', (tester) async {
      int listenerCalls = 0;
      CounterComponent? receivedEntity;

      await tester.pumpWidget(
        wrapWithScope(
          orchestration,
          EntityWatcher<CounterComponent>(
            listener: (context, entity) {
              listenerCalls++;
              receivedEntity = entity;
            },
            builder: (context, counter) => Text('${counter.value}'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      orchestration.get<CounterComponent>().update(7);
      await tester.pump();

      expect(listenerCalls, equals(1));
      expect(receivedEntity?.value, equals(7));
    });

    testWidgets('does not call listener before any change', (tester) async {
      int listenerCalls = 0;

      await tester.pumpWidget(
        wrapWithScope(
          orchestration,
          EntityWatcher<CounterComponent>(listener: (context, entity) => listenerCalls++, builder: (context, counter) => Text('${counter.value}')),
        ),
      );
      await tester.pumpAndSettle();

      expect(listenerCalls, equals(0));
    });

    testWidgets('multiple successive changes each trigger a rebuild', (tester) async {
      await tester.pumpWidget(wrapWithScope(orchestration, EntityWatcher<CounterComponent>(builder: (context, counter) => Text('${counter.value}'))));
      await tester.pumpAndSettle();

      orchestration.get<CounterComponent>().update(1);
      await tester.pump();
      expect(find.text('1'), findsOneWidget);

      orchestration.get<CounterComponent>().update(2);
      await tester.pump();
      expect(find.text('2'), findsOneWidget);
    });
  });

  // ---------------------------------------------------------------------------
  // MultiEntityBuilder widget tests
  // ---------------------------------------------------------------------------

  group('MultiEntityBuilder', () {
    late TestOrchestration orchestration;

    setUp(() {
      orchestration = TestOrchestration();
    });

    testWidgets('renders initial values for all entities', (tester) async {
      await tester.pumpWidget(
        wrapWithScope(
          orchestration,
          MultiEntityWatcher(
            entities: {CounterComponent, LabelComponent},
            builder: (context, value) {
              final counter = value.get<CounterComponent>();
              final label = value.get<LabelComponent>();
              return Text('${counter.value}-${label.value}');
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('0-hello'), findsOneWidget);
    });

    testWidgets('rebuilds when first entity changes', (tester) async {
      await tester.pumpWidget(
        wrapWithScope(
          orchestration,
          MultiEntityWatcher(
            entities: {CounterComponent, LabelComponent},
            builder: (context, value) {
              final counter = value.get<CounterComponent>();
              final label = value.get<LabelComponent>();
              return Text('${counter.value}-${label.value}');
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      orchestration.get<CounterComponent>().update(9);
      await tester.pump();

      expect(find.text('9-hello'), findsOneWidget);
    });

    testWidgets('rebuilds when second entity changes', (tester) async {
      await tester.pumpWidget(
        wrapWithScope(
          orchestration,
          MultiEntityWatcher(
            entities: {CounterComponent, LabelComponent},
            builder: (context, value) {
              final counter = value.get<CounterComponent>();
              final label = value.get<LabelComponent>();
              return Text('${counter.value}-${label.value}');
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      orchestration.get<LabelComponent>().update('world');
      await tester.pump();

      expect(find.text('0-world'), findsOneWidget);
    });

    testWidgets('calls listener when any entity changes', (tester) async {
      int listenerCalls = 0;
      Type? changedType;

      await tester.pumpWidget(
        wrapWithScope(
          orchestration,
          MultiEntityWatcher(
            entities: {CounterComponent, LabelComponent},
            listener: (context, value) {
              listenerCalls++;
              changedType = value.entities.keys.first;
            },
            builder: (context, value) => const Text('x'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      orchestration.get<CounterComponent>().update(3);
      await tester.pump();

      expect(listenerCalls, equals(1));
      expect(changedType, equals(CounterComponent));
    });

    testWidgets('does not call listener before any change', (tester) async {
      int listenerCalls = 0;

      await tester.pumpWidget(
        wrapWithScope(
          orchestration,
          MultiEntityWatcher(
            entities: {CounterComponent, LabelComponent},
            listener: (context, value) => listenerCalls++,
            builder: (context, value) => const Text('x'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(listenerCalls, equals(0));
    });
  });
}

// ---------------------------------------------------------------------------
// Helper
// ---------------------------------------------------------------------------

Widget wrapWithScope(Orchestration orchestration, Widget child) {
  return MaterialApp(
    home: OrchestraScope(orchestrations: {orchestration}, child: child),
  );
}
