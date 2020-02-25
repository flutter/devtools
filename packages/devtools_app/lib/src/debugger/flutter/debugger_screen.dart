// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:vm_service/vm_service.dart';

import '../../flutter/common_widgets.dart';
import '../../flutter/flutter_widgets/linked_scroll_controller.dart';
import '../../flutter/octicons.dart';
import '../../flutter/screen.dart';
import '../../flutter/split.dart';
import '../../globals.dart';
import 'debugger_controller.dart';

class DebuggerScreen extends Screen {
  const DebuggerScreen() : super(DevToolsScreenType.debugger);

  @override
  Widget build(BuildContext context) {
    return DebuggerScreenBody();
  }

  @override
  Widget buildTab(BuildContext context) {
    return const Tab(
      text: 'Debugger',
      icon: Icon(Octicons.bug),
    );
  }
}

class DebuggerScreenBody extends StatefulWidget {
  @override
  DebuggerScreenBodyState createState() => DebuggerScreenBodyState();
}

class DebuggerScreenBodyState extends State<DebuggerScreenBody> {
  DebuggerController controller;
  ScriptRef loadingScript;
  Script script;
  ScriptList scriptList;

  @override
  void initState() {
    super.initState();
    controller?.setVmService(serviceManager.service);
    // TODO(https://github.com/flutter/devtools/issues/1648): Make file picker.
    // Make the loading process disposable.
    serviceManager.service
        .getScripts(serviceManager.isolateManager.selectedIsolate.id)
        .then((scripts) async {
      setState(() {
        scriptList = scripts;
      });
    });
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

  @override
  Widget build(BuildContext context) {
    return Split(
      axis: Axis.horizontal,
      initialFirstFraction: 0.25,
      // TODO(https://github.com/flutter/devtools/issues/1648): Debug panes.
      firstChild: OutlinedBorder(
        child: Column(
          children: [
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
        child: loadingScript != null && script == null
            ? const Center(child: CircularProgressIndicator())
            : CodeView(
                script: script,
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

class CodeView extends StatefulWidget {
  const CodeView({Key key, this.script, this.onSelected}) : super(key: key);

  final Script script;
  final void Function(Script script, int row, int column) onSelected;

  @override
  _CodeViewState createState() => _CodeViewState();
}

class _CodeViewState extends State<CodeView> {
  List<String> lines = [];
  LinkedScrollControllerGroup _horizontalController;

  @override
  void initState() {
    super.initState();
    _horizontalController = LinkedScrollControllerGroup();
    _updateLines();
  }

  @override
  void didUpdateWidget(CodeView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.script != oldWidget.script) {
      _updateLines();
    }
  }

  void _updateLines() {
    setState(() {
      lines = widget.script?.source?.split('\n') ?? [];
    });
  }

  void _onPressed(int line) {}

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
          itemBuilder: (context, index) {
            return ScriptRow(
              group: _horizontalController,
              lineNumber: index,
              lineContents: lines[index],
              onPressed: () => _onPressed(index),
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
  const ScriptRow(
      {Key key, this.group, this.lineNumber, this.lineContents, this.onPressed})
      : super(key: key);
  final int lineNumber;
  final String lineContents;
  final LinkedScrollControllerGroup group;
  final VoidCallback onPressed;

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
      child: InkWell(
        onTap: widget.onPressed,
        child: ListView(
          scrollDirection: Axis.horizontal,
          controller: linkedController,
          children: [
            Container(
              width: 48.0,
              padding: const EdgeInsets.only(left: 4.0),
              color: Theme.of(context).primaryColorDark,
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
