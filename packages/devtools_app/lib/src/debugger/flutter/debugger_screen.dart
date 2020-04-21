// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

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
import 'breakpoints.dart';
import 'codeview.dart';
import 'common.dart';
import 'console.dart';
import 'controls.dart';
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

  @override
  Widget buildStatus(BuildContext context, TextTheme textTheme) {
    final controller = Provider.of<DebuggerController>(context);
    return DebuggerStatus(controller: controller);
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

  DebuggerController controller;
  Script script;
  BreakpointAndSourcePosition selectedBreakpoint;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final newController = Provider.of<DebuggerController>(context);
    if (newController == controller) return;
    controller = newController;

    // TODO(devoncarew): We need to be more precise about the changes we listen
    // to. These coarse listeners are causing us to rebuild much more of the UI
    // than we need to.
    script = controller.currentScript.value;
    addAutoDisposeListener(controller.currentScript, () {
      setState(() {
        script = controller.currentScript.value;
      });
    });

    addAutoDisposeListener(controller.currentStack);
    addAutoDisposeListener(controller.sortedScripts);
    addAutoDisposeListener(controller.breakpoints);
  }

  Future<void> _onScriptSelected(ScriptRef ref) async {
    if (ref == null) return;

    await controller.selectScript(ref);
  }

  Future<void> _onBreakpointSelected(BreakpointAndSourcePosition bp) async {
    if (bp != selectedBreakpoint) {
      setState(() {
        selectedBreakpoint = bp;
      });
    }

    // TODO(devoncarew): Change the line selection in the code view as well.
        await controller.selectScript(bp.script);
  }

  Map<int, Breakpoint> _breakpointsForLines() {
    if (script == null) return {};
    return {
      for (var b in controller.breakpoints.value
          .where((b) => b != null && b.location.script?.id == script.id))
        controller.lineNumber(script, b.location): b,
    };
  }

  Future<void> toggleBreakpoint(Script script, int line) async {
    final breakpoints = _breakpointsForLines();
    if (breakpoints.containsKey(line)) {
      await controller.removeBreakpoint(breakpoints[line]);
    } else {
      try {
        await controller.addBreakpoint(script.id, line);
      } catch (_) {
        // ignore errors setting breakpoints
      }
    }
    // The controller's breakpoints value listener will update us at this point
    // to rebuild.
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final codeWidget = OutlinedBorder(
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
    );

    final codeArea = ValueListenableBuilder(
      valueListenable: controller.librariesVisible,
      builder: (context, value, _) {
        if (value) {
          // TODO(devoncarew): Animate this opening and closing.
          return Split(
            axis: Axis.horizontal,
            initialFractions: const [0.70, 0.30],
            children: [
              codeWidget,
              ScriptPicker(
                controller: controller,
                scripts: controller.sortedScripts.value,
                selected: script,
                onSelected: _onScriptSelected,
              ),
            ],
          );
        } else {
          return codeWidget;
        }
      },
    );

    return Split(
      axis: Axis.horizontal,
      initialFractions: const [0.25, 0.75],
      children: [
        OutlinedBorder(child: debuggerPanes()),
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
                  Console(controller: controller),
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
          initialFractions: const [0.38, 0.38, 0.24],
          minSizes: const [0.0, 0.0, 0.0],
          headers: [
            debuggerPaneHeader(context, callStackTitle, needsTopBorder: false),
            debuggerPaneHeader(context, variablesTitle),
            debuggerPaneHeader(
              context,
              breakpointsTitle,
              rightChild: BreakpointsCountBadge(
                breakpoints: controller.breakpoints.value,
              ),
            ),
          ],
          children: [
            const Center(child: Text('TODO: call stack')),
            const Center(child: Text('TODO: variables')),
            BreakpointPicker(
              controller: controller,
              selected: selectedBreakpoint,
              onSelected: _onBreakpointSelected,
            ),
          ],
        );
      },
    );
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
