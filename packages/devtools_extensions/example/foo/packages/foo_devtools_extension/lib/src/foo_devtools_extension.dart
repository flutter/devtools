// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app_shared/ui.dart';
import 'package:devtools_extensions/api.dart';
import 'package:devtools_extensions/devtools_extensions.dart';
import 'package:flutter/material.dart';

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
            ListeningForDevToolsEventExample(),
            SizedBox(height: 32.0),
            CallingDevToolsAPIsExample(),
          ],
        ),
      ),
    );
  }
}

class ListeningForDevToolsEventExample extends StatefulWidget {
  const ListeningForDevToolsEventExample({super.key});

  @override
  State<ListeningForDevToolsEventExample> createState() =>
      _ListeningForDevToolsEventExampleState();
}

class _ListeningForDevToolsEventExampleState
    extends State<ListeningForDevToolsEventExample> {
  String? message;

  @override
  void initState() {
    super.initState();
    // Example of the devtools extension registering a custom handler to listen
    // for an event coming from DevTools.
    extensionManager.registerEventHandler(
      DevToolsExtensionEventType.unknown,
      (event) {
        setState(() {
          message = event.data?.toString() ?? 'unknown event';
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '2. Example of listening for a DevTools event',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const PaddedDivider.thin(),
        Text('Received an unknown event from DevTools: $message'),
      ],
    );
  }
}

class CallingDevToolsAPIsExample extends StatelessWidget {
  const CallingDevToolsAPIsExample({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '3. Example of calling DevTools extension APIs',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const PaddedDivider.thin(),
        ElevatedButton(
          onPressed: () => extensionManager.postMessageToDevTools(
            DevToolsExtensionEvent(
              DevToolsExtensionEventType.unknown,
              data: {'foo': 'bar'},
            ),
          ),
          child: const Text('Send a message to DevTools'),
        ),
        const SizedBox(height: 16.0),
        ElevatedButton(
          onPressed: () =>
              extensionManager.showNotification('Yay, DevTools Extensions!'),
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
    );
  }
}
