import 'package:flutter/material.dart';
import 'package:stager/stager.dart';

/// To run: `flutter run -t test/scenes/hello.stager_app.dart -d macos`.
class HelloScene extends Scene {
  @override
  Widget build() {
    return const MaterialApp(
      home: Card(
        child: Text('hello, world'),
      ),
    );
  }

  @override
  Future<void> setUp() async {}

  @override
  String get title => '$HelloScene';
}
