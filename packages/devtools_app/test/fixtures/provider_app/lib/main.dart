// Copyright 2021 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// ignore: unused_import, allows the tests to use functions from tester.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import 'mixin.dart';
// ignore: unused_import, allows the tests to use functions from tester.dart
import 'tester.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  var _providers = <SingleChildWidget>[];
  var _totalProvidersAdded = 0;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => Counter()),
        ..._providers,
      ],
      builder: (context, _) => MaterialApp(
        home: Scaffold(
          body: SizedBox.expand(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Providers count ${1 + _providers.length}'),
                Text(context.watch<Counter>().count.toString()),
                ElevatedButton(
                  key: const Key('increment'),
                  onPressed: () => context.read<Counter>().increment(),
                  child: const Icon(Icons.add),
                ),
              ],
            ),
          ),
          floatingActionButton: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FloatingActionButton(
                key: const Key('add'),
                onPressed: () {
                  setState(() {
                    _providers = [
                      ..._providers,
                      Provider<int>.value(value: _totalProvidersAdded++),
                    ];
                  });
                },
                child: const Icon(Icons.add),
              ),
              FloatingActionButton(
                key: const Key('remove'),
                onPressed: () {
                  setState(() {
                    _providers = List.from(_providers)..removeLast();
                  });
                },
                child: const Icon(Icons.remove),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class Counter with ChangeNotifier, Mixin {
  int _count = 0;
  int get count => _count;

  final complex = ComplexObject();

  void increment() {
    _count++;
    notifyListeners();
  }

  @override
  // ignore: hash_and_equals, overriding the hashcode for testing purposes
  int get hashCode => 42;
}

enum Enum { a, b }

final _token = Object();

class ComplexObject {
  Enum enumeration = Enum.a;
  Null nill;
  bool boolean = false;
  int integer = 0;
  double float = .42;
  String string = 'hello world';
  Object plainInstance = const _SubObject('hello world');

  int lateWithInitializer = 21;
  late int uninitializedLate;

  final int finalVar = 42;

  int get getter => 42;

  int _getterAndSetter = 0;
  // ignore: unnecessary_getters_setters
  int get getterAndSetter => _getterAndSetter;
  // ignore: unnecessary_getters_setters
  set getterAndSetter(int value) => _getterAndSetter = value;

  var map = <Object?, Object?>{
    'list': [42],
    'string': 'string',
    42: 'number_key',
    true: 'bool_key',
    null: null,
    const _SubObject('complex-key'): const _SubObject('complex-value'),
    _token: 'non-constant key',
    'nested_map': <Object, Object>{
      'key': 'value',
    }
  };

  var list = <Object?>[
    42,
    'string',
    [],
    <Object, Object>{},
    const _SubObject('complex-value'),
    null,
  ];

  @override
  // ignore: hash_and_equals, overriding the hashcode for testing purposes
  int get hashCode => 21;
}

class _SubObject {
  const _SubObject(this.value);
  final String value;
}
