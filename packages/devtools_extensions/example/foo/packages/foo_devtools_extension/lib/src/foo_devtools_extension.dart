// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_extensions/api.dart';
import 'package:devtools_extensions/devtools_extensions.dart';
import 'package:flutter/material.dart';

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
  int counter = 0;

  String? message;

  @override
  void initState() {
    super.initState();
    // Example of the devtools extension registering a custom handler.
    extensionManager.registerEventHandler(
      DevToolsExtensionEventType.themeUpdate,
      (event) {
        final themeUpdateValue =
            event.data?[ExtensionEventParameters.theme] as String?;
        setState(() {
          message = themeUpdateValue;
        });
      },
    );
  }

  void _incrementCounter() {
    setState(() {
      counter++;
    });
    extensionManager.postMessageToDevTools(
      DevToolsExtensionEvent(
        DevToolsExtensionEventType.unknown,
        data: {'increment_count': counter},
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
            Text('You have pushed the button $counter times'),
            const SizedBox(height: 16.0),
            ElevatedButton(
              onPressed: _incrementCounter,
              child: const Text('Increment and post count to DevTools'),
            ),
            const SizedBox(height: 48.0),
            Text('Received theme update from DevTools: $message'),
            const SizedBox(height: 48.0),
            ElevatedButton(
              onPressed: () => extensionManager
                  .showNotification('Yay, DevTools Extensions!'),
              child: const Text('Show DevTools notification'),
            ),
            const SizedBox(height: 16.0),
            ElevatedButton(
              onPressed: () => extensionManager.showBannerMessage(
                key: 'example_message_single_dismiss',
                type: 'warning',
                message: 'Warning: with great power, comes great '
                    'responsibility. I\'m not going to tell you twice.\n'
                    '(This message can only be shown once)',
                extensionName: 'foo',
              ),
              child: const Text(
                'Show DevTools warning (ignore if already dismissed)',
              ),
            ),
            const SizedBox(height: 16.0),
            ElevatedButton(
              onPressed: () => extensionManager.showBannerMessage(
                key: 'example_message_multi_dismiss',
                type: 'warning',
                message: 'Warning: with great power, comes great '
                    'responsibility. I\'ll keep reminding you if you '
                    'forget.\n(This message can be shown multiple times)',
                extensionName: 'foo',
                ignoreIfAlreadyDismissed: false,
              ),
              child: const Text(
                'Show DevTools warning (can show again after dismiss)',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
