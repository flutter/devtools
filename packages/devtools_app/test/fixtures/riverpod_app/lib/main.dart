// Copyright 2021 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// ignore: unused_import, allows the tests to use functions from tester.dart

// @dart=2.9

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ignore: unused_import, allows the tests to use functions from tester.dart
import 'tester.dart';

final container = ProviderContainer();

void main() {
  runApp(
    UncontrolledProviderScope(
      container: container,
      child: MyApp(),
    ),
  );
}

final counterProvider = StateNotifierProvider((ref) => Counter());

class MyApp extends ConsumerWidget {
  @override
  Widget build(BuildContext context, ScopedReader watch) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Counter'),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('You clicked this many times on the button:'),
              Text(
                watch(counterProvider).toString(),
                style: Theme.of(context).textTheme.headline4,
              ),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton(
          key: const Key('increment'),
          onPressed: () => context.read(counterProvider).increment(),
          child: const Icon(Icons.add),
        ),
      ),
    );
  }
}

class Counter extends StateNotifier<int> {
  Counter() : super(0);

  void increment() => state++;

  @override
  // ignore: hash_and_equals, overriding the hashcode for testing purposes
  int get hashCode => 42;
}
