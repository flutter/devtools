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
  _MyGarbage _gcableItem = _MyGarbage(0, 'Should be gced, initial.');

  void _incrementCounter() {
    setState(() {
      _counter++;
      _garbage.add(_MyGarbage(0, 'Never gced.'));
      if (identityHashCode(_gcableItem) < 0) {
        // We need this block to show compiler [_gcableItem] is in use.
      }
      _gcableItem = _MyGarbage(0, 'Should be gced, initial.');
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
  _MyGarbage(this._level, this._note) {
    if (_level >= _depth) {
      childClass = null;
      childList = null;
      mapSimpleKey = null;
      mapSimpleValue = null;
      map = null;
      record = null;
    } else {
      _MyGarbage createInstance({String? note}) =>
          _MyGarbage(_level + 1, note ?? _note);

      childClass = createInstance();

      childList = List.generate(_width, (_) => createInstance());

      mapSimpleKey = {
        for (var index = 0; index < _width; index++) index: createInstance(),
      };

      mapSimpleValue = {
        for (var index = 0; index < _width; index++) createInstance(): index,
      };

      map = {
        for (final _ in Iterable<void>.generate(_width))
          createInstance(): createInstance(),
      };

      final closureMember = createInstance(note: 'closure');
      closure = () {
        if (identityHashCode(closureMember) < 0) {
          // We need this block to show compiler [_closureMember] is in use.
        }
      };

      record = ('foo', count: 100, garbage: createInstance(note: 'record'));
    }
  }

  static const _depth = 2;
  static const _width = 3;

  final int _level;
  final String _note;

  late final _MyGarbage? childClass;
  late final List<_MyGarbage>? childList;
  final Map mapSimple = Map.fromIterable(Iterable.generate(_width));
  final Map mapEmpty = {};
  final Map mapOfNulls = {null: null};
  final listOfInt = List.generate(300, (i) => i);
  late final Map<dynamic, _MyGarbage>? mapSimpleKey;
  late final Map<_MyGarbage, dynamic>? mapSimpleValue;
  late final Map<_MyGarbage, _MyGarbage>? map;
  late final void Function() closure;

  late final (String, {int count, _MyGarbage garbage})? record;
}
