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

class _LoginButton extends StatelessWidget {
  const _LoginButton();

  @override
  Widget build(BuildContext context) {
    return MultiEntityWatcher(
      entities: {LoginProcessComponent, LoginEvent},
      builder: (context, value) {
        final process = value.get<LoginProcessComponent>().value;
        final login = value.get<LoginEvent>().trigger;

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
      },
    );
  }
}
