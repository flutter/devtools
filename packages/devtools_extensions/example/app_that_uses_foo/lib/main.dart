// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:foo/foo.dart';

void main() {
  runApp(const MyAppThatUsesFoo());
}

class MyAppThatUsesFoo extends StatelessWidget {
  const MyAppThatUsesFoo({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Foo Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepOrange),
        useMaterial3: true,
      ),
      home: const HomePage(title: 'App that uses package:foo'),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.title});

  final String title;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _counter = 0;

  void _incrementCounter() {
    setState(() {
      _counter++;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: Center(
        child: Column(
          children: [
            FooBarBaz(
              onFoo: _incrementCounter,
              onBar: _incrementCounter,
              onBaz: _incrementCounter,
            ),
            Text('FooBarBaz count: $_counter'),
          ],
        ),
      ),
    );
  }
}
