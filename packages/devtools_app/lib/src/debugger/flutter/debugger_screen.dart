// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/src/flutter/theme.dart';
import 'package:flutter/material.dart' hide Stack;
import 'package:vm_service/vm_service.dart';

import '../../flutter/auto_dispose_mixin.dart';
import '../../flutter/common_widgets.dart';
import '../../flutter/flutter_widgets/linked_scroll_controller.dart';
import '../../flutter/octicons.dart';
import '../../flutter/screen.dart';
import '../../flutter/split.dart';
import '../../globals.dart';
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
  DebuggerController controller;
  ScriptRef loadingScript;
  Script script;
  ScriptList scriptList;
  Stack stack;

  @override
  void initState() {
    super.initState();
    // TODO(djshuckerow): promote this controller to app-level Controllers.
    controller = DebuggerController();
    controller.setVmService(serviceManager.service);
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
      for (var b in bps) controller.getLineNumber(script, b.location): b,
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
      initialFirstFraction: 0.25,
      // TODO(https://github.com/flutter/devtools/issues/1648): Debug panes.
      firstChild: OutlinedBorder(
        child: Column(
          children: [
            const Text('Breakpoints'),
            Expanded(
              child: BreakpointPicker(
                breakpoints: controller.breakpoints.value,
              ),
            ),
            const Divider(),
            const Text('Scripts'),
            Expanded(
              child: ScriptPicker(
                scripts: scriptList,
                onSelected: onScriptSelected,
                selected: loadingScript,
              ),
            ),
          ],
        ),
      ),
      // TODO(https://github.com/flutter/devtools/issues/1648): Debug controls.
      secondChild: OutlinedBorder(
        child: Column(
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
                      breakpoints: getBreakpointsForLines(),
                      onSelected: toggleBreakpoint,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class BreakpointPicker extends StatelessWidget {
  const BreakpointPicker({Key key, this.breakpoints, this.controller})
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
    return Scrollbar(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: MediaQuery.of(context).size.width,
          child: ListView.builder(
            itemBuilder: (context, index) => SizedBox(
              height: ScriptRow.rowHeight,
              child: Text(textFor(breakpoints[index])),
            ),
            itemCount: breakpoints.length,
          ),
        ),
      ),
    );
  }
}

/// Picker that takes a [ScriptList] and allows selection of one of the scripts inside.
class ScriptPicker extends StatefulWidget {
  const ScriptPicker({Key key, this.scripts, this.onSelected, this.selected})
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
    return Column(
      mainAxisSize: MainAxisSize.max,
      children: [
        TextField(
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
        return Row(children: [
          MaterialButton(
            onPressed: isPaused ? null : controller.pause,
            child: const Text('Pause'),
          ),
          MaterialButton(
            onPressed: isPaused ? controller.resume : null,
            child: const Text('Resume'),
          ),
          MaterialButton(
            onPressed: isPaused ? controller.stepIn : null,
            child: const Text('Step In'),
          ),
          MaterialButton(
            onPressed: isPaused ? controller.stepOver : null,
            child: const Text('Step Over'),
          ),
          MaterialButton(
            onPressed: isPaused ? controller.stepOut : null,
            child: const Text('Step Out'),
          ),
        ]);
      },
    );
  }
}

class CodeView extends StatefulWidget {
  const CodeView(
      {Key key,
      this.script,
      this.stack,
      this.controller,
      this.onSelected,
      this.breakpoints})
      : super(key: key);

  final DebuggerController controller;
  final Map<int, Breakpoint> breakpoints;
  final Script script;
  final Stack stack;
  final void Function(Script script, int line) onSelected;

  @override
  _CodeViewState createState() => _CodeViewState();
}

class _CodeViewState extends State<CodeView> {
  List<String> lines = [];
  LinkedScrollControllerGroup _horizontalController;
  ScrollController verticalController;
  // The paused positions in the current [widget.script] from the [widget.stack].
  List<int> pausedPositions;

  @override
  void initState() {
    super.initState();
    verticalController = ScrollController();
    _horizontalController = LinkedScrollControllerGroup();
    _updateLines();
    _updatePausedPositions();
  }

  @override
  void dispose() {
    super.dispose();
    verticalController.dispose();
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
          .where((frame) => frame.location.script.id == widget.script.id);
      pausedPositions = [
        for (var frame in framesInScript)
          widget.controller.getLineNumber(widget.script, frame.location)
      ];
    });

    if (pausedPositions.isNotEmpty) {
      verticalController.animateTo(
        pausedPositions.first * ScriptRow.rowHeight,
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
    return DefaultTextStyle(
      style: Theme.of(context)
          .textTheme
          .bodyText2
          .copyWith(fontFamily: 'RobotoMono'),
      child: Scrollbar(
        child: ListView.builder(
          controller: verticalController,
          itemBuilder: (context, index) {
            return ScriptRow(
              group: _horizontalController,
              lineNumber: index,
              lineContents: lines[index],
              onPressed: () => _onPressed(index),
              isBreakpoint: widget.breakpoints.containsKey(index),
              isPausedHere: pausedPositions.contains(index),
            );
          },
          itemCount: lines.length,
          itemExtent: ScriptRow.rowHeight,
        ),
      ),
    );
  }
}

class ScriptRow extends StatefulWidget {
  const ScriptRow({
    Key key,
    this.group,
    this.lineNumber,
    this.lineContents,
    this.onPressed,
    @required this.isPausedHere,
    @required this.isBreakpoint,
  }) : super(key: key);

  final int lineNumber;
  final String lineContents;
  final LinkedScrollControllerGroup group;
  final VoidCallback onPressed;
  final bool isBreakpoint;
  final bool isPausedHere;

  static const rowHeight = 32.0;

  @override
  _ScriptRowState createState() => _ScriptRowState();
}

class _ScriptRowState extends State<ScriptRow> {
  ScrollController linkedController;

  @override
  void initState() {
    super.initState();
    linkedController = widget.group.addAndGet();
  }

  @override
  void didUpdateWidget(ScriptRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.group != oldWidget.group) {
      linkedController.dispose();
      linkedController = widget.group.addAndGet();
    }
  }

  @override
  void dispose() {
    linkedController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.centerLeft,
      height: ScriptRow.rowHeight,
      color: widget.isPausedHere ? Theme.of(context).selectedRowColor : null,
      child: InkWell(
        onTap: widget.onPressed,
        child: ListView(
          scrollDirection: Axis.horizontal,
          controller: linkedController,
          children: [
            Container(
              // TODO(djshuckerow): Measure the longest line number for sizing.
              width: 48.0,
              padding: const EdgeInsets.only(left: 4.0),
              decoration: widget.isBreakpoint
                  ? BoxDecoration(
                      border: Border.all(color: Theme.of(context).accentColor),
                      color: Theme.of(context).primaryColorDark,
                    )
                  : BoxDecoration(color: Theme.of(context).primaryColorDark),
              child: Text(
                '${widget.lineNumber}',
                style: TextStyle(
                  color: Theme.of(context).primaryTextTheme.bodyText2.color,
                ),
              ),
            ),
            Text(widget.lineContents),
          ],
        ),
      ),
    );
  }
}
