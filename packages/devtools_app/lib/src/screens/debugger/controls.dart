// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// @dart=2.9

import 'package:codicon/codicon.dart';
import 'package:flutter/material.dart' hide Stack;
import 'package:provider/provider.dart';
import 'package:vm_service/vm_service.dart';

import '../../primitives/auto_dispose_mixin.dart';
import '../../shared/common_widgets.dart';
import '../../shared/theme.dart';
import '../../ui/label.dart';
import 'debugger_controller.dart';

class DebuggingControls extends StatefulWidget {
  const DebuggingControls({Key key}) : super(key: key);

  @override
  _DebuggingControlsState createState() => _DebuggingControlsState();
}

class _DebuggingControlsState extends State<DebuggingControls>
    with AutoDisposeMixin {
  DebuggerController controller;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    controller = Provider.of<DebuggerController>(context);
    addAutoDisposeListener(controller.isPaused);
    addAutoDisposeListener(controller.resuming);
    addAutoDisposeListener(controller.stackFramesWithLocation);
  }

  @override
  Widget build(BuildContext context) {
    final isPaused = controller.isPaused.value;
    final resuming = controller.resuming.value;
    final hasStackFrames = controller.stackFramesWithLocation.value.isNotEmpty;
    final isSystemIsolate = controller.isSystemIsolate;
    final canStep = isPaused && !resuming && hasStackFrames && !isSystemIsolate;
    return SizedBox(
      height: defaultButtonHeight,
      child: Row(
        children: [
          _pauseAndResumeButtons(isPaused: isPaused, resuming: resuming),
          const SizedBox(width: denseSpacing),
          _stepButtons(canStep: canStep),
          const SizedBox(width: denseSpacing),
          BreakOnExceptionsControl(controller: controller),
          const Expanded(child: SizedBox(width: denseSpacing)),
          _librariesButton(),
        ],
      ),
    );
  }

  Widget _pauseAndResumeButtons({
    @required bool isPaused,
    @required bool resuming,
  }) {
    final isSystemIsolate = controller.isSystemIsolate;
    return RoundedOutlinedBorder(
      child: Row(
        children: [
          DebuggerButton(
            title: 'Pause',
            icon: Codicons.debugPause,
            autofocus: true,
            // Disable when paused or selected isolate is a system isolate.
            onPressed: (isPaused || isSystemIsolate) ? null : controller.pause,
          ),
          LeftBorder(
            child: DebuggerButton(
              title: 'Resume',
              icon: Codicons.debugContinue,
              // Enable while paused + not resuming and selected isolate is not
              // a system isolate.
              onPressed: ((isPaused && !resuming) && !isSystemIsolate)
                  ? controller.resume
                  : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _stepButtons({@required bool canStep}) {
    return RoundedOutlinedBorder(
      child: Row(
        children: [
          DebuggerButton(
            title: 'Step Over',
            icon: Codicons.debugStepOver,
            onPressed: canStep ? controller.stepOver : null,
          ),
          LeftBorder(
            child: DebuggerButton(
              title: 'Step In',
              icon: Codicons.debugStepInto,
              onPressed: canStep ? controller.stepIn : null,
            ),
          ),
          LeftBorder(
            child: DebuggerButton(
              title: 'Step Out',
              icon: Codicons.debugStepOut,
              onPressed: canStep ? controller.stepOut : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _librariesButton() {
    return ValueListenableBuilder(
      valueListenable: controller.fileExplorerVisible,
      builder: (context, visible, _) {
        return RoundedOutlinedBorder(
          child: Container(
            color: visible ? Theme.of(context).highlightColor : null,
            child: DebuggerButton(
              title: 'File Explorer',
              icon: Icons.folder,
              onPressed: controller.toggleLibrariesVisible,
            ),
          ),
        );
      },
    );
  }
}

class BreakOnExceptionsControl extends StatelessWidget {
  const BreakOnExceptionsControl({
    Key key,
    @required this.controller,
  }) : super(key: key);

  final DebuggerController controller;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: controller.exceptionPauseMode,
      builder: (BuildContext context, String modeId, _) {
        return RoundedDropDownButton<ExceptionMode>(
          value: ExceptionMode.from(modeId),
          // Cannot set exception pause mode for system isolates.
          onChanged: controller.isSystemIsolate
              ? null
              : (ExceptionMode mode) {
                  controller.setIsolatePauseMode(mode.id);
                },
          isDense: true,
          items: [
            for (var mode in ExceptionMode.modes)
              DropdownMenuItem<ExceptionMode>(
                value: mode,
                child: Text(mode.description),
              )
          ],
          selectedItemBuilder: (BuildContext context) {
            return [
              for (var mode in ExceptionMode.modes)
                DropdownMenuItem<ExceptionMode>(
                  value: mode,
                  child: Text(mode.name),
                )
            ];
          },
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
      'Ignore',
      "Don't stop on exceptions",
    ),
    ExceptionMode(
      ExceptionPauseMode.kUnhandled,
      'Uncaught',
      'Stop on uncaught exceptions',
    ),
    ExceptionMode(
      ExceptionPauseMode.kAll,
      'All',
      'Stop on all exceptions',
    ),
  ];

  static ExceptionMode from(String id) {
    return modes.singleWhere((mode) => mode.id == id,
        orElse: () => modes.first);
  }

  final String id;
  final String name;
  final String description;
}

@visibleForTesting
class DebuggerButton extends StatelessWidget {
  const DebuggerButton({
    @required this.title,
    @required this.icon,
    @required this.onPressed,
    this.autofocus = false,
  });

  final String title;
  final IconData icon;
  final VoidCallback onPressed;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    return DevToolsTooltip(
      message: title,
      child: OutlinedButton(
        autofocus: autofocus,
        style: OutlinedButton.styleFrom(
          side: BorderSide.none,
          shape: const ContinuousRectangleBorder(),
        ),
        onPressed: onPressed,
        child: MaterialIconLabel(
          label: title,
          iconData: icon,
          minScreenWidthForTextBeforeScaling: mediumDeviceWidth,
        ),
      ),
    );
  }
}
