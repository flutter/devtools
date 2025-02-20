// Copyright 2020 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'dart:async';

import 'package:devtools_app_shared/ui.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:flutter/material.dart' hide Stack;
import 'package:vm_service/vm_service.dart';

import '../../shared/analytics/constants.dart' as gac;
import '../../shared/globals.dart';
import '../../shared/primitives/utils.dart';
import '../../shared/ui/common_widgets.dart';
import 'debugger_controller.dart';

class DebuggingControls extends StatefulWidget {
  const DebuggingControls({super.key});

  static const minWidthBeforeScaling = 1750.0;

  // The icon size for the material_symbol icons needs to be increased to
  // account for padding included in the icon assets.
  static final materialIconSize = scaleByFontFactor(
    defaultIconSizeBeforeScaling + 3.0,
  );

  @override
  State<DebuggingControls> createState() => _DebuggingControlsState();
}

class _DebuggingControlsState extends State<DebuggingControls>
    with AutoDisposeMixin {
  late DebuggerController controller;

  @override
  void initState() {
    super.initState();
    controller = screenControllers.lookup<DebuggerController>();
    addAutoDisposeListener(
      serviceConnection
          .serviceManager
          .isolateManager
          .mainIsolateState
          ?.isPaused,
    );
    addAutoDisposeListener(controller.resuming);
    addAutoDisposeListener(controller.stackFramesWithLocation);
  }

  @override
  Widget build(BuildContext context) {
    final resuming = controller.resuming.value;
    final hasStackFrames = controller.stackFramesWithLocation.value.isNotEmpty;
    final isSystemIsolate = controller.isSystemIsolate;
    final canStep =
        serviceConnection.serviceManager.isMainIsolatePaused &&
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
          icon: Icons.pause,
          autofocus: true,
          // Disable when paused or selected isolate is a system isolate.
          onPressed:
              (isPaused || isSystemIsolate)
                  ? null
                  : () => unawaited(controller.pause()),
        ),
        ButtonGroupItemData(
          tooltip: 'Resume',
          iconAsset: 'icons/material_symbols/resume.png',
          iconSize: DebuggingControls.materialIconSize,
          // Enable while paused + not resuming and selected isolate is not
          // a system isolate.
          onPressed:
              ((isPaused && !resuming) && !isSystemIsolate)
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
          iconAsset: 'icons/material_symbols/step_over.png',
          iconSize: DebuggingControls.materialIconSize,
          onPressed: canStep ? () => unawaited(controller.stepOver()) : null,
        ),
        ButtonGroupItemData(
          label: 'Step In',
          iconAsset: 'icons/material_symbols/step_into.png',
          iconSize: DebuggingControls.materialIconSize,
          onPressed: canStep ? () => unawaited(controller.stepIn()) : null,
        ),
        ButtonGroupItemData(
          label: 'Step Out',
          iconAsset: 'icons/material_symbols/step_out.png',
          iconSize: DebuggingControls.materialIconSize,
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
          gaSelection:
              visible
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
  const CodeStatisticsControls({super.key, required this.controller});

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
                  icon: Icons.checklist,
                ),
                _CodeStatsControl(
                  tooltip: 'Show profiler hits',
                  icon: Icons.local_fire_department,
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
              onPressed:
                  showCodeCoverage || showProfileInformation
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
  const _CodeStatsControl({required this.icon, required this.tooltip});

  final IconData icon;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return DevToolsTooltip(
      message: tooltip,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: defaultSpacing),
        child: Icon(icon, size: defaultIconSize),
      ),
    );
  }
}

class BreakOnExceptionsControl extends StatelessWidget {
  const BreakOnExceptionsControl({super.key, required this.controller});

  final DebuggerController controller;

  @override
  Widget build(BuildContext context) {
    final isInSmallMode =
        MediaQuery.of(context).size.width <
        DebuggingControls.minWidthBeforeScaling;
    return ValueListenableBuilder<String?>(
      valueListenable: controller.exceptionPauseMode,
      builder: (BuildContext context, modeId, _) {
        final exceptionMode = ExceptionMode.from(modeId);
        return DevToolsTooltip(
          message: exceptionMode.description,
          child: RoundedDropDownButton<ExceptionMode>(
            value: exceptionMode,
            // Cannot set exception pause mode for system isolates.
            onChanged:
                controller.isSystemIsolate
                    ? null
                    : (ExceptionMode? mode) {
                      unawaited(controller.setIsolatePauseMode(mode!.id));
                    },
            isDense: true,
            items: [
              for (final mode in ExceptionMode.modes)
                DropdownMenuItem<ExceptionMode>(
                  value: mode,
                  child: Text(isInSmallMode ? mode.name : mode.description),
                ),
            ],
          ),
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
