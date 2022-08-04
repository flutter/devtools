// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_shared/devtools_shared.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../analytics/analytics.dart' as ga;
import '../analytics/constants.dart' as analytics_constants;
import '../config_specific/import_export/import_export.dart';
import '../primitives/blocking_action_mixin.dart';
import '../primitives/utils.dart';
import '../shared/common_widgets.dart';
import '../shared/file_import.dart';
import '../shared/globals.dart';
import '../shared/notifications.dart';
import '../shared/routing.dart';
import '../shared/theme.dart';
import '../shared/utils.dart';
import '../ui/label.dart';
import 'framework_core.dart';

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
  @override
  void initState() {
    super.initState();
    ga.screen(analytics_constants.landingScreen);
  }

  @override
  Widget build(BuildContext context) {
    return Scrollbar(
      child: ListView(
        children: const [
          ConnectDialog(),
          SizedBox(height: defaultSpacing),
          ImportFileInstructions(),
          SizedBox(height: defaultSpacing),
          AppSizeToolingInstructions(),
        ],
      ),
    );
  }
}

class LandingScreenSection extends StatelessWidget {
  const LandingScreenSection({
    Key? key,
    required this.title,
    required this.child,
  }) : super(key: key);

  final String title;

  final Widget child;

  @override
  Widget build(BuildContext context) {
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
        PaddedDivider.vertical(padding: 10.0),
      ],
    );
  }
}

class ConnectDialog extends StatefulWidget {
  const ConnectDialog({Key? key}) : super(key: key);

  @override
  _ConnectDialogState createState() => _ConnectDialogState();
}

class _ConnectDialogState extends State<ConnectDialog>
    with BlockingActionMixin {
  late final TextEditingController connectDialogController;

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
    return LandingScreenSection(
      title: 'Connect',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Connect to a Running App',
            style: Theme.of(context).textTheme.subtitle1,
          ),
          const SizedBox(height: denseRowSpacing),
          Text(
            'Enter a URL to a running Dart or Flutter application',
            style: Theme.of(context).textTheme.caption,
          ),
          const Padding(padding: EdgeInsets.only(top: 20.0)),
          _buildConnectInput(),
        ],
      ),
    );
  }

  Widget _buildConnectInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            SizedBox(
              width: scaleByFontFactor(350.0),
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
              onPressed: actionInProgress ? null : _connect,
              child: const Text('Connect'),
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
    ga.select(
      analytics_constants.landingScreen,
      analytics_constants.connectToApp,
    );
    if (connectDialogController.text.isEmpty) {
      Notifications.of(context)!.push('Please enter a VM Service URL.');
      return;
    }

    final uri = normalizeVmServiceUri(connectDialogController.text);
    // Cache the routerDelegate and notifications providers before the async
    // gap as the landing screen may not be displayed by the time the async gap
    // is complete but we still want to show notifications and change the route.
    // TODO(jacobr): better understand why this is the case. It is bit counter
    // intuitive that we don't want to just cancel the route change or
    // notification if we are already on a different screen.
    final routerDelegate = DevToolsRouterDelegate.of(context);
    final notifications = Notifications.of(context)!;
    final connected = await FrameworkCore.initVmService(
      '',
      explicitUri: uri,
      errorReporter: (message, error) {
        notifications.push('$message $error');
      },
    );
    if (connected) {
      final connectedUri = serviceManager.service!.connectedUri;
      routerDelegate.updateArgsIfNotCurrent({'uri': '$connectedUri'});
      final shortUri = connectedUri.replace(path: '');
      notifications.push('Successfully connected to $shortUri.');
    } else if (uri == null) {
      notifications.push(
        'Failed to connect to the VM Service at "${connectDialogController.text}".\n'
        'The link was not valid.',
      );
    }
  }
}

class ImportFileInstructions extends StatelessWidget {
  const ImportFileInstructions({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return LandingScreenSection(
      title: 'Load DevTools Data',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Import a data file to use DevTools without an app connection.',
            style: Theme.of(context).textTheme.subtitle1,
          ),
          const SizedBox(height: denseRowSpacing),
          Text(
            'At this time, DevTools only supports importing files that were originally'
            ' exported from DevTools.',
            style: Theme.of(context).textTheme.caption,
          ),
          const SizedBox(height: defaultSpacing),
          ElevatedButton(
            onPressed: () => _importFile(context),
            child: const MaterialIconLabel(
              label: 'Import File',
              iconData: Icons.file_upload,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _importFile(BuildContext context) async {
    ga.select(
      analytics_constants.landingScreen,
      analytics_constants.importFile,
    );
    final DevToolsJsonFile? importedFile = await importFileFromPicker(
      acceptedTypes: ['json'],
    );

    if (importedFile != null) {
      Provider.of<ImportController>(context, listen: false)
          .importData(importedFile);
    }
  }
}

class AppSizeToolingInstructions extends StatelessWidget {
  const AppSizeToolingInstructions({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return LandingScreenSection(
      title: 'App Size Tooling',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Analyze and view diffs for your app\'s size',
            style: Theme.of(context).textTheme.subtitle1,
          ),
          const SizedBox(height: denseRowSpacing),
          Text(
            'Load Dart AOT snapshots or app size analysis files to '
            'track down size issues in your app.',
            style: Theme.of(context).textTheme.caption,
          ),
          const SizedBox(height: defaultSpacing),
          ElevatedButton(
            child: const Text('Open app size tool'),
            onPressed: () => _onOpenAppSizeToolSelected(context),
          ),
        ],
      ),
    );
  }

  void _onOpenAppSizeToolSelected(BuildContext context) {
    ga.select(
      analytics_constants.landingScreen,
      analytics_constants.openAppSizeTool,
    );
    DevToolsRouterDelegate.of(context).navigate(appSizePageId);
  }
}
