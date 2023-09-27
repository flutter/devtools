// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:flutter/material.dart';

class MissingMaterialError extends StatelessWidget {
  const MissingMaterialError({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'Missing Material',
      home: ExampleWidget(),
      // The line below can resolve the error.
      // home: Scaffold(body: new ExampleWidget()),
    );
  }
}

/// Opens an [AlertDialog] showing what the user typed.
class ExampleWidget extends StatefulWidget {
  const ExampleWidget({Key? key}) : super(key: key);

  @override
  State<ExampleWidget> createState() => _ExampleWidgetState();
}

/// State for [ExampleWidget] widgets.
class _ExampleWidgetState extends State<ExampleWidget> {
  final TextEditingController _controller = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        TextField(
          controller: _controller,
          decoration: const InputDecoration(
            hintText: 'Type something',
          ),
        ),
        ElevatedButton(
          onPressed: () {
            unawaited(
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('What you typed'),
                  content: Text(_controller.text),
                ),
              ),
            );
          },
          child: const Text('DONE'),
        ),
      ],
    );
  }
}
