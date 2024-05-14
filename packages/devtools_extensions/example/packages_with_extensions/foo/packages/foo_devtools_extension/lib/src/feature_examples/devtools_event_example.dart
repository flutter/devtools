// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_extensions/api.dart';
import 'package:devtools_extensions/devtools_extensions.dart';
import 'package:flutter/material.dart';

/// This widget shows an example of how you can register a custom event handler
/// for any type of [DevToolsExtensionEventType].
///
/// When the DevTools extension receives an event from DevTools, the default
/// handler for the [DevToolsExtensionEventType] will be called (this is
/// managed automatically by package:devtools_extensions), and any custom
/// event handlers will be called after the default handler.
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
    // Example of the devtools extension registering a custom handler for an
    // event coming from DevTools.
    extensionManager.registerEventHandler(
      DevToolsExtensionEventType.unknown,
      // This callback will be called when the DevTools extension receives an
      // event of type [DevToolsExtensionEventType.unknown] from DevTools.
      (event) {
        setState(() {
          message = event.data?.toString() ?? 'unknown event';
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Text('Received an unknown event from DevTools: $message');
  }
}
