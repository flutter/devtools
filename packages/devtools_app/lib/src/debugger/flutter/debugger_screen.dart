// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart' hide Stack;
import 'package:vm_service/vm_service.dart';

import '../../flutter/auto_dispose_mixin.dart';
import '../../flutter/common_widgets.dart';
import '../../flutter/controllers.dart';
import '../../flutter/flex_split_column.dart';
import '../../flutter/octicons.dart';
import '../../flutter/screen.dart';
import '../../flutter/split.dart';
import '../../flutter/theme.dart';
import '../../globals.dart';
import '../../ui/flutter/label.dart';
import 'breakpoints.dart';
import 'codeview.dart';
import 'debugger_controller.dart';
import 'scripts.dart';

class DebuggerScreen extends Screen {
  const DebuggerScreen()
      : super(
          DevToolsScreenType.debugger,
          title: 'Debugger',
          icon: Octicons.bug,
        );

  @override
  String get docPageId => 'debugger';

  @override
  bool get showIsolateSelector => true;

  @override
  Widget build(BuildContext context) {
    return !serviceManager.connectedApp.isProfileBuildNow
        ? const DebuggerScreenBody()
        : const DisabledForProfileBuildMessage();
  }
}

class DebuggerScreenBody extends StatefulWidget {
  const DebuggerScreenBody();

  @override
  DebuggerScreenBodyState createState() => DebuggerScreenBodyState();
}

class DebuggerScreenBodyState extends State<DebuggerScreenBody>
    with AutoDisposeMixin {
  static const callStackTitle = 'Call Stack';
  static const variablesTitle = 'Variables';
  static const breakpointsTitle = 'Breakpoints';
  static const librariesTitle = 'Libraries';

  static const debuggerPaneHeaderHeight = 36.0;

  DebuggerController controller;
  ScriptRef loadingScript;
  Script script;
  ScriptList scriptList;
  Stack stack;
  List<Breakpoint> breakpoints;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final newController = Controllers.of(context).debugger;
    if (newController == controller) return;
    controller = newController;

    addAutoDisposeListener(controller.currentScript, () {
      setState(() {
        script = controller.currentScript.value;
      });
    });
    addAutoDisposeListener(controller.currentStack, () {
      setState(() {
        stack = controller.currentStack.value;
      });
    });
    addAutoDisposeListener(controller.scriptList, () {
      setState(() {
        scriptList = controller.scriptList.value;
      });
    });
    breakpoints = controller.breakpoints.value;
    addAutoDisposeListener(controller.breakpoints, () {
      setState(() {
        breakpoints = controller.breakpoints.value;
      });
    });

    controller.getScripts();
  }

  Future<void> _onScriptSelected(ScriptRef ref) async {
    if (ref == null) return;
    setState(() {
      loadingScript = ref;
      script = null;
    });
    await controller.selectScript(ref);
  }

  Map<int, Breakpoint> _breakpointsForLines() {
    if (script == null) return {};
    final bps = breakpoints
        .where((b) => b != null && b.location.script.id == script.id);
    return {
      for (var b in bps) controller.lineNumber(script, b.location): b,
    };
  }

  Future<void> toggleBreakpoint(Script script, int line) async {
    final breakpoints = _breakpointsForLines();
    if (breakpoints.containsKey(line)) {
      await controller.removeBreakpoint(breakpoints[line]);
    } else {
      await controller.addBreakpoint(script.id, line);
    }
    // The controller's breakpoints value listener will update us at this point
    // to rebuild.
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Split(
      axis: Axis.horizontal,
      initialFractions: const [0.25, 0.75],
      // TODO(https://github.com/flutter/devtools/issues/1648): Debug panes.
      children: [
        OutlinedBorder(child: debuggerPanes()),
        // TODO(https://github.com/flutter/devtools/issues/1648): Debug controls.
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DebuggingControls(controller: controller),
            const SizedBox(height: denseRowSpacing),
            Expanded(
              child: loadingScript != null && script == null
                  ? const Center(child: CircularProgressIndicator())
                  : OutlinedBorder(
                      child: Column(
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              border: Border(
                                bottom: BorderSide(color: theme.focusColor),
                              ),
                              color: titleSolidBackgroundColor,
                            ),
                            padding:
                                const EdgeInsets.only(left: defaultSpacing),
                            alignment: Alignment.centerLeft,
                            height: debuggerPaneHeaderHeight,
                            child: Text(
                              script == null ? ' ' : '${script.uri}',
                              style: theme.textTheme.subtitle2,
                            ),
                          ),
                          Expanded(
                            child: CodeView(
                              script: script,
                              stack: stack,
                              controller: controller,
                              lineNumberToBreakpoint: _breakpointsForLines(),
                              onSelected: toggleBreakpoint,
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ],
    );
  }

  Widget debuggerPanes() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return FlexSplitColumn(
          totalHeight: constraints.maxHeight,
          initialFractions: const [0.25, 0.25, 0.25, 0.25],
          minSizes: const [0.0, 0.0, 0.0, 0.0],
          headers: [
            _debuggerPaneHeader(callStackTitle),
            _debuggerPaneHeader(variablesTitle),
            _debuggerPaneHeader(breakpointsTitle),
            _debuggerPaneHeader(librariesTitle),
          ],
          children: [
            const Center(child: Text('TODO: call stack')),
            const Center(child: Text('TODO: variables')),
            BreakpointPicker(controller: controller),
            ScriptPicker(
              scripts: scriptList,
              onSelected: _onScriptSelected,
              selected: loadingScript,
            ),
          ],
        );
      },
    );
  }

  FlexSplitColumnHeader _debuggerPaneHeader(String title) {
    final theme = Theme.of(context);

    return FlexSplitColumnHeader(
      height: debuggerPaneHeaderHeight,
      child: Container(
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: theme.focusColor),
          ),
          color: titleSolidBackgroundColor,
        ),
        padding: const EdgeInsets.only(left: defaultSpacing),
        alignment: Alignment.centerLeft,
        height: debuggerPaneHeaderHeight,
        child: Text(
          title,
          style: Theme.of(context).textTheme.subtitle2,
        ),
      ),
    );
  }
}

class DebuggingControls extends StatelessWidget {
  const DebuggingControls({Key key, @required this.controller})
      : super(key: key);

  final DebuggerController controller;

  @override
  Widget build(BuildContext context) {
    // TODO(devoncarew): Change to using two sets of ToggleButtons.

    return ValueListenableBuilder(
      valueListenable: controller.isPaused,
      builder: (context, isPaused, child) {
        return SizedBox(
          height: DebuggerScreenBodyState.debuggerPaneHeaderHeight,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              // todo: create a group
              MaterialButton(
                onPressed: isPaused ? null : controller.pause,
                child: const MaterialIconLabel(
                  Icons.pause,
                  'Pause',
                ),
              ),
              MaterialButton(
                onPressed: isPaused ? controller.resume : null,
                child: const MaterialIconLabel(
                  Icons.play_arrow,
                  'Resume',
                ),
              ),
              const SizedBox(width: defaultSpacing),
              // todo: create a group
              MaterialButton(
                onPressed: isPaused ? controller.stepIn : null,
                child: const MaterialIconLabel(
                  Icons.keyboard_arrow_down,
                  'Step In',
                ),
              ),
              MaterialButton(
                onPressed: isPaused ? controller.stepOver : null,
                child: const MaterialIconLabel(
                  Icons.keyboard_arrow_right,
                  'Step Over',
                ),
              ),
              MaterialButton(
                onPressed: isPaused ? controller.stepOut : null,
                child: const MaterialIconLabel(
                  Icons.keyboard_arrow_up,
                  'Step Out',
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
