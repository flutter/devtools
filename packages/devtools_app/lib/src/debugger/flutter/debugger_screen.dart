// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart' hide Stack;
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
import '../../ui/flutter/label.dart';
import 'breakpoints.dart';
import 'codeview.dart';
import 'common.dart';
import 'console.dart';
import 'debugger_controller.dart';
import 'scripts.dart';

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

  DebuggerController controller;
  ScriptRef loadingScript;
  Script script;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final newController = Provider.of<DebuggerController>(context);
    if (newController == controller) return;
    controller = newController;

    // TODO(all): We need to be more precise about the changes we listen to.
    // These coarse listeners are causing us to rebuild much more of the UI than
    // we need to.
    addAutoDisposeListener(controller.currentScript, () {
      setState(() {
        script = controller.currentScript.value;
      });
    });
    addAutoDisposeListener(controller.currentStack);
    addAutoDisposeListener(controller.sortedScripts);
    addAutoDisposeListener(controller.breakpoints);

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
    return {
      for (var b in controller.breakpoints.value
          .where((b) => b != null && b.location.script.id == script.id))
        controller.lineNumber(script, b.location): b,
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
    final loading = loadingScript != null && script == null;

    return Split(
      axis: Axis.horizontal,
      initialFractions: const [0.25, 0.75],
      children: [
        OutlinedBorder(child: debuggerPanes()),
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DebuggingControls(controller: controller),
            const SizedBox(height: denseRowSpacing),
            Expanded(
              child: Split(
                axis: Axis.vertical,
                initialFractions: const [0.75, 0.25],
                children: [
                  if (loading) const Center(child: CircularProgressIndicator()),
                  if (!loading)
                    OutlinedBorder(
                      child: Column(
                        children: [
                          debuggerSectionTitle(theme,
                              text: script == null ? ' ' : '${script.uri}'),
                          Expanded(
                            child: CodeView(
                              script: script,
                              stack: controller.currentStack.value,
                              controller: controller,
                              lineNumberToBreakpoint: _breakpointsForLines(),
                              onSelected: toggleBreakpoint,
                            ),
                          ),
                        ],
                      ),
                    ),
                  Console(),
                ],
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
          initialFractions: const [0.20, 0.20, 0.20, 0.40],
          minSizes: const [0.0, 0.0, 0.0, 0.0],
          headers: [
            _debuggerPaneHeader(callStackTitle, needsTopBorder: false),
            _debuggerPaneHeader(variablesTitle),
            _debuggerPaneHeader(breakpointsTitle),
            _debuggerPaneHeader(
              librariesTitle,
              rightChild: ScriptCountBadge(
                scripts: controller.sortedScripts.value,
              ),
            ),
          ],
          children: [
            const Center(child: Text('TODO: call stack')),
            const Center(child: Text('TODO: variables')),
            BreakpointPicker(controller: controller),
            ScriptPicker(
              scripts: controller.sortedScripts.value,
              selected: loadingScript,
              onSelected: _onScriptSelected,
            ),
          ],
        );
      },
    );
  }

  FlexSplitColumnHeader _debuggerPaneHeader(
    String title, {
    bool needsTopBorder = true,
    Widget rightChild,
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
          color: titleSolidBackgroundColor,
        ),
        padding: const EdgeInsets.only(left: defaultSpacing, right: 4.0),
        alignment: Alignment.centerLeft,
        height: DebuggerScreen.debuggerPaneHeaderHeight,
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: Theme.of(context).textTheme.subtitle2,
              ),
            ),
            if (rightChild != null) rightChild,
          ],
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
    return ValueListenableBuilder(
      valueListenable: controller.isPaused,
      builder: (context, isPaused, child) {
        return SizedBox(
          height: DebuggerScreen.debuggerPaneHeaderHeight,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              OutlinedBorder(
                child: Row(
                  children: [
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
                  ],
                ),
              ),
              const SizedBox(width: denseSpacing),
              OutlinedBorder(
                child: Row(
                  children: [
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
              ),
            ],
          ),
        );
      },
    );
  }
}
