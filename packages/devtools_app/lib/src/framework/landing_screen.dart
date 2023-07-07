// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:devtools_shared/devtools_shared.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../shared/analytics/analytics.dart' as ga;
import '../shared/analytics/constants.dart' as gac;
import '../shared/common_widgets.dart';
import '../shared/config_specific/import_export/import_export.dart';
import '../shared/feature_flags.dart';
import '../shared/globals.dart';
import '../shared/primitives/blocking_action_mixin.dart';
import '../shared/primitives/utils.dart';
import '../shared/routing.dart';
import '../shared/theme.dart';
import '../shared/ui/label.dart';
import '../shared/utils.dart';
import 'framework_core.dart';

/// The landing screen when starting Dart DevTools without being connected to an
/// app.
///
/// We need to use this screen to get a guarantee that the app has a Dart VM
/// available as well as to provide access to other functionality that does not
/// require a connected Dart application.
class LandingScreenBody extends StatefulWidget {
  const LandingScreenBody({super.key, this.sampleData = const []});

  final List<DevToolsJsonFile> sampleData;

  @override
  State<LandingScreenBody> createState() => _LandingScreenBodyState();
}

class _LandingScreenBodyState extends State<LandingScreenBody> {
  @override
  void initState() {
    super.initState();
    ga.screen(gac.landingScreen);
  }

  @override
  Widget build(BuildContext context) {
    return Scrollbar(
      child: ListView(
        children: [
          const ConnectDialog(),
          const SizedBox(height: defaultSpacing),
          const AppSizeToolingInstructions(),
          if (FeatureFlags.memoryAnalysis) ...[
            const SizedBox(height: defaultSpacing),
            const MemoryAnalysisInstructions(),
          ],
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
          style: textTheme.titleLarge,
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
  State<ConnectDialog> createState() => _ConnectDialogState();
}

class _ConnectDialogState extends State<ConnectDialog>
    with BlockingActionMixin {
  late final TextEditingController connectDialogController;

  SharedPreferences? _debugSharedPreferences;
  static const _vmServiceUriKey = 'vmServiceUri';
  @override
  void initState() {
    super.initState();
    connectDialogController = TextEditingController();
    assert(() {
      _debugInitSharedPreferences();
      return true;
    }());
  }

  void _debugInitSharedPreferences() async {
    // We only do this in debug mode as it speeds iteration for DevTools
    // developers who tend to repeatedly restart DevTools to debug the same
    // test application.
    _debugSharedPreferences = await SharedPreferences.getInstance();
    if (_debugSharedPreferences != null && mounted) {
      final uri = _debugSharedPreferences!.getString(_vmServiceUriKey);
      if (uri != null) {
        connectDialogController.text = uri;
      }
    }
  }

  @override
  void dispose() {
    connectDialogController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    final connectorInput = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            SizedBox(
              width: scaleByFontFactor(350.0),
              child: TextField(
                onSubmitted:
                    actionInProgress ? null : (str) => unawaited(_connect()),
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
              onPressed: actionInProgress ? null : () => unawaited(_connect()),
              child: const Text('Connect'),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Text(
            '(e.g., http://127.0.0.1:12345/auth_code=...)',
            textAlign: TextAlign.start,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      ],
    );

    return LandingScreenSection(
      title: 'Connect',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Connect to a Running App',
            style: textTheme.titleMedium,
          ),
          const SizedBox(height: denseRowSpacing),
          Text(
            'Enter a URL to a running Dart or Flutter application',
            style: textTheme.bodySmall,
          ),
          const Padding(padding: EdgeInsets.only(top: 20.0)),
          connectorInput,
        ],
      ),
    );
  }

  Future<void> _connect() async {
    assert(!actionInProgress);
    await blockWhileInProgress(_connectHelper);
  }

  Future<void> _connectHelper() async {
    ga.select(
      gac.landingScreen,
      gac.connectToApp,
    );
    if (connectDialogController.text.isEmpty) {
      notificationService.push('Please enter a VM Service URL.');
      return;
    }

    assert(() {
      if (_debugSharedPreferences != null) {
        _debugSharedPreferences!
            .setString(_vmServiceUriKey, connectDialogController.text);
      }
      return true;
    }());

    final uri = normalizeVmServiceUri(connectDialogController.text);
    // Cache the routerDelegate and notifications providers before the async
    // gap as the landing screen may not be displayed by the time the async gap
    // is complete but we still want to show notifications and change the route.
    // TODO(jacobr): better understand why this is the case. It is bit counter
    // intuitive that we don't want to just cancel the route change or
    // notification if we are already on a different screen.
    final routerDelegate = DevToolsRouterDelegate.of(context);
    final connected = await FrameworkCore.initVmService(
      '',
      explicitUri: uri,
      errorReporter: (message, error) {
        notificationService.pushError(
          '$message $error',
          isReportable: false,
        );
      },
    );
    if (connected) {
      final connectedUri = serviceManager.service!.connectedUri;
      routerDelegate.updateArgsIfChanged({'uri': '$connectedUri'});
      final shortUri = connectedUri.replace(path: '');
      notificationService.push('Successfully connected to $shortUri.');
    } else if (uri == null) {
      notificationService.push(
        'Failed to connect to the VM Service at "${connectDialogController.text}".\n'
        'The link was not valid.',
      );
    }
  }
}

class AppSizeToolingInstructions extends StatelessWidget {
  const AppSizeToolingInstructions({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return LandingScreenSection(
      title: 'App Size Tooling',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Analyze and view diffs for your app\'s size',
            style: textTheme.titleMedium,
          ),
          const SizedBox(height: denseRowSpacing),
          Text(
            'Load Dart AOT snapshots or app size analysis files to '
            'track down size issues in your app.',
            style: textTheme.bodySmall,
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
      gac.landingScreen,
      gac.openAppSizeTool,
    );
    DevToolsRouterDelegate.of(context).navigate(appSizeScreenId);
  }
}

@visibleForTesting
class MemoryAnalysisInstructions extends StatelessWidget {
  const MemoryAnalysisInstructions({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return LandingScreenSection(
      title: 'Memory Analysis',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Analyze and diff the saved memory snapshots',
            style: textTheme.titleMedium,
          ),
          const SizedBox(height: denseRowSpacing),
          Text(
            // TODO(polina-c): make package:leak_tracker a link.
            // https://github.com/flutter/devtools/issues/5606
            'Analyze heap snapshots that were previously saved from DevTools or package:leak_tracker.',
            style: textTheme.bodySmall,
          ),
          const SizedBox(height: defaultSpacing),
          ElevatedButton(
            child: const Text('Open memory analysis tool'),
            onPressed: () => _onOpen(context),
          ),
        ],
      ),
    );
  }

  void _onOpen(BuildContext context) {
    ga.select(
      gac.landingScreen,
      gac.openMemoryAnalysisTool,
    );
    DevToolsRouterDelegate.of(context).navigate(memoryAnalysisScreenId);
  }
}

class SampleDataDropDownButton extends StatefulWidget {
  const SampleDataDropDownButton({
    super.key,
    this.sampleData = const [],
  });

  final List<DevToolsJsonFile> sampleData;

  @override
  State<SampleDataDropDownButton> createState() =>
      _SampleDataDropDownButtonState();
}

class _SampleDataDropDownButtonState extends State<SampleDataDropDownButton> {
  DevToolsJsonFile? value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        RoundedDropDownButton<DevToolsJsonFile>(
          value: value,
          items: [
            for (final data in widget.sampleData) _buildMenuItem(data),
          ],
          onChanged: (file) => setState(() {
            value = file;
          }),
        ),
        const SizedBox(width: defaultSpacing),
        ElevatedButton(
          onPressed: value == null
              ? null
              : () => Provider.of<ImportController>(context, listen: false)
                  .importData(value!),
          child: const MaterialIconLabel(
            label: 'Load sample data',
            iconData: Icons.file_upload,
          ),
        ),
      ],
    );
  }

  DropdownMenuItem<DevToolsJsonFile> _buildMenuItem(DevToolsJsonFile file) {
    return DropdownMenuItem<DevToolsJsonFile>(
      value: file,
      child: Text(file.path),
    );
  }
}
