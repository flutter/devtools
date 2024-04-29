// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';

import 'missing_material_error.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
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
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Center(
        child: Card(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              makeDemoEntry(
                context,
                'Missing Material Example',
                const MissingMaterialError(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget makeDemoEntry(BuildContext context, String title, Widget nextScreen) {
    void navigateToDemo() async {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => nextScreen),
      );
    }

    navigateCallbacks[title] = navigateToDemo;
    return Row(
      children: <Widget>[
        const SizedBox(
          width: 50.0,
        ),
        const Icon(Icons.star),
        TextButton(
          onPressed: navigateToDemo,
          child: Text(title),
        ),
      ],
    );
  }
}

Map<String, void Function()> navigateCallbacks = {};

// Hook to navigate to a specific screen.
void navigateToScreen(String title) {
  navigateCallbacks[title]!();
}
