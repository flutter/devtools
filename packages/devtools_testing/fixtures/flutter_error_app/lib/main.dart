// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';

import 'missing_material_error.dart';

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
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
  const MyHomePage({Key key, this.title}) : super(key: key);

  final String title;

  @override
  _MyHomePageState createState() => _MyHomePageState();
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
                MissingMaterialError(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget makeDemoEntry(BuildContext context, String title, Widget nextScreen) {
    final navigateToDemo = () async {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => nextScreen),
      );
    };
    navigateCallbacks[title] = navigateToDemo;
    return Row(
      children: <Widget>[
        const SizedBox(
          width: 50.0,
        ),
        const Icon(Icons.star),
        FlatButton(
          child: Text(title),
          onPressed: navigateToDemo,
        ),
      ],
    );
  }
}

Map<String, Function> navigateCallbacks = {};

// Hook to navigate to a specific screen.
void navigateToScreen(String title) {
  navigateCallbacks[title]();
}
