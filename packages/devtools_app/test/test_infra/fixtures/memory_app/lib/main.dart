// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

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
  final _garbage = <_MyGarbage>[];
  int _counter = 0;

  void _incrementCounter() {
    setState(() {
      _counter++;
      _garbage.add(_MyGarbage(0));
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Text(
              'You have pushed the button this many times:',
            ),
            Text(
              '$_counter',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _incrementCounter,
        tooltip: 'Increment',
        child: const Icon(Icons.add),
      ),
    );
  }
}

/// Contains references of different types to
/// test representation of a heap instance in DevTools console.
class _MyGarbage {
  _MyGarbage(this._level) {
    _instances++;

    if (_level >= _depth) {
      childClass = null;
      childList = null;
      childMapSimpleKey = null;
      childMapSimpleValue = null;
      childMap = null;
    } else {
      childClass = _MyGarbage(_level + 1);

      childList =
          Iterable.generate(_width, (_) => _MyGarbage(_level + 1)).toList();

      childMapSimpleKey = Map.fromIterable(
        Iterable.generate(_width),
        value: (_) => _MyGarbage(_level + 1),
      );

      childMapSimpleValue = Map.fromIterable(
        Iterable.generate(_width),
        key: (_) => _MyGarbage(_level + 1),
      );

      childMap = Map.fromIterable(
        Iterable.generate(_width),
        key: (_) => _MyGarbage(_level + 1),
        value: (_) => _MyGarbage(_level + 1),
      );
    }
  }

  static int _instances = 0;

  static const _depth = 2;
  static const _width = 3;

  final int _level;

  late final _MyGarbage? childClass;
  late final List<_MyGarbage>? childList;
  final Map childMapSimple = Map.fromIterable(Iterable.generate(_width));
  late final Map<dynamic, _MyGarbage>? childMapSimpleKey;
  late final Map<_MyGarbage, dynamic>? childMapSimpleValue;
  late final Map<_MyGarbage, _MyGarbage>? childMap;
}
