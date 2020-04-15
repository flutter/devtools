// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:pedantic/pedantic.dart';

import '../../src/framework/framework_core.dart';
import '../url_utils.dart';
import '../utils.dart';
import 'common_widgets.dart';
import 'navigation.dart';
import 'notifications.dart';
import 'screen.dart';
import 'theme.dart';

/// The screen in the app responsible for connecting to the Dart VM.
///
/// We need to use this screen to get a guarantee that the app has a Dart VM
/// available.
class ConnectScreen extends Screen {
  const ConnectScreen() : super(DevToolsScreenType.connect, title: 'Connect');

  @override
  Widget build(BuildContext context) => ConnectScreenBody();
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
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Connect',
              style: textTheme.headline5,
              key: const Key('Connect Title'),
            ),
            const PaddedDivider(),
            Text(
              'Connect to a Running App',
              style: textTheme.bodyText1,
            ),
            const SizedBox(height: denseRowSpacing),
            Text(
              'Enter a URL to a running Dart or Flutter application',
              style: textTheme.caption,
            ),
            const Padding(padding: EdgeInsets.only(top: 20.0)),
            _buildTextInput(),
            const PaddedDivider(padding: EdgeInsets.symmetric(vertical: 10.0)),
            // TODO(https://github.com/flutter/devtools/issues/1111): support
            // drag-and-drop of snapshot files here.
          ],
        ),
      ],
    );
  }

  Widget _buildTextInput() {
    final CallbackDwell connectDebounce = CallbackDwell(_connect);

    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        SizedBox(
          width: 350.0,
          child: TextField(
            onSubmitted: (str) => connectDebounce.invoke(),
            autofocus: true,
            decoration: const InputDecoration(
              isDense: true,
              border: OutlineInputBorder(),
              enabledBorder: OutlineInputBorder(
                // TODO(jacobr): we need to use themed colors everywhere instead
                // of hard coding material colors.
                borderSide: BorderSide(width: 0.5, color: Colors.grey),
              ),
              hintText: 'http://127.0.0.1:12345/auth_code=',
            ),
            controller: controller,
          ),
        ),
        const Padding(
          padding: EdgeInsets.only(left: 20.0),
        ),
        RaisedButton(
          child: const Text('Connect'),
          onPressed: connectDebounce.invoke,
        ),
      ],
    );
  }

  Future<void> _connect() async {
    final uri = normalizeVmServiceUri(controller.text);
    final connected = await FrameworkCore.initVmService(
      '',
      explicitUri: uri,
      errorReporter: (message, error) {
        Notifications.of(context).push('$message $error');
      },
    );
    if (connected) {
      unawaited(
        Navigator.popAndPushNamed(
          context,
          routeNameWithQueryParams(context, '/', {'uri': '$uri'}),
        ),
      );
      final shortUri = uri.replace(path: '');
      Notifications.of(context).push(
        'Successfully connected to $shortUri.',
      );
    } else if (uri == null) {
      Notifications.of(context).push(
        'Failed to connect to the VM Service at "${controller.text}".\n'
        'The link was not valid.',
      );
    }
  }
}
