// Copyright 2025 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'dart:async';

import 'package:devtools_app_shared/ui.dart';
import 'package:dtd/dtd.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../shared/development_helpers.dart';
import '../../shared/framework/screen.dart';
import '../../shared/globals.dart';
import '../../shared/ui/common_widgets.dart';
import 'dtd_tools_controller.dart';
import 'events.dart';
import 'services.dart';
import 'shared.dart';

// TODO(https://github.com/flutter/devtools/issues/9216): ship this screen as a
// DevTools extension instead of a first party DevTools screen.

/// A screen for inspecting a Dart Tooling Daemon instance.
///
/// By default, this screen will connect to the DTD connection available from
/// DevTools, but the tool can also connect to a DTD instance manually.
class DTDToolsScreen extends Screen {
  DTDToolsScreen() : super.fromMetaData(ScreenMetaData.dtdTools);

  static final id = ScreenMetaData.dtdTools.id;

  @override
  Widget buildScreenBody(BuildContext _) => const DTDToolsScreenBody();
}

class DTDToolsScreenBody extends StatelessWidget {
  const DTDToolsScreenBody({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = screenControllers.lookup<DTDToolsController>();
    return MultiValueListenableBuilder(
      listenables: [
        controller.localDtdManager.connection,
        dtdManager.connection,
      ],
      builder: (context, values, _) {
        final activeDtdManager = controller.activeDtdManager;
        final connection = activeDtdManager.connection.value;
        return connection != null
            ? DtdConnectedView(
                dtd: connection,
                dtdUri: activeDtdManager.uri!.toString(),
                onDisconnect: activeDtdManager.disconnect,
              )
            : DtdNotConnectedView(connectDtd: controller.connectDtd);
      },
    );
  }
}

/// Displays information about a live instance of the Dart Tooling Daemon and
/// provides functionality for calling DTD service methods.
class DtdConnectedView extends StatefulWidget {
  const DtdConnectedView({
    super.key,
    required this.dtd,
    required this.dtdUri,
    required this.onDisconnect,
  });

  final DartToolingDaemon dtd;
  final String dtdUri;
  final VoidCallback onDisconnect;

  @override
  State<DtdConnectedView> createState() => _DtdConnectedViewState();
}

class _DtdConnectedViewState extends State<DtdConnectedView> {
  ServicesController? _registeredServicesController;
  EventsController? _eventsController;

  @override
  void initState() {
    super.initState();
    _registeredServicesController = ServicesController();
    _eventsController = EventsController();
    _initForDtdConnection();
  }

  @override
  void didUpdateWidget(covariant DtdConnectedView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.dtd != widget.dtd || oldWidget.dtdUri != widget.dtdUri) {
      _initForDtdConnection();
    }
  }

  @override
  void dispose() {
    _registeredServicesController?.dispose();
    _eventsController?.dispose();
    super.dispose();
  }

  void _initForDtdConnection() {
    _registeredServicesController!
      ..cancelStreamSubscriptions()
      ..dtd = widget.dtd;
    unawaited(_registeredServicesController!.init());
    _eventsController!
      ..cancelStreamSubscriptions()
      ..dtd = widget.dtd
      ..init();
    knownDtdStreams.forEach(widget.dtd.streamListen);
  }

  @override
  Widget build(BuildContext context) {
    final isGlobalDtd = widget.dtd == dtdManager.connection.value;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        SelectionArea(
          child: Padding(
            padding: const EdgeInsets.all(densePadding),
            child: Row(
              children: [
                Text('DTD connection:', style: Theme.of(context).boldTextStyle),
                const SizedBox(width: denseSpacing),
                DevToolsTooltip(
                  message:
                      'This DTD URI is being used for ${isGlobalDtd ? 'all of DevTools.' : 'this screen only.'}',
                  child: RoundedLabel(
                    labelText: isGlobalDtd ? 'Global' : 'Local',
                  ),
                ),
                const SizedBox(width: denseSpacing),
                Text(widget.dtdUri),
                const SizedBox(width: denseSpacing),
                DevToolsButton(
                  icon: Icons.close,
                  label: 'Disconnect',
                  onPressed: widget.onDisconnect,
                ),
                const Spacer(),
              ],
            ),
          ),
        ),
        const SizedBox(height: defaultSpacing),
        Expanded(
          child: SplitPane(
            axis: Axis.horizontal,
            initialFractions: const [0.6, 0.4],
            children: [
              RoundedOutlinedBorder(
                clip: true,
                child: ServicesView(controller: _registeredServicesController!),
              ),
              EventsView(controller: _eventsController!),
            ],
          ),
        ),
      ],
    );
  }
}

/// Displays a text field for entering a DTD URI to connect the DTD Tools screen
/// to.
class DtdNotConnectedView extends StatefulWidget {
  const DtdNotConnectedView({super.key, required this.connectDtd});

  final Future<void> Function(Uri, {bool connectToGlobalDtd}) connectDtd;

  @override
  State<DtdNotConnectedView> createState() => _DtdNotConnectedViewState();
}

class _DtdNotConnectedViewState extends State<DtdNotConnectedView> {
  late final TextEditingController textEditingController;

  bool _connectToGlobalDtd = false;

  String? _connectionError;

  @override
  void initState() {
    super.initState();
    textEditingController = TextEditingController();
    if (debugDtdUri != null) {
      textEditingController.text = debugDtdUri!;
    }
  }

  @override
  void dispose() {
    super.dispose();
    textEditingController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Please enter a DTD URI to connect to:'),
        const SizedBox(height: denseSpacing),
        Row(
          children: [
            Expanded(
              child: DevToolsClearableTextField(
                controller: textEditingController,
                onSubmitted: (_) => _connect(),
              ),
            ),
            if (kDebugMode) ...[
              const SizedBox(width: defaultSpacing),
              DevToolsTooltip(
                message: 'Connect all DevTools screens to this DTD URI.',
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Checkbox(
                      value: _connectToGlobalDtd,
                      onChanged: (value) =>
                          setState(() => _connectToGlobalDtd = value ?? false),
                    ),
                    const Text('Connect DevTools'),
                  ],
                ),
              ),
            ],
            const SizedBox(width: defaultSpacing),
            DevToolsButton(
              label: 'Connect',
              elevated: true,
              onPressed: _connect,
            ),
          ],
        ),
        if (_connectionError != null) ...[
          const SizedBox(height: denseSpacing),
          Text(_connectionError!, style: Theme.of(context).errorTextStyle),
        ],
      ],
    );
  }

  Future<void> _connect() async {
    setState(() {
      _connectionError = null;
    });
    try {
      await widget.connectDtd(
        Uri.parse(textEditingController.text),
        connectToGlobalDtd: _connectToGlobalDtd,
      );
    } catch (error) {
      setState(() {
        _connectionError = error.toString();
      });
    }
  }
}
