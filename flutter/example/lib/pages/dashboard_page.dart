import 'package:flutter/material.dart';
import 'package:orchestra_flutter/orchestra_flutter.dart';

import '../features/timer_feature/timer_feature.dart';
import '../features/user_auth_feature/user_auth_feature.dart';

class DashboardPage extends OrchestraWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, OrchestraHandle handle) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _TimerDisplay(),
            _LogoutButton(),
          ],
        ),
      ),
    );
  }
}

class _LogoutButton extends OrchestraWidget {
  const _LogoutButton();

  @override
  Widget build(BuildContext context, OrchestraHandle handle) {
    final process = handle.watch<LogoutProcessComponent>().value;

    return ElevatedButton(
      onPressed: process.isRunning ? null : handle.get<LogoutEvent>().trigger,
      child: const Text('Logout'),
    );
  }
}

class _TimerDisplay extends OrchestraWidget {
  const _TimerDisplay();

  @override
  Widget build(BuildContext context, OrchestraHandle handle) {
    handle.onEnter(() {
      handle.get<StartTimerEvent>().trigger();
    });
    final stopTimer = handle.get<StopTimerEvent>().trigger;
    handle.onExit(stopTimer);
    final timerValue = handle.watch<TimerValueComponent>().value;
    return Text('Timer: ${timerValue.inSeconds} seconds');
  }
}
