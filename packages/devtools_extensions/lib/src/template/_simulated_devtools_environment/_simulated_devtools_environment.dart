// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:js_interop';
import 'dart:math' as math;

import 'package:devtools_app_shared/service.dart';
import 'package:devtools_app_shared/ui.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:web/web.dart' hide Text, Clipboard;

import '../../api/api.dart';
import '../../api/model.dart';
import '../../utils.dart';
import '../devtools_extension.dart';

part '_simulated_devtools_controller.dart';
part 'connection_ui/_connect.dart';
part 'connection_ui/_dtd_connect.dart';
part 'connection_ui/_vm_service_connect.dart';

/// Wraps [child] in a simulated DevTools environment.
///
/// The simulated environment implements and exposes the same extension host
/// APIs that DevTools does.
///
/// To use this wrapper, set the 'use_simulated_environment' environment
/// variable to true. See [_simulatedEnvironmentEnabled] from
/// `devtools_extension.dart`.
class SimulatedDevToolsWrapper extends StatefulWidget {
  const SimulatedDevToolsWrapper({
    super.key,
    required this.child,
    required this.requiresRunningApplication,
    required this.onDtdConnectionChange,
  });

  final Widget child;

  final bool requiresRunningApplication;

  final Future<void> Function(String?) onDtdConnectionChange;

  @override
  State<SimulatedDevToolsWrapper> createState() =>
      SimulatedDevToolsWrapperState();
}

@visibleForTesting
class SimulatedDevToolsWrapperState extends State<SimulatedDevToolsWrapper>
    with AutoDisposeMixin {
  late final SimulatedDevToolsController simController;

  late final ScrollController scrollController;

  bool get vmServiceConnected => vmServiceConnectionState.connected;
  late ConnectedState vmServiceConnectionState;

  bool dtdConnected = false;

  @override
  void initState() {
    super.initState();
    simController = SimulatedDevToolsController()..init();

    scrollController = ScrollController();

    vmServiceConnectionState = serviceManager.connectedState.value;
    addAutoDisposeListener(serviceManager.connectedState, () {
      setState(() {
        vmServiceConnectionState = serviceManager.connectedState.value;
      });
    });

    dtdConnected = dtdManager.hasConnection;
    addAutoDisposeListener(dtdManager.connection, () {
      setState(() {
        dtdConnected = dtdManager.hasConnection;
      });
    });
  }

  @override
  void dispose() {
    simController.dispose();
    scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth;
        const environmentPanelMinWidth =
            VmServiceConnectionDisplay.totalControlsWidth + 2 * defaultSpacing;

        final environmentPanelFraction =
            environmentPanelMinWidth / availableWidth;
        final childFraction = 1 - environmentPanelFraction;

        return SplitPane(
          axis: Axis.horizontal,
          initialFractions: [childFraction, environmentPanelFraction],
          minSizes: const [100.0, 0.0],
          children: [
            OutlineDecoration.onlyRight(
              child: Padding(
                padding: const EdgeInsets.all(defaultSpacing),
                child: widget.child,
              ),
            ),
            LayoutBuilder(
              builder: (context, environmentPanelConstraints) {
                final availableEnvironmentPanelWidth =
                    environmentPanelConstraints.maxWidth;
                final environmentPanelWidth = math.max(
                  environmentPanelMinWidth,
                  availableEnvironmentPanelWidth,
                );

                return Scrollbar(
                  controller: scrollController,
                  thumbVisibility: true,
                  child: SingleChildScrollView(
                    controller: scrollController,
                    scrollDirection: Axis.horizontal,
                    child: SizedBox(
                      width: environmentPanelWidth,
                      child: OutlineDecoration.onlyLeft(
                        child: Padding(
                          padding: const EdgeInsets.all(defaultSpacing),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Simulated DevTools Environment',
                                style: theme.textTheme.titleMedium,
                              ),
                              const PaddedDivider(),
                              VmServiceConnectionDisplay(
                                connected: vmServiceConnected,
                                simController: simController,
                              ),
                              const PaddedDivider(),
                              DTDConnectionDisplay(
                                simController: simController,
                                connected: dtdConnected,
                                onConnectionChange:
                                    widget.onDtdConnectionChange,
                              ),
                              _SimulatedApi(
                                simController: simController,
                                requiresRunningApplication:
                                    widget.requiresRunningApplication,
                                connectedToApplication: vmServiceConnected,
                              ),
                              const PaddedDivider(),
                              Expanded(
                                child: _LogsView(simController: simController),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }
}

class _SimulatedApi extends StatelessWidget {
  const _SimulatedApi({
    required this.simController,
    required this.requiresRunningApplication,
    required this.connectedToApplication,
  });

  final SimulatedDevToolsController simController;

  final bool requiresRunningApplication;

  final bool connectedToApplication;

  @override
  Widget build(BuildContext context) {
    if (requiresRunningApplication && !connectedToApplication) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: denseSpacing),
      child: Column(
        children: [
          Row(
            children: [
              DevToolsButton(
                label: 'PING',
                onPressed: simController.ping,
              ),
              const SizedBox(width: denseSpacing),
              DevToolsButton(
                label: 'TOGGLE THEME',
                onPressed: simController.toggleTheme,
              ),
              const SizedBox(width: denseSpacing),
              DevToolsButton(
                label: 'FORCE RELOAD',
                onPressed: simController.forceReload,
              ),
              // TODO(kenz): add buttons for other simulated events as the extension
              // API expands.
            ],
          ),
          const SizedBox(height: defaultSpacing),
          if (connectedToApplication)
            Row(
              children: [
                DevToolsButton(
                  icon: Icons.bolt,
                  tooltip: 'Hot reload connected app',
                  onPressed: simController.hotReloadConnectedApp,
                ),
                const SizedBox(width: denseSpacing),
                DevToolsButton(
                  icon: Icons.replay,
                  tooltip: 'Hot restart connected app',
                  onPressed: simController.hotRestartConnectedApp,
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _LogsView extends StatelessWidget {
  const _LogsView({required this.simController});

  final SimulatedDevToolsController simController;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Logs:',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            DevToolsButton.iconOnly(
              icon: Icons.clear,
              outlined: false,
              tooltip: 'Clear logs',
              onPressed: () => simController.messageLogs.clear(),
            ),
          ],
        ),
        const PaddedDivider.thin(),
        Expanded(
          child: _LogMessages(
            simController: simController,
          ),
        ),
      ],
    );
  }
}

class _LogMessages extends StatefulWidget {
  const _LogMessages({required this.simController});

  final SimulatedDevToolsController simController;

  @override
  State<_LogMessages> createState() => _LogMessagesState();
}

class _LogMessagesState extends State<_LogMessages> {
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: widget.simController.messageLogs,
      builder: (context, logs, _) {
        if (_scrollController.hasClients && _scrollController.atScrollBottom) {
          unawaited(_scrollController.autoScrollToBottom());
        }
        return Scrollbar(
          controller: _scrollController,
          thumbVisibility: true,
          child: ListView.builder(
            controller: _scrollController,
            itemCount: logs.length,
            itemBuilder: (context, index) {
              final log = logs[index];
              Widget logEntry = LogListItem(log: log);
              if (index != 0) {
                logEntry = OutlineDecoration.onlyTop(child: logEntry);
              }
              return logEntry;
            },
          ),
        );
      },
    );
  }
}

@visibleForTesting
class LogListItem extends StatelessWidget {
  const LogListItem({super.key, required this.log});

  final MessageLogEntry log;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: densePadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '[${log.timestamp.toString()}] from ${log.source.display}',
            style: Theme.of(context).fixedFontStyle,
          ),
          if (log.message != null) Text(log.message!),
          if (log.data != null)
            FormattedJson(
              json: log.data,
            ),
        ],
      ),
    );
  }
}
