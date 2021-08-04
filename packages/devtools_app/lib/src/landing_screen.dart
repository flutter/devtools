// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'blocking_action_mixin.dart';
import 'common_widgets.dart';
import 'config_specific/import_export/import_export.dart';
import 'file_import.dart';
import 'framework/framework_core.dart';
import 'globals.dart';
import 'notifications.dart';
import 'routing.dart';
import 'theme.dart';
import 'ui/label.dart';
import 'url_utils.dart';

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

class _LandingScreenBodyState extends State<LandingScreenBody>
    with BlockingActionMixin {
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
    return Scrollbar(
      child: ListView(
        children: [
          _buildConnectDialog(),
          const SizedBox(height: defaultSpacing),
          _buildImportInstructions(),
          const SizedBox(height: defaultSpacing),
          _buildAppSizeInstructions(),
        ],
      ),
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

  Widget _buildImportInstructions() {
    return _buildSection(
      title: 'Load DevTools Data',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _subtitleText(
              'Import a data file to use DevTools without an app connection.'),
          const SizedBox(height: denseRowSpacing),
          _captionText(
              'At this time, DevTools only supports importing files that were originally'
              ' exported from DevTools.'),
          const SizedBox(height: defaultSpacing),
          ElevatedButton(
            onPressed: _importFile,
            child: const MaterialIconLabel(
              label: 'Import File',
              iconData: Icons.file_upload,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _importFile() async {
    final importedFile = await importFileFromPicker(
      acceptedTypes: ['json'],
    );
    Provider.of<ImportController>(context, listen: false)
        .importData(importedFile);
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
          const SizedBox(height: defaultSpacing),
          ElevatedButton(
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            SizedBox(
              width: 350.0,
              child: TextField(
                onSubmitted: actionInProgress ? null : (str) => _connect(),
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
            ),
            const SizedBox(width: defaultSpacing),
            ElevatedButton(
              child: const Text('Connect'),
              onPressed: actionInProgress ? null : _connect,
            ),
          ],
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
    );
  }

  Future<void> _connect() async {
    assert(!actionInProgress);
    await blockWhileInProgress(_connectHelper);
  }

  Future<void> _connectHelper() async {
    if (connectDialogController.text?.isEmpty ?? true) {
      Notifications.of(context).push(
        'Please enter a VM Service URL.',
      );
      return;
    }

    final uri = normalizeVmServiceUri(connectDialogController.text);
    // Cache the routerDelegate and notifications providers before the async
    // gap as the landing screen may not be displayed by the time the async gap
    // is complete but we still want to show notifications and change the route.
    // TODO(jacobr): better understand why this is the case. It is  bit counter
    // intuitive that we don't want to just cancel the route change or
    // notification if we are already on a different screen.
    final routerDelegate = DevToolsRouterDelegate.of(context);
    final notifications = Notifications.of(context);
    final connected = await FrameworkCore.initVmService(
      '',
      explicitUri: uri,
      errorReporter: (message, error) {
        notifications.push('$message $error');
      },
    );
    if (connected) {
      final connectedUri = serviceManager.service.connectedUri;
      routerDelegate.updateArgsIfNotCurrent({'uri': '$connectedUri'});
      final shortUri = connectedUri.replace(path: '');
      notifications.push(
        'Successfully connected to $shortUri.',
      );
    } else if (uri == null) {
      notifications.push(
        'Failed to connect to the VM Service at "${connectDialogController.text}".\n'
        'The link was not valid.',
      );
    }
  }
}
