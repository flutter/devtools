// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:codicon/codicon.dart';
import 'package:devtools_app_shared/ui.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:flutter/material.dart' hide Stack;
import 'package:vm_service/vm_service.dart';

import '../../shared/analytics/constants.dart' as gac;
import '../../shared/common_widgets.dart';
import '../../shared/globals.dart';
import '../../shared/primitives/utils.dart';
import '../../shared/utils.dart';
import 'debugger_controller.dart';

class DebuggingControls extends StatefulWidget {
  const DebuggingControls({super.key});

  static const minWidthBeforeScaling = 1750.0;

  @override
  State<DebuggingControls> createState() => _DebuggingControlsState();
}

class _DebuggingControlsState extends State<DebuggingControls>
    with
        AutoDisposeMixin,
        ProvidedControllerMixin<DebuggerController, DebuggingControls> {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!initController()) return;
    addAutoDisposeListener(
      serviceConnection
          .serviceManager.isolateManager.mainIsolateState?.isPaused,
    );
    addAutoDisposeListener(controller.resuming);
    addAutoDisposeListener(controller.stackFramesWithLocation);
  }

  @override
  Widget build(BuildContext context) {
    final resuming = controller.resuming.value;
    final hasStackFrames = controller.stackFramesWithLocation.value.isNotEmpty;
    final isSystemIsolate = controller.isSystemIsolate;
    final canStep = serviceConnection.serviceManager.isMainIsolatePaused &&
        !resuming &&
        hasStackFrames &&
        !isSystemIsolate;
    final isVmApp =
        serviceConnection.serviceManager.connectedApp?.isRunningOnDartVM ??
            false;
    return SizedBox(
      height: defaultButtonHeight,
      child: Row(
        children: [
          _pauseAndResumeButtons(
            isPaused: serviceConnection.serviceManager.isMainIsolatePaused,
            resuming: resuming,
          ),
          const SizedBox(width: denseSpacing),
          _stepButtons(canStep: canStep),
          const SizedBox(width: denseSpacing),
          BreakOnExceptionsControl(controller: controller),
          if (isVmApp) ...[
            const SizedBox(width: denseSpacing),
            CodeStatisticsControls(controller: controller),
          ],
          const Expanded(child: SizedBox(width: denseSpacing)),
          _librariesButton(),
        ],
      ),
    );
  }

  Widget _pauseAndResumeButtons({
    required bool isPaused,
    required bool resuming,
  }) {
    final isSystemIsolate = controller.isSystemIsolate;
    return RoundedButtonGroup(
      items: [
        ButtonGroupItemData(
          tooltip: 'Pause',
          icon: Codicons.debugPause,
          autofocus: true,
          // Disable when paused or selected isolate is a system isolate.
          onPressed: (isPaused || isSystemIsolate)
              ? null
              : () => unawaited(controller.pause()),
        ),
        ButtonGroupItemData(
          tooltip: 'Resume',
          icon: Codicons.debugContinue,
          // Enable while paused + not resuming and selected isolate is not
          // a system isolate.
          onPressed: ((isPaused && !resuming) && !isSystemIsolate)
              ? () => unawaited(controller.resume())
              : null,
        ),
      ],
    );
  }

  Widget _stepButtons({required bool canStep}) {
    return RoundedButtonGroup(
      items: [
        ButtonGroupItemData(
          label: 'Step Over',
          icon: Codicons.debugStepOver,
          onPressed: canStep ? () => unawaited(controller.stepOver()) : null,
        ),
        ButtonGroupItemData(
          label: 'Step In',
          icon: Codicons.debugStepInto,
          onPressed: canStep ? () => unawaited(controller.stepIn()) : null,
        ),
        ButtonGroupItemData(
          label: 'Step Out',
          icon: Codicons.debugStepOut,
          onPressed: canStep ? () => unawaited(controller.stepOut()) : null,
        ),
      ],
      minScreenWidthForTextBeforeScaling:
          DebuggingControls.minWidthBeforeScaling,
    );
  }

  Widget _librariesButton() {
    return ValueListenableBuilder<bool>(
      valueListenable: controller.codeViewController.fileExplorerVisible,
      builder: (context, visible, _) {
        return GaDevToolsButton(
          icon: Icons.folder_outlined,
          label: 'File Explorer',
          onPressed: controller.codeViewController.toggleLibrariesVisible,
          gaScreen: gac.debugger,
          gaSelection: visible
              ? gac.DebuggerEvents.hideFileExplorer.name
              : gac.DebuggerEvents.showFileExplorer.name,
          minScreenWidthForTextBeforeScaling:
              DebuggingControls.minWidthBeforeScaling,
        );
      },
    );
  }
}

class CodeStatisticsControls extends StatelessWidget {
  const CodeStatisticsControls({
    super.key,
    required this.controller,
  });

  final DebuggerController controller;

  @override
  Widget build(BuildContext context) {
    return MultiValueListenableBuilder(
      listenables: [
        controller.codeViewController.showCodeCoverage,
        controller.codeViewController.showProfileInformation,
      ],
      builder: (context, values, _) {
        final showCodeCoverage = values.first as bool;
        final showProfileInformation = values.second as bool;
        return Row(
          children: [
            // TODO(kenz): clean up this button group when records are
            // available.
            DevToolsToggleButtonGroup(
              selectedStates: [showCodeCoverage, showProfileInformation],
              children: const [
                _CodeStatsControl(
                  tooltip: 'Show code coverage',
                  icon: Codicons.checklist,
                ),
                _CodeStatsControl(
                  tooltip: 'Show profiler hits',
                  icon: Codicons.flame,
                ),
              ],
              onPressed: (index) {
                if (index == 0) {
                  controller.codeViewController.toggleShowCodeCoverage();
                } else if (index == 1) {
                  controller.codeViewController.toggleShowProfileInformation();
                }
              },
            ),
            const SizedBox(width: denseSpacing),
            RefreshButton(
              iconOnly: true,
              tooltip: 'Refresh statistics',
              gaScreen: gac.debugger,
              gaSelection: gac.DebuggerEvents.refreshStatistics.name,
              onPressed: showCodeCoverage || showProfileInformation
                  ? () => unawaited(
                        controller.codeViewController.refreshCodeStatistics(),
                      )
                  : null,
            ),
          ],
        );
      },
    );
  }
}

class _CodeStatsControl extends StatelessWidget {
  const _CodeStatsControl({
    required this.icon,
    required this.tooltip,
  });

  final IconData icon;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return DevToolsTooltip(
      message: tooltip,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: defaultSpacing),
        child: Icon(
          icon,
          size: defaultIconSize,
        ),
      ),
    );
  }
}

class BreakOnExceptionsControl extends StatelessWidget {
  const BreakOnExceptionsControl({
    super.key,
    required this.controller,
  });

  final DebuggerController controller;

  @override
  Widget build(BuildContext context) {
    final isInSmallMode = MediaQuery.of(context).size.width <
        DebuggingControls.minWidthBeforeScaling;
    return ValueListenableBuilder<String?>(
      valueListenable: controller.exceptionPauseMode,
      builder: (BuildContext context, modeId, _) {
        return RoundedDropDownButton<ExceptionMode>(
          value: ExceptionMode.from(modeId),
          // Cannot set exception pause mode for system isolates.
          onChanged: controller.isSystemIsolate
              ? null
              : (ExceptionMode? mode) {
                  unawaited(controller.setIsolatePauseMode(mode!.id));
                },
          isDense: true,
          items: [
            for (final mode in ExceptionMode.modes)
              DropdownMenuItem<ExceptionMode>(
                value: mode,
                child: Text(
                  isInSmallMode ? mode.name : mode.description,
                ),
              ),
          ],
        );
      },
    );
  }
}

class ExceptionMode {
  ExceptionMode(this.id, this.name, this.description);

  static final modes = [
    ExceptionMode(
      ExceptionPauseMode.kNone,
      'Ignore exceptions',
      "Don't stop on exceptions",
    ),
    ExceptionMode(
      ExceptionPauseMode.kUnhandled,
      'Uncaught exceptions',
      'Stop on uncaught exceptions',
    ),
    ExceptionMode(
      ExceptionPauseMode.kAll,
      'All exceptions',
      'Stop on all exceptions',
    ),
  ];

  static ExceptionMode from(String? id) {
    return modes.singleWhere(
      (mode) => mode.id == id,
      orElse: () => modes.first,
    );
  }

  final String id;
  final String name;
  final String description;
}
