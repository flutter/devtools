// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'common_widgets.dart';
import 'framework/framework_core.dart';
import 'globals.dart';
import 'notifications.dart';
import 'routing.dart';
import 'theme.dart';
import 'url_utils.dart';
import 'utils.dart';

/// The landing screen when starting Dart DevTools without being connected to an
/// app.
///
/// We need to use this screen to get a guarantee that the app has a Dart VM
/// available as well as to provide access to other functionality that does not
/// require a connected Dart application.
class LandingScreenBody extends StatefulWidget {
  @override
  State<LandingScreenBody> createState() => _LandingScreenBodyState();
}

class _LandingScreenBodyState extends State<LandingScreenBody> {
  TextEditingController connectDialogController;

  @override
  void initState() {
    super.initState();
    connectDialogController = TextEditingController();
  }

  @override
  void dispose() {
    connectDialogController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildConnectDialog(),
        const SizedBox(height: defaultSpacing),
        _buildAppSizeInstructions(),
      ],
    );
  }

  Widget _buildConnectDialog() {
    return _buildSection(
      title: 'Connect',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _subtitleText('Connect to a Running App'),
          const SizedBox(height: denseRowSpacing),
          _captionText('Enter a URL to a running Dart or Flutter application'),
          const Padding(padding: EdgeInsets.only(top: 20.0)),
          _buildConnectInput(),
        ],
      ),
    );
  }

  Widget _buildAppSizeInstructions() {
    return _buildSection(
      title: 'App Size Tooling',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _subtitleText('Analyze and view diffs for your app\'s size'),
          const SizedBox(height: denseRowSpacing),
          _captionText('Load Dart AOT snapshots or app size analysis files to '
              'track down size issues in your app.'),
          const Padding(padding: EdgeInsets.only(top: 20.0)),
          RaisedButton(
            child: const Text('Open app size tool'),
            onPressed: () =>
                DevToolsRouterDelegate.of(context).navigate(appSizePageId),
          ),
        ],
      ),
    );
  }

  Widget _buildSection({@required String title, @required Widget child}) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: textTheme.headline5,
        ),
        const PaddedDivider(),
        child,
        const PaddedDivider(padding: EdgeInsets.symmetric(vertical: 10.0)),
      ],
    );
  }

  Widget _subtitleText(String text) {
    return Text(
      text,
      style: Theme.of(context).textTheme.subtitle1,
    );
  }

  Widget _captionText(String text) {
    return Text(
      text,
      style: Theme.of(context).textTheme.caption,
    );
  }

  Widget _buildConnectInput() {
    final CallbackDwell connectDebounce = CallbackDwell(_connect);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 350.0,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
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
                ),
                controller: connectDialogController,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Text(
                  '(e.g., http://127.0.0.1:12345/auth_code=...)',
                  textAlign: TextAlign.start,
                  style: Theme.of(context).textTheme.caption,
                ),
              ),
            ],
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
    if (connectDialogController.text?.isEmpty ?? true) {
      Notifications.of(context).push(
        'Please enter a VM Service URL.',
      );
      return;
    }

    final uri = normalizeVmServiceUri(connectDialogController.text);
    final connected = await FrameworkCore.initVmService(
      '',
      explicitUri: uri,
      errorReporter: (message, error) {
        Notifications.of(context).push('$message $error');
      },
    );
    if (connected) {
      final connectedUri = serviceManager.service.connectedUri;
      DevToolsRouterDelegate.of(context)
          .updateArgsIfNotCurrent({'uri': '$connectedUri'});
      final shortUri = connectedUri.replace(path: '');
      Notifications.of(context).push(
        'Successfully connected to $shortUri.',
      );
    } else if (uri == null) {
      Notifications.of(context).push(
        'Failed to connect to the VM Service at "${connectDialogController.text}".\n'
        'The link was not valid.',
      );
    }
  }
}
