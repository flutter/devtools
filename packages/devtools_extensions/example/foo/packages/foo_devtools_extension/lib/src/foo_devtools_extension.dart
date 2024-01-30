// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app_shared/ui.dart';
import 'package:devtools_extensions/devtools_extensions.dart';
import 'package:flutter/material.dart';

import 'devtools_event_example.dart';
import 'devtools_extension_api_example.dart';
import 'expression_evaluation_example.dart';
import 'service_extension_example.dart';

class FooDevToolsExtension extends StatelessWidget {
  const FooDevToolsExtension({super.key});

  @override
  Widget build(BuildContext context) {
    return const DevToolsExtension(
      child: FooExtensionHomePage(),
    );
  }
}

class FooExtensionHomePage extends StatefulWidget {
  const FooExtensionHomePage({super.key});

  @override
  State<FooExtensionHomePage> createState() => _FooExtensionHomePageState();
}

class _FooExtensionHomePageState extends State<FooExtensionHomePage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('Foo DevTools Extension'),
      ),
      body: const Padding(
        padding: EdgeInsets.symmetric(vertical: denseSpacing),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            ServiceExtensionExample(),
            SizedBox(height: 32.0),
            EvalExample(),
            SizedBox(height: 32.0),
            ListeningForDevToolsEventExample(),
            SizedBox(height: 32.0),
            CallingDevToolsExtensionsAPIsExample(),
          ],
        ),
      ),
    );
  }
}
