// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'timer_feature.dart';

final class TimerStateComponent extends Component<TimerState> {
  TimerStateComponent() : super(TimerState.stopped);
}

final class TimerValueComponent extends Component<Duration> {
  TimerValueComponent() : super(Duration.zero);
}

final class ResetTimerEvent extends Event {}

final class StartTimerEvent extends Event {}

final class StopTimerEvent extends Event {}

final class HandleStartTimerReactiveSystem extends ReactiveSystem {
  @override
  Set<Type> get reactsTo {
    return const {StartTimerEvent};
  }

  @override
  Set<Type> get interactsWith {
    return const {TimerStateComponent};
  }

  @override
  bool get reactsIf {
    return get<TimerStateComponent>().value == TimerState.stopped;
  }

  @override
  void react() {
    get<TimerStateComponent>().value = TimerState.running;
  }
}

final class HandleStopTimerReactiveSystem extends ReactiveSystem {
  @override
  Set<Type> get reactsTo {
    return const {StopTimerEvent};
  }

  @override
  Set<Type> get interactsWith {
    return const {TimerStateComponent};
  }

  @override
  bool get reactsIf {
    return get<TimerStateComponent>().value == TimerState.running;
  }

  @override
  void react() {
    get<TimerStateComponent>().value = TimerState.stopped;
  }
}

final class HandleResetTimerReactiveSystem extends ReactiveSystem {
  @override
  Set<Type> get reactsTo {
    return const {ResetTimerEvent};
  }

  @override
  Set<Type> get interactsWith {
    return const {TimerValueComponent};
  }

  @override
  void react() {
    get<TimerValueComponent>().value = Duration.zero;
  }
}

final class HandleUpdateTimerExecuteSystem extends ExecuteSystem {
  @override
  Set<Type> get interactsWith {
    return const {TimerValueComponent};
  }

  @override
  bool get executesIf {
    return get<TimerStateComponent>().value == TimerState.running;
  }

  @override
  void execute(Duration elapsed) {
    get<TimerValueComponent>().value += elapsed;
  }
}

final class TimerFeatureOrchestration extends Orchestration {
  TimerFeatureOrchestration() {
    add(TimerStateComponent());
    add(TimerValueComponent());
    add(ResetTimerEvent());
    add(StartTimerEvent());
    add(StopTimerEvent());
    add(HandleStartTimerReactiveSystem());
    add(HandleStopTimerReactiveSystem());
    add(HandleResetTimerReactiveSystem());
    add(HandleUpdateTimerExecuteSystem());
  }
}
