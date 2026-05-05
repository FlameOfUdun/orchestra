import 'package:flutter/material.dart';

void main() {
  runApp(const _Application());
}

class _Application extends StatelessWidget {
  const _Application();

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: Scaffold(body: Center(child: Text('Hello World!'))),
    );
  }
}
