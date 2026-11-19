import 'package:flutter/material.dart';

void main() => runApp(const L2aApp());

/// The host of the plugin under test: one screen that tells the tests the app is up.
class L2aApp extends StatelessWidget {
  const L2aApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: Scaffold(
        body: Center(child: Text('l2a ready', key: Key('l2a-ready'))),
      ),
    );
  }
}
