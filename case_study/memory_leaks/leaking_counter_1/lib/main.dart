// Copyright 2025 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.
import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _counter = 0;
  final _cachedScreens = <Scaffold>[];

  /// Increments counter if current screen contains floating action button.
  void _incrementCounter(BuildContext context) {
    if (_cachedScreens.last.floatingActionButton != null) {
      setState(() => _counter++);
    }
  }

  Scaffold buildScreen(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Text(
              'The counter value is:',
            ),
            MyCounterView(value: _counter),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _incrementCounter(context),
        tooltip: 'Increment counter',
        foregroundColor: theme.canvasColor,
        child: const Icon(Icons.add),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screen = buildScreen(context);
    _cachedScreens.add(screen);
    return screen;
  }
}

class MyCounterView extends StatelessWidget {
  const MyCounterView({super.key, required this.value});
  final int value;

  @override
  Widget build(BuildContext context) {
    return Text(
      '$value',
      style: Theme.of(context).textTheme.headlineMedium,
    );
  }
}
