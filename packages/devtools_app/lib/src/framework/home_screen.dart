// Copyright 2019 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'dart:async';

import 'package:devtools_app_shared/ui.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:devtools_shared/devtools_shared.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../service/connected_app/connection_info.dart';
import '../shared/analytics/analytics.dart' as ga;
import '../shared/analytics/constants.dart' as gac;
import '../shared/config_specific/import_export/import_export.dart';
import '../shared/framework/routing.dart';
import '../shared/framework/screen.dart';
import '../shared/globals.dart';
import '../shared/primitives/blocking_action_mixin.dart';
import '../shared/primitives/utils.dart';
import '../shared/title.dart';
import '../shared/ui/vm_flag_widgets.dart';
import 'framework_core.dart';

class HomeScreen extends Screen {
  HomeScreen({this.sampleData = const []})
    : super.fromMetaData(
        ScreenMetaData.home,
        titleGenerator: () => devToolsTitle.value,
      );

  static final id = ScreenMetaData.home.id;

  final List<DevToolsJsonFile> sampleData;

  @override
  Widget buildScreenBody(BuildContext context) {
    return HomeScreenBody(sampleData: sampleData);
  }
}

class HomeScreenBody extends StatefulWidget {
  const HomeScreenBody({super.key, this.sampleData = const []});

  final List<DevToolsJsonFile> sampleData;

  @override
  State<HomeScreenBody> createState() => _HomeScreenBodyState();
}

class _HomeScreenBodyState extends State<HomeScreenBody> with AutoDisposeMixin {
  @override
  void initState() {
    super.initState();
    ga.screen(gac.home);

    addAutoDisposeListener(serviceConnection.serviceManager.connectedState);
  }

  @override
  Widget build(BuildContext context) {
    final connected =
        serviceConnection.serviceManager.connectedState.value.connected &&
        serviceConnection.serviceManager.connectedAppInitialized;
    return Scrollbar(
      child: ListView(
        children: [
          ConnectionSection(connected: connected),
          if (widget.sampleData.isNotEmpty && !kReleaseMode && !connected) ...[
            SampleDataDropDownButton(sampleData: widget.sampleData),
            const SizedBox(height: defaultSpacing),
          ],
        ],
      ),
    );
  }
}

class ConnectionSection extends StatelessWidget {
  const ConnectionSection({super.key, required this.connected});

  static const _primaryMinScreenWidthForTextBeforeScaling = 480.0;
  static const _secondaryMinScreenWidthForTextBeforeScaling = 600.0;

  final bool connected;

  @override
  Widget build(BuildContext context) {
    if (connected) {
      return LandingScreenSection(
        title: 'Connected app',
        actions: [
          ViewVmFlagsButton(
            gaScreen: gac.home,
            minScreenWidthForTextBeforeScaling:
                _secondaryMinScreenWidthForTextBeforeScaling,
          ),
          const SizedBox(width: defaultSpacing),
          ConnectToNewAppButton(
            gaScreen: gac.home,
            minScreenWidthForTextBeforeScaling:
                _primaryMinScreenWidthForTextBeforeScaling,
            routerDelegate: DevToolsRouterDelegate.of(context),
            onPressed:
                () => Navigator.of(context, rootNavigator: true).pop('dialog'),
          ),
        ],
        child: const ConnectedAppSummary(narrowView: false),
      );
    }
    return const ConnectInput();
  }
}

class LandingScreenSection extends StatelessWidget {
  const LandingScreenSection({
    super.key,
    required this.title,
    required this.child,
    this.actions = const [],
  });

  final String title;

  final Widget child;

  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(title, style: textTheme.headlineMedium)),
            ...actions,
          ],
        ),
        const PaddedDivider(),
        child,
        PaddedDivider.vertical(padding: 10.0),
      ],
    );
  }
}

class ConnectInput extends StatefulWidget {
  const ConnectInput({super.key});

  @override
  State<ConnectInput> createState() => _ConnectInputState();
}

class _ConnectInputState extends State<ConnectInput> with BlockingActionMixin {
  late final TextEditingController connectDialogController;

  /// The key for the VM Service URI we cache in storage for the purpose of
  /// speeding up the DevTools development cycle.
  static const _debugVmServiceUriKey = 'debug_vmServiceUri';

  @override
  void initState() {
    super.initState();
    connectDialogController = TextEditingController();
    assert(() {
      _debugInitVmServiceCache();
      return true;
    }());
  }

  void _debugInitVmServiceCache() async {
    // We only do this in debug mode as it speeds iteration for DevTools
    // developers who tend to repeatedly restart DevTools to debug the same
    // test application.
    final uri = await storage.getValue(_debugVmServiceUriKey);
    if (uri != null) {
      setState(() {
        connectDialogController.text = uri;
      });
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
              height: defaultTextFieldHeight,
              width: scaleByFontFactor(350.0),
              child: DevToolsClearableTextField(
                labelText: 'URL',
                onSubmitted:
                    actionInProgress ? null : (str) => unawaited(_connect()),
                autofocus: true,
                controller: connectDialogController,
              ),
            ),
            const SizedBox(width: defaultSpacing),
            DevToolsButton(
              onPressed: actionInProgress ? null : () => unawaited(_connect()),
              elevated: true,
              label: 'Connect',
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: densePadding),
          child: Text(
            '(e.g., http://127.0.0.1:12345/auth_code=... or ws://...)',
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
          Text('Connect to a Running App', style: textTheme.titleMedium),
          const SizedBox(height: denseRowSpacing),
          Text('Enter a Dart VM Service URL', style: textTheme.bodySmall),
          const SizedBox(height: denseSpacing),
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
    ga.select(gac.home, gac.HomeScreenEvents.connectToApp.name);

    final uri = connectDialogController.text;
    if (uri.isEmpty) {
      notificationService.push('Please enter a VM Service URL.');
      return;
    }

    assert(() {
      storage.setValue(_debugVmServiceUriKey, uri);
      return true;
    }());

    // Cache the routerDelegate and notifications providers before the async
    // gap as the landing screen may not be displayed by the time the async gap
    // is complete but we still want to show notifications and change the route.
    // TODO(jacobr): better understand why this is the case. It is bit counter
    // intuitive that we don't want to just cancel the route change or
    // notification if we are already on a different screen.
    final routerDelegate = DevToolsRouterDelegate.of(context);
    final connected = await FrameworkCore.initVmService(
      serviceUriAsString: uri,
    );
    if (connected) {
      final connectedUri = Uri.parse(
        serviceConnection.serviceManager.serviceUri!,
      );
      await routerDelegate.updateArgsIfChanged({'uri': '$connectedUri'});
      final shortUri = connectedUri.replace(path: '');
      notificationService.push('Successfully connected to $shortUri.');
    } else if (normalizeVmServiceUri(uri) == null) {
      notificationService.push(
        'Failed to connect to the VM Service at "${connectDialogController.text}".\n'
        'The link was not valid.',
      );
    }
  }
}

class SampleDataDropDownButton extends StatefulWidget {
  const SampleDataDropDownButton({super.key, this.sampleData = const []});

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
          items: [for (final data in widget.sampleData) _buildMenuItem(data)],
          onChanged:
              (file) => setState(() {
                value = file;
              }),
        ),
        const SizedBox(width: defaultSpacing),
        ElevatedButton(
          onPressed:
              value == null
                  ? null
                  : () => Provider.of<ImportController>(
                    context,
                    listen: false,
                  ).importData(value!),
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
