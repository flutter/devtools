// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart' hide Stack;
import 'package:vm_service/vm_service.dart';

import '../common_widgets.dart';
import '../theme.dart';
import '../ui/label.dart';
import 'debugger_controller.dart';
import 'scripts.dart';

class DebuggingControls extends StatelessWidget {
  const DebuggingControls({Key key, @required this.controller})
      : super(key: key);

  final DebuggerController controller;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: controller.isPaused,
      builder: (context, isPaused, _) {
        return ValueListenableBuilder(
          valueListenable: controller.resuming,
          builder: (context, resuming, Widget _) {
            final canStep = isPaused && !resuming && controller.hasFrames.value;

            return SizedBox(
              height: Theme.of(context).buttonTheme.height,
              child: Row(
                children: [
                  RoundedOutlinedBorder(
                    child: Row(
                      children: [
                        DebuggerButton(
                          title: 'Pause',
                          icon: Icons.pause,
                          autofocus: true,
                          onPressed: isPaused ? null : controller.pause,
                        ),
                        _LeftBorder(
                          child: DebuggerButton(
                            title: 'Resume',
                            icon: Icons.play_arrow,
                            onPressed: (isPaused && !resuming)
                                ? controller.resume
                                : null,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: denseSpacing),
                  RoundedOutlinedBorder(
                    child: Row(
                      children: [
                        DebuggerButton(
                          title: 'Step In',
                          icon: Icons.keyboard_arrow_down,
                          onPressed: canStep ? controller.stepIn : null,
                        ),
                        _LeftBorder(
                          child: DebuggerButton(
                            title: 'Step Over',
                            icon: Icons.keyboard_arrow_right,
                            onPressed: canStep ? controller.stepOver : null,
                          ),
                        ),
                        _LeftBorder(
                          child: DebuggerButton(
                            title: 'Step Out',
                            icon: Icons.keyboard_arrow_up,
                            onPressed: canStep ? controller.stepOut : null,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: denseSpacing),
                  RoundedOutlinedBorder(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.only(
                          left: defaultSpacing,
                          right: borderPadding,
                        ),
                        child: BreakOnExceptionsControl(controller: controller),
                      ),
                    ),
                  ),
                  const Expanded(child: SizedBox(width: denseSpacing)),
                  ValueListenableBuilder(
                    valueListenable: controller.librariesVisible,
                    builder: (context, visible, _) {
                      return RoundedOutlinedBorder(
                        child: Container(
                          color:
                              visible ? Theme.of(context).highlightColor : null,
                          child: DebuggerButton(
                            title: 'Libraries',
                            icon: libraryIcon,
                            onPressed: controller.toggleLibrariesVisible,
                          ),
                        ),
                      );
                    },
                  )
                ],
              ),
            );
          },
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
        return DropdownButtonHideUnderline(
          child: DropdownButton<ExceptionMode>(
            value: ExceptionMode.from(modeId),
            onChanged: (ExceptionMode mode) {
              controller.setExceptionPauseMode(mode.id);
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
    return ActionButton(
      tooltip: title,
      child: OutlineButton(
        autofocus: autofocus,
        borderSide: BorderSide.none,
        shape: const ContinuousRectangleBorder(),
        onPressed: onPressed,
        child: MaterialIconLabel(
          icon,
          title,
          includeTextWidth: mediumDeviceWidth,
        ),
      ),
    );
  }
}

class _LeftBorder extends StatelessWidget {
  const _LeftBorder({this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final leftBorder =
        Border(left: BorderSide(color: Theme.of(context).focusColor));

    return Container(
      decoration: BoxDecoration(border: leftBorder),
      child: child,
    );
  }
}
