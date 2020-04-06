// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:math' as math;

import 'package:flutter/material.dart' hide Stack;
import 'package:vm_service/vm_service.dart';

import '../../flutter/auto_dispose_mixin.dart';
import '../../flutter/common_widgets.dart';
import '../../flutter/controllers.dart';
import '../../flutter/flex_split_column.dart';
import '../../flutter/flutter_widgets/linked_scroll_controller.dart';
import '../../flutter/octicons.dart';
import '../../flutter/screen.dart';
import '../../flutter/split.dart';
import '../../flutter/theme.dart';
import '../../globals.dart';
import '../../ui/flutter/label.dart';
import 'debugger_controller.dart';

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
  static const debuggerPaneHeaderHeight = 60.0;

  DebuggerController controller;
  ScriptRef loadingScript;
  Script script;
  ScriptList scriptList;
  Stack stack;

  @override
  void initState() {
    super.initState();
    final newController = Controllers.of(context).debugger;
    if (newController == controller) return;
    controller = newController;
    addAutoDisposeListener(controller.isPaused, _onPaused);
    addAutoDisposeListener(controller.breakpoints);
    // TODO(djshuckerow): Make the loading process disposable.
    serviceManager.service
        .getScripts(serviceManager.isolateManager.selectedIsolate.id)
        .then((scripts) async {
      setState(() {
        scriptList = scripts;
      });
    });
  }

  Future<void> _onPaused() async {
    // TODO(https://github.com/flutter/devtools/issues/1648): Allow choice of
    // the scripts on the stack.
    if (controller.isPaused.value) {
      final currentStack = await controller.getStack();
      setState(() {
        stack = currentStack;
      });
      if (stack == null || stack.frames.isEmpty) return;
      final currentScript =
          await controller.getScript(stack.frames.first.location.script);
      setState(() {
        script = currentScript;
      });
    }
  }

  Future<void> onScriptSelected(ScriptRef ref) async {
    if (ref == null) return;
    setState(() {
      loadingScript = ref;
      script = null;
    });
    final result = await serviceManager.service.getObject(
      serviceManager.isolateManager.selectedIsolate.id,
      ref.id,
    ) as Script;

    setState(() {
      script = result;
    });
  }

  Map<int, Breakpoint> getBreakpointsForLines() {
    if (script == null) return {};
    String getScriptId(Breakpoint b) => b.location.script.id;

    final bps = controller.breakpoints.value
        .where((b) => b != null && getScriptId(b) == script.id);
    return {
      for (var b in bps) controller.lineNumber(script, b.location): b,
    };
  }

  Future<void> toggleBreakpoint(Script script, int line) async {
    final breakpoints = getBreakpointsForLines();
    if (breakpoints.containsKey(line)) {
      await controller.removeBreakpoint(breakpoints[line]);
    } else {
      await controller.addBreakpoint(script.id, line);
    }
    // The controller's breakpoints value listener will update us at this
    // point to rebuild.
  }

  @override
  Widget build(BuildContext context) {
    return Split(
      axis: Axis.horizontal,
      initialFractions: const [0.25, 0.75],
      // TODO(https://github.com/flutter/devtools/issues/1648): Debug panes.
      children: [
        OutlinedBorder(child: debuggerPanes()),
        // TODO(https://github.com/flutter/devtools/issues/1648): Debug controls.
        OutlinedBorder(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DebuggingControls(
                controller: controller,
              ),
              const Divider(height: 0.0),
              Expanded(
                child: loadingScript != null && script == null
                    ? const Center(child: CircularProgressIndicator())
                    : CodeView(
                        script: script,
                        stack: stack,
                        controller: controller,
                        lineNumberToBreakpoint: getBreakpointsForLines(),
                        onSelected: toggleBreakpoint,
                      ),
              ),
            ],
          ),
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
            BreakpointPicker(
              breakpoints: controller.breakpoints.value,
              controller: controller,
            ),
            ScriptPicker(
              scripts: scriptList,
              onSelected: onScriptSelected,
              selected: loadingScript,
            ),
          ],
        );
      },
    );
  }

  FlexSplitColumnHeader _debuggerPaneHeader(String title) {
    return FlexSplitColumnHeader(
      height: debuggerPaneHeaderHeight,
      child: Container(
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: Theme.of(context).focusColor),
          ),
          color: Theme.of(context).primaryColor,
        ),
        padding: const EdgeInsets.only(left: defaultSpacing),
        alignment: Alignment.centerLeft,
        height: debuggerPaneHeaderHeight,
        child: Text(
          title,
          style: Theme.of(context).textTheme.headline6,
        ),
      ),
    );
  }
}

class BreakpointPicker extends StatelessWidget {
  const BreakpointPicker(
      {Key key, @required this.breakpoints, @required this.controller})
      : super(key: key);
  final List<Breakpoint> breakpoints;
  final DebuggerController controller;

  String textFor(Breakpoint breakpoint) {
    if (breakpoint.resolved) {
      final location = breakpoint.location as SourceLocation;
      // TODO(djshuckerow): Resolve the scripts in the background and
      // switch from token position to line numbers.
      return '${location.script.uri.split('/').last} Position '
          '${location.tokenPos} (${location.script.uri})';
    } else {
      final location = breakpoint.location as UnresolvedSourceLocation;
      return '${location.script.uri.split('/').last} Position '
          '${location.line} (${location.script.uri})';
    }
  }

  @override
  Widget build(BuildContext context) {
    return _densePadding(
      child: Scrollbar(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: MediaQuery.of(context).size.width,
            child: ListView.builder(
              itemBuilder: (context, index) => SizedBox(
                height: _CodeViewState.rowHeight,
                child: Text(textFor(breakpoints[index])),
              ),
              itemCount: breakpoints.length,
            ),
          ),
        ),
      ),
    );
  }
}

/// Picker that takes a [ScriptList] and allows selection of one of the scripts inside.
class ScriptPicker extends StatefulWidget {
  const ScriptPicker(
      {Key key,
      @required this.scripts,
      @required this.onSelected,
      @required this.selected})
      : super(key: key);

  final ScriptList scripts;
  final void Function(ScriptRef scriptRef) onSelected;
  final ScriptRef selected;

  @override
  ScriptPickerState createState() => ScriptPickerState();
}

class ScriptPickerState extends State<ScriptPicker> {
  List<ScriptRef> _filtered;
  TextEditingController filterController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (_isNotLoaded) initFilter();
  }

  @override
  void didUpdateWidget(ScriptPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_isNotLoaded) {
      initFilter();
    } else if (oldWidget.scripts != widget.scripts) {
      updateFilter(filterController.text);
    }
  }

  void initFilter() {
    // Make an educated guess as to the main package to slim down the initial list of scripts we show.
    if (widget.scripts?.scripts != null) {
      final mainFile = widget.scripts.scripts
          .firstWhere((ref) => ref.uri.contains('main.dart'));
      filterController.text = mainFile.uri.split('/').first;
      updateFilter(filterController.text);
    }
  }

  void updateFilter(String value) {
    setState(() {
      if (widget.scripts?.scripts == null) {
        _filtered = null;
      } else {
        // TODO(djshuckerow): Use DebuggerState.getShortScriptName logic here.
        _filtered = widget.scripts.scripts
            .where((ref) => ref.uri.contains(value.toLowerCase()))
            .toList();
      }
    });
  }

  Widget _buildScript(ScriptRef ref) {
    final selectedColor = Theme.of(context).selectedRowColor;
    return Material(
      color: ref == widget.selected ? selectedColor : null,
      child: InkWell(
        onTap: () => widget.onSelected(ref),
        child: Container(
          padding: const EdgeInsets.all(4.0),
          alignment: Alignment.centerLeft,
          child: Text('${ref?.uri?.split('/')?.last} (${ref?.uri})'),
        ),
      ),
    );
  }

  bool get _isNotLoaded => _filtered == null || widget.scripts?.scripts == null;

  @override
  Widget build(BuildContext context) {
    if (_isNotLoaded) {
      return const Center(child: CircularProgressIndicator());
    }
    final items = _filtered;
    return _densePadding(
      child: Column(
        children: [
          TextField(
            decoration: const InputDecoration(
              labelText: 'Filter',
              border: UnderlineInputBorder(),
            ),
            controller: filterController,
            onChanged: updateFilter,
          ),
          Expanded(
            child: Scrollbar(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: MediaQuery.of(context).size.width,
                  child: ListView.builder(
                    itemBuilder: (context, index) => _buildScript(items[index]),
                    itemCount: items.length,
                    itemExtent: 32.0,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class DebuggingControls extends StatelessWidget {
  const DebuggingControls({Key key, @required this.controller})
      : super(key: key);

  final DebuggerController controller;

  static const controlsHeight = 56.0;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: controller.isPaused,
      builder: (context, isPaused, child) {
        return SizedBox(
          height: controlsHeight,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              MaterialButton(
                onPressed: isPaused ? null : controller.pause,
                child: MaterialIconLabel(
                  Icons.pause,
                  'Pause',
                ),
              ),
              MaterialButton(
                onPressed: isPaused ? controller.resume : null,
                child: MaterialIconLabel(
                  Icons.play_arrow,
                  'Resume',
                ),
              ),
              MaterialButton(
                onPressed: isPaused ? controller.stepIn : null,
                child: MaterialIconLabel(
                  Icons.keyboard_arrow_down,
                  'Step In',
                ),
              ),
              MaterialButton(
                onPressed: isPaused ? controller.stepOver : null,
                child: MaterialIconLabel(
                  Icons.keyboard_arrow_right,
                  'Step Over',
                ),
              ),
              MaterialButton(
                onPressed: isPaused ? controller.stepOut : null,
                child: MaterialIconLabel(
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

class CodeView extends StatefulWidget {
  const CodeView({
    Key key,
    this.script,
    this.stack,
    this.controller,
    this.onSelected,
    this.lineNumberToBreakpoint,
  }) : super(key: key);

  final DebuggerController controller;
  final Map<int, Breakpoint> lineNumberToBreakpoint;
  final Script script;
  final Stack stack;
  final void Function(Script script, int line) onSelected;

  @override
  _CodeViewState createState() => _CodeViewState();
}

class _CodeViewState extends State<CodeView> {
  List<String> lines = [];
  ScrollController _horizontalController;
  LinkedScrollControllerGroup verticalController;
  ScrollController gutterController;
  ScrollController textController;
  // The paused positions in the current [widget.script] from the [widget.stack].
  List<int> pausedPositions;

  static const rowHeight = 32.0;
  static const assumedCharacterWidth = 16.0;

  @override
  void initState() {
    super.initState();
    _horizontalController = ScrollController();
    verticalController = LinkedScrollControllerGroup();
    gutterController = verticalController.addAndGet();
    textController = verticalController.addAndGet();
    _updateLines();
    _updatePausedPositions();
  }

  @override
  void dispose() {
    super.dispose();
    _horizontalController.dispose();
    gutterController.dispose();
    textController.dispose();
  }

  @override
  void didUpdateWidget(CodeView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.script != oldWidget.script) {
      _updateLines();
    }
    if (widget.stack != oldWidget.stack) {
      _updatePausedPositions();
    }
  }

  void _updateLines() {
    setState(() {
      lines = widget.script?.source?.split('\n') ?? [];
    });
  }

  void _updatePausedPositions() {
    setState(() {
      final framesInScript = (widget.stack?.frames ?? [])
          .where((frame) => frame.location.script.id == widget.script?.id);
      pausedPositions = [
        for (var frame in framesInScript)
          widget.controller.lineNumber(widget.script, frame.location)
      ];
    });

    if (pausedPositions.isNotEmpty) {
      verticalController.animateTo(
        pausedPositions.first * rowHeight,
        duration: shortDuration,
        curve: defaultCurve,
      );
    }
  }

  void _onPressed(int line) {
    widget.onSelected(widget.script, line);
  }

  @override
  Widget build(BuildContext context) {
    // TODO(https://github.com/flutter/devtools/issues/1648): Line numbers,
    // syntax highlighting and breakpoint markers.
    if (widget.script == null) {
      return Center(
        child: Text(
          'No script selected',
          style: Theme.of(context).textTheme.subtitle1,
        ),
      );
    }
    // Apply the log change-of-base formula, then add 16dp
    // padding for every digit in the maximum number of lines.
    final gutterWidth = lines.isEmpty
        ? _CodeViewState.assumedCharacterWidth
        : _CodeViewState.assumedCharacterWidth *
            (math.log(lines.length) / math.ln10);
    return DefaultTextStyle(
      style: Theme.of(context)
          .textTheme
          .bodyText2
          .copyWith(fontFamily: 'RobotoMono'),
      child: Scrollbar(
        child: Row(
          children: [
            SizedBox(
              width: gutterWidth,
              child: ListView(
                controller: gutterController,
                children: [
                  for (var i = 0; i < lines.length; i++)
                    GutterRow(
                      lineNumber: i,
                      totalLines: lines.length,
                      onPressed: () => _onPressed(i),
                      isBreakpoint:
                          widget.lineNumberToBreakpoint.containsKey(i),
                    ),
                ],
                itemExtent: rowHeight,
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                controller: _horizontalController,
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: assumedCharacterWidth *
                      lines
                          .map((s) => s.length)
                          .reduce((a, b) => math.max(a, b)),
                  child: ListView(
                    controller: textController,
                    children: [
                      for (var i = 0; i < lines.length; i++)
                        ScriptRow(
                          lineContents: lines[i],
                          onPressed: () => _onPressed(i),
                          isPausedHere: pausedPositions.contains(i),
                        )
                    ],
                    itemExtent: rowHeight,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class GutterRow extends StatelessWidget {
  const GutterRow({
    Key key,
    @required this.lineNumber,
    @required this.totalLines,
    @required this.onPressed,
    @required this.isBreakpoint,
  }) : super(key: key);
  final int lineNumber;
  final int totalLines;
  final VoidCallback onPressed;
  // TODO(djshuckerow): Add support for multiple breakpoints in a line and
  // different types of decorators than just breakpoints.
  final bool isBreakpoint;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPressed,
      child: Container(
        height: _CodeViewState.rowHeight,
        padding: const EdgeInsets.only(left: 4.0),
        decoration: isBreakpoint
            ? BoxDecoration(
                border: Border.all(color: Theme.of(context).accentColor),
                color: Theme.of(context).primaryColorDark,
              )
            : BoxDecoration(color: Theme.of(context).primaryColorDark),
        child: Text(
          '$lineNumber',
          style: TextStyle(
            color: Theme.of(context).primaryTextTheme.bodyText2.color,
          ),
        ),
      ),
    );
  }
}

class ScriptRow extends StatelessWidget {
  const ScriptRow({
    Key key,
    @required this.lineContents,
    @required this.onPressed,
    @required this.isPausedHere,
  }) : super(key: key);

  final String lineContents;
  final VoidCallback onPressed;
  final bool isPausedHere;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPressed,
      child: Container(
        alignment: Alignment.centerLeft,
        height: _CodeViewState.rowHeight,
        color: isPausedHere ? Theme.of(context).selectedRowColor : null,
        child: Text(lineContents),
      ),
    );
  }
}

Widget _densePadding({@required Widget child}) {
  return Padding(
      padding: const EdgeInsets.only(left: denseSpacing), child: child);
}
