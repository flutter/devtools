// FILE: main.dart (Note: Do not remove comment, for testing.)

// Copyright 2021 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// ATTENTION: If any lines are added to or  deleted from this file then the
// debugger panel integration test will need to be updated with new line numbers
// (the test verifies that breakpoints are hit at specific lines).

import 'package:flutter/material.dart';
// Unused imports are useful for testing autocomplete.
// ignore_for_file: unused_import
import 'src/autocomplete.dart';
import 'src/other_classes.dart';

void main() => runApp(const MyApp());

bool topLevelFieldForTest = false;

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    // ignore: unused_local_variable, for testing.
    var count = 0;
    void incrementCounter() {
      count++;
    }

    PeriodicAction(incrementCounter).doEvery(const Duration(seconds: 1));
    return MaterialApp(
      title: 'Hello, World',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Hello, World'),
        ),
        body: const Center(
          child: Text('Hello, World!'),
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: _printHello,
          tooltip: 'Say hi',
          child: const Icon(Icons.abc),
        ), 
      ),
    );
  }

  void _printHello() {
    // ignore: avoid_print, for testing.
    print('Hello!');
  }
}
