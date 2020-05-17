// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:flutter/material.dart' hide Stack;
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:vm_service/vm_service.dart';

import '../../flutter/auto_dispose_mixin.dart';
import '../../flutter/common_widgets.dart';
import '../../flutter/flex_split_column.dart';
import '../../flutter/octicons.dart';
import '../../flutter/screen.dart';
import '../../flutter/split.dart';
import '../../flutter/theme.dart';
import '../../globals.dart';
import 'breakpoints.dart';
import 'call_stack.dart';
import 'codeview.dart';
import 'console.dart';
import 'controls.dart';
import 'debugger_controller.dart';
import 'debugger_model.dart';
import 'scripts.dart';
import 'variables.dart';

// This is currently a dev-time flag as the overall call depth may not be that
// interesting to users.
const bool showCallStackCount = true;

class DebuggerScreen extends Screen {
  const DebuggerScreen()
      : super('debugger', title: 'Debugger', icon: Octicons.bug);

  static const debuggerPaneHeaderHeight = 36.0;

  @override
  String get docPageId => screenId;

  @override
  bool get showIsolateSelector => true;

  @override
  Widget build(BuildContext context) {
    return !serviceManager.connectedApp.isProfileBuildNow
        ? const DebuggerScreenBody()
        : const DisabledForProfileBuildMessage();
  }

  @override
  Widget buildStatus(BuildContext context, TextTheme textTheme) {
    final controller = Provider.of<DebuggerController>(context);
    return DebuggerStatus(controller: controller);
  }
}

class DebuggerScreenBody extends StatefulWidget {
  const DebuggerScreenBody();

  static final codeViewKey = GlobalKey(debugLabel: 'codeViewKey');
  static final scriptViewKey = GlobalKey(debugLabel: 'scriptViewKey');

  @override
  DebuggerScreenBodyState createState() => DebuggerScreenBodyState();
}

class DebuggerScreenBodyState extends State<DebuggerScreenBody>
    with AutoDisposeMixin {
  static const callStackTitle = 'Call Stack';
  static const variablesTitle = 'Variables';
  static const breakpointsTitle = 'Breakpoints';

  DebuggerController controller;
  FocusNode _libraryFilterFocusNode;

  @override
  void initState() {
    super.initState();
    _libraryFilterFocusNode = FocusNode();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final newController = Provider.of<DebuggerController>(context);
    if (newController == controller) return;
    controller = newController;
  }

  @override
  void dispose() {
    _libraryFilterFocusNode.dispose();
    super.dispose();
  }

  void _onLocationSelected(ScriptLocation location) {
    if (location != null) {
      controller.showScriptLocation(location);
    }
  }

  Future<void> _toggleBreakpoint(ScriptRef script, int line) async {
    final bp = controller.breakpointsWithLocation.value.firstWhere((bp) {
      return bp.scriptRef == script && bp.line == line;
    }, orElse: () => null);

    if (bp != null) {
      await controller.removeBreakpoint(bp.breakpoint);
    } else {
      try {
        await controller.addBreakpoint(script.id, line);
      } catch (_) {
        // ignore errors setting breakpoints
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final codeView = ValueListenableBuilder(
      valueListenable: controller.currentScriptRef,
      builder: (context, scriptRef, _) {
        return CodeView(
          key: DebuggerScreenBody.codeViewKey,
          controller: controller,
          scriptRef: scriptRef,
          onSelected: _toggleBreakpoint,
        );
      },
    );

    final codeArea = ValueListenableBuilder(
      valueListenable: controller.librariesVisible,
      builder: (context, visible, _) {
        if (visible) {
          // Focus the filter textfield when the ScriptPicker opens
          _libraryFilterFocusNode.requestFocus();

          // TODO(devoncarew): Animate this opening and closing.
          return Split(
            axis: Axis.horizontal,
            initialFractions: const [0.70, 0.30],
            children: [
              codeView,
              AnimatedBuilder(
                animation: Listenable.merge([
                  controller.sortedScripts,
                  controller.sortedClasses,
                ]),
                builder: (context, _) {
                  return ScriptPicker(
                    key: DebuggerScreenBody.scriptViewKey,
                    controller: controller,
                    scripts: controller.sortedScripts.value,
                    classes: controller.sortedClasses.value,
                    onSelected: _onLocationSelected,
                    libraryFilterFocusNode: _libraryFilterFocusNode,
                  );
                },
              ),
            ],
          );
        } else {
          return codeView;
        }
      },
    );

    return Shortcuts(
      shortcuts: <LogicalKeySet, Intent>{
        LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyP):
            FilterLibraryIntent(_libraryFilterFocusNode, controller),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          FilterLibraryIntent: FilterLibraryAction(),
        },
        child: Split(
          axis: Axis.horizontal,
          initialFractions: const [0.25, 0.75],
          children: [
            OutlineDecoration(child: debuggerPanes()),
            Column(
              children: [
                DebuggingControls(controller: controller),
                const SizedBox(height: denseRowSpacing),
                Expanded(
                  child: Split(
                    axis: Axis.vertical,
                    initialFractions: const [0.74, 0.26],
                    children: [
                      codeArea,
                      DebuggerConsole(controller: controller),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget debuggerPanes() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return FlexSplitColumn(
          totalHeight: constraints.maxHeight,
          initialFractions: const [0.38, 0.38, 0.24],
          minSizes: const [0.0, 0.0, 0.0],
          headers: [
            debuggerPaneHeader(
              context,
              callStackTitle,
              needsTopBorder: false,
              rightChild: showCallStackCount ? _callStackRightChild() : null,
            ),
            debuggerPaneHeader(context, variablesTitle),
            debuggerPaneHeader(
              context,
              breakpointsTitle,
              rightChild: _breakpointsRightChild(),
              rightPadding: 0.0,
            ),
          ],
          children: const [
            CallStack(),
            Variables(),
            BreakpointPicker(),
          ],
        );
      },
    );
  }

  Widget _callStackRightChild() {
    return ValueListenableBuilder(
      valueListenable: controller.stackFramesWithLocation,
      builder: (context, stackFrames, _) {
        return CallStackCountBadge(stackFrames: stackFrames);
      },
    );
  }

  Widget _breakpointsRightChild() {
    return ValueListenableBuilder(
      valueListenable: controller.breakpointsWithLocation,
      builder: (context, breakpoints, _) {
        return Row(children: [
          BreakpointsCountBadge(breakpoints: breakpoints),
          ActionButton(
            child: FlatButton(
              padding: EdgeInsets.zero,
              child: const Icon(Icons.delete, size: 24.0),
              onPressed:
                  breakpoints.isNotEmpty ? controller.clearBreakpoints : null,
            ),
            tooltip: 'Remove all breakpoints',
          ),
        ]);
      },
    );
  }
}

class FilterLibraryIntent extends Intent {
  const FilterLibraryIntent(
    this.focusNode,
    this.debuggerController,
  )   : assert(debuggerController != null),
        assert(focusNode != null);

  final FocusNode focusNode;
  final DebuggerController debuggerController;
}

class FilterLibraryAction extends Action<FilterLibraryIntent> {
  @override
  void invoke(FilterLibraryIntent intent) {
    intent.debuggerController.openLibrariesView();
    intent.focusNode.requestFocus();
  }
}

class DebuggerStatus extends StatefulWidget {
  const DebuggerStatus({
    Key key,
    @required this.controller,
  }) : super(key: key);

  final DebuggerController controller;

  @override
  _DebuggerStatusState createState() => _DebuggerStatusState();
}

class _DebuggerStatusState extends State<DebuggerStatus> with AutoDisposeMixin {
  String _status;

  @override
  void initState() {
    super.initState();

    addAutoDisposeListener(widget.controller.isPaused, _updateStatus);

    _status = '';
    _updateStatus();
  }

  @override
  void didUpdateWidget(DebuggerStatus oldWidget) {
    super.didUpdateWidget(oldWidget);

    // todo: should we check that widget.controller != oldWidget.controller?
    addAutoDisposeListener(widget.controller.isPaused, _updateStatus);
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      _status,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }

  void _updateStatus() async {
    final status = await _computeStatus();
    if (status != _status) {
      setState(() {
        _status = status;
      });
    }
  }

  Future<String> _computeStatus() async {
    final paused = widget.controller.isPaused.value;

    if (!paused) {
      return 'running';
    }

    final event = widget.controller.lastEvent;
    final frame = event.topFrame;
    final reason =
        event.kind == EventKind.kPauseException ? ' on exception' : '';

    if (frame == null) {
      return 'paused$reason';
    }

    final fileName = ' at ' + frame.location.script.uri.split('/').last;
    final script = await widget.controller.getScript(frame.location.script);
    final pos =
        widget.controller.calculatePosition(script, frame.location.tokenPos);

    return 'paused$reason$fileName $pos';
  }
}

FlexSplitColumnHeader debuggerPaneHeader(
  BuildContext context,
  String title, {
  bool needsTopBorder = true,
  Widget rightChild,
  double rightPadding = 4.0,
}) {
  final theme = Theme.of(context);

  return FlexSplitColumnHeader(
    height: DebuggerScreen.debuggerPaneHeaderHeight,
    child: Container(
      decoration: BoxDecoration(
        border: Border(
          top: needsTopBorder
              ? BorderSide(color: theme.focusColor)
              : BorderSide.none,
          bottom: BorderSide(color: theme.focusColor),
        ),
        color: titleSolidBackgroundColor(theme),
      ),
      padding: EdgeInsets.only(left: defaultSpacing, right: rightPadding),
      alignment: Alignment.centerLeft,
      height: DebuggerScreen.debuggerPaneHeaderHeight,
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.subtitle2,
            ),
          ),
          if (rightChild != null) rightChild,
        ],
      ),
    ),
  );
}
