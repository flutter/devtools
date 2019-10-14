// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../src/framework/framework_core.dart';
import 'common_widgets.dart';
import 'screen.dart';

/// The screen in the app responsible for connecting to the Dart VM.
///
/// We need to use this screen to get a guarantee that the app has a
/// Dart VM available.
class ConnectScreen extends Screen {
  const ConnectScreen() : super('Connect');

  @override
  Widget build(BuildContext context) => ConnectScreenBody();

  @override
  Widget buildTab(BuildContext context) {
    // ConnectScreen doesn't have a tab.
    return null;
  }
}

class ConnectScreenBody extends StatefulWidget {
  @override
  State<ConnectScreenBody> createState() => _ConnectScreenBodyState();
}

class _ConnectScreenBodyState extends State<ConnectScreenBody> {
  TextEditingController controller;

  @override
  void initState() {
    super.initState();
    controller = TextEditingController();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Connect',
          style: textTheme.headline,
          key: const Key('Connect Title'),
        ),
        const PaddedDivider(),
        Text(
          'Connect to a running app',
          style: textTheme.body2,
        ),
        Text(
          'Enter a URL to a running Dart or Flutter application',
          style: textTheme.caption,
        ),
        const Padding(padding: EdgeInsets.only(top: 20.0)),
        _buildTextInput(),
        // Workaround the lack of copy/paste in macOS shell text input
        // https://github.com/flutter/flutter/issues/30709
        // by providing a manual paste button.
        if (!kIsWeb)
          RaisedButton(
            child: const Text(
              'Paste from clipboard (Flutter Desktop paste support workaround)',
            ),
            onPressed: () async {
              final data = await Clipboard.getData('text/plain');
              if (data?.text?.isNotEmpty == true) {
                controller.text = data?.text;
              }
            },
          ),
        const PaddedDivider(padding: EdgeInsets.symmetric(vertical: 10.0)),
        // TODO(https://github.com/flutter/devtools/issues/1111): support drag-and-drop of snapshot files here.
      ],
    );
  }

  Widget _buildTextInput() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        SizedBox(
          width: 240.0,
          child: TextField(
            onSubmitted: _connect,
            decoration: const InputDecoration(
              isDense: true,
              border: OutlineInputBorder(),
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(width: 0.5, color: Colors.grey),
              ),
              hintText: 'URL',
            ),
            maxLines: 1,
            controller: controller,
          ),
        ),
        const Padding(
          padding: EdgeInsets.only(left: 20.0),
        ),
        RaisedButton(
          child: const Text('Connect'),
          onPressed: _connect,
        ),
      ],
    );
  }

  Future<void> _connect([_]) async {
    final uri = Uri.parse(controller.text);
    final bool connected = await FrameworkCore.initVmService(
      '',
      explicitUri: uri,
      errorReporter: (title, error) {
        Scaffold.of(context).showSnackBar(
          SnackBar(content: Text(title)),
        );
      },
    );

    if (connected) {
      final uriQuery = 'uri=${Uri.encodeQueryComponent(controller.text)}';
      return Navigator.popAndPushNamed(context, '/?$uriQuery');
    }
  }
}
