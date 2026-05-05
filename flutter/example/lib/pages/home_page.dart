import 'package:flutter/material.dart';
import 'package:orchestra_flutter/orchestra_flutter.dart';

import '../features/user_auth_feature/user_auth_feature.dart';

class HomePage extends OrchestraWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, OrchestraHandle handle) {
    handle.onEnter(() {
      debugPrint('HomePage entered');
      handle.get<ReloadUserEvent>().trigger();
    });

    handle.onExit(() {
      debugPrint('HomePage exited');
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Home'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Welcome to the Home Page!'),
          ],
        ),
      ),
    );
  }
}
