import 'package:orchestra/orchestra.dart';

part 'models/timer_state.dart';
part 'timer_feature.g.dart';

final timerFeature = Composer.createOrchestration();

final timerState = timerFeature.addComponent(TimerState.stopped);

final timerValue = timerFeature.addComponent(Duration.zero);

final resetTimer = timerFeature.addEvent();

final startTimer = timerFeature.addEvent();

final stopTimer = timerFeature.addEvent();

final handleStartTimer = timerFeature.addReactiveSystem(
  reactsTo: {startTimer},
  reactsIf: () {
    return timerState.value == TimerState.stopped;
  },
  react: () {
    timerState.value = TimerState.running;
  },
);

final handleStopTimer = timerFeature.addReactiveSystem(
  reactsTo: {stopTimer},
  reactsIf: () {
    return timerState.value == TimerState.running;
  },
  react: () {
    timerState.value = TimerState.stopped;
  },
);

final handleResetTimer = timerFeature.addReactiveSystem(
  reactsTo: {resetTimer},
  react: () {
    timerValue.value = Duration.zero;
  },
);

final handleUpdateTimer = timerFeature.addExecuteSystem(
  executesIf: () {
    return timerState.value == TimerState.running;
  },
  execute: (elapsed) {
    timerValue.value += elapsed;
  },
);
