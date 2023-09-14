// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_extensions/api.dart';
import 'package:devtools_extensions/devtools_extensions.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(const FooDevToolsExtension());
}

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
  int _counter = 0;

  String? _message;

  @override
  void initState() {
    super.initState();
    // Example of the devtools extension registering a custom handler.
    extensionManager.registerEventHandler(
      DevToolsExtensionEventType.unknown,
      (event) {
        setState(() {
          _message = event.data?['message'] as String?;
        });
      },
    );
  }

  void _incrementCounter() {
    setState(() {
      _counter++;
    });
    extensionManager.postMessageToDevTools(
      DevToolsExtensionEvent(
        DevToolsExtensionEventType.unknown,
        data: {'increment_count': _counter},
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('Foo DevTools Extension'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text('You have pushed the button $_counter times:'),
            const SizedBox(height: 16.0),
            ElevatedButton(
              onPressed: _incrementCounter,
              child: const Text('Increment and post count to DevTools'),
            ),
            const SizedBox(height: 48.0),
            Text('Received message from DevTools: $_message'),
            const SizedBox(height: 48.0),
            Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: () => extensionManager
                      .showNotification('Yay, DevTools Extensions!'),
                  child: const Text('Show DevTools notification'),
                ),
                const SizedBox(width: 16.0),
                ElevatedButton(
                  onPressed: () => extensionManager.showBannerMessage(
                    key: 'example_message',
                    type: 'warning',
                    message:
                        'Warning: with great power, comes great responsibility.',
                    extensionName: 'foo',
                  ),
                  child: const Text('Show DevTools warning'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
