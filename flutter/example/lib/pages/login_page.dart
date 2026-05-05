import 'package:flutter/material.dart';
import 'package:orchestra_flutter/orchestra_flutter.dart';

import '../features/user_auth_feature/user_auth_feature.dart';

class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Login'),
      ),
      body: const Center(
        child: _LoginButton(),
      ),
    );
  }
}

class _LoginButton extends OrchestraWidget {
  const _LoginButton();

  @override
  Widget build(BuildContext context, OrchestraHandle handle) {
    final process = handle.watch<LoginProcessComponent>().value;
    final login = handle.get<LoginEvent>().trigger;

    return ElevatedButton(
      onPressed: process.isRunning
          ? null
          : () {
              login(AuthCredentials(
                username: 'username',
                password: 'password',
              ));
            },
      child: const Text('Login'),
    );
  }
}
