// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'test_feature.dart';

final class TestComponent extends Component<int> {
  TestComponent() : super(0);
}

final class TestEvent extends Event {}

final class TestDataEvent extends DataEvent<String> {}

final class TestReactiveSystem extends ReactiveSystem {
  @override
  Set<Type> get reactsTo {
    return const {TestDataEvent};
  }

  @override
  Set<Type> get interactsWith {
    return const {TestComponent, TestDataEvent, TestEvent};
  }

  @override
  bool get reactsIf {
    return get<TestComponent>().value > 0;
  }

  @override
  void react() {
    get<TestComponent>().previous;
    get<TestComponent>().value;
    get<TestComponent>().updatedAt;
    get<TestEvent>().triggeredAt;
    get<TestEvent>().trigger();
    get<TestDataEvent>().trigger('Hello');
    _react(get<TestDataEvent>().data);
  }

  void _react(String data) {
    _react2(() {
      get<TestComponent>().value++;
    });
  }

  void _react2(void Function() method) {
    method();
  }
}

final class TestExecuteSystem extends ExecuteSystem {
  @override
  Set<Type> get interactsWith {
    return const {TestEvent};
  }

  @override
  bool get executesIf {
    return _executesIf();
  }

  @override
  void execute(Duration elapsed) {
    _execute();
  }

  void _execute() {
    _execute2();
  }

  void _execute2() {
    get<TestEvent>().trigger();
  }

  bool _executesIf() {
    return _executesIf2();
  }

  bool _executesIf2() {
    return get<TestComponent>().value > 0;
  }
}

final class TestCleanupSystem extends CleanupSystem {
  @override
  Set<Type> get interactsWith {
    return const {TestComponent};
  }

  @override
  bool get cleansIf {
    return _cleansIf();
  }

  @override
  void cleanup() {
    _cleanup();
  }

  void _cleanup() {
    _cleanup2();
  }

  void _cleanup2() {
    get<TestComponent>().value = 0;
  }

  bool _cleansIf() {
    return get<TestComponent>().value > 20;
  }
}

final class TestTeardownSystem extends TeardownSystem {
  @override
  Set<Type> get interactsWith {
    return const {TestComponent};
  }

  @override
  void teardown() {
    _teardown();
  }

  void _teardown() {
    _teardown2();
  }

  void _teardown2() {
    get<TestComponent>().value = 1;
  }
}

final class TestInitializeSystem extends InitializeSystem {
  @override
  Set<Type> get interactsWith {
    return const {TestComponent};
  }

  @override
  void initialize() {
    _initialize();
  }

  void _initialize() {
    _initialize2();
  }

  void _initialize2() {
    get<TestComponent>().value = 1;
  }
}

final class TestFeatureOrchestration extends Orchestration {
  TestFeatureOrchestration() {
    add(TestComponent());
    add(TestEvent());
    add(TestDataEvent());
    add(TestReactiveSystem());
    add(TestExecuteSystem());
    add(TestCleanupSystem());
    add(TestTeardownSystem());
    add(TestInitializeSystem());
  }
}
