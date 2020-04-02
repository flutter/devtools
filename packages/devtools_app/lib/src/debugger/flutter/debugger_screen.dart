// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:vm_service/vm_service.dart';

import '../../flutter/common_widgets.dart';
import '../../flutter/flex_split_column.dart';
import '../../flutter/octicons.dart';
import '../../flutter/screen.dart';
import '../../flutter/split.dart';
import '../../flutter/theme.dart';
import '../../globals.dart';

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

class DebuggerScreenBodyState extends State<DebuggerScreenBody> {
  static const callStackTitle = 'Call Stack';
  static const variablesTitle = 'Variables';
  static const breakpointsTitle = 'Breakpoints';
  static const librariesTitle = 'Libraries';
  static const debuggerPaneHeaderHeight = 60.0;

  ScriptRef loadingScript;
  Script script;
  ScriptList scriptList;

  @override
  void initState() {
    super.initState();
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
      initialFractions: const [0.25, 0.75],
      // TODO(https://github.com/flutter/devtools/issues/1648): Debug panes.
      children: [
        OutlinedBorder(child: debuggerPanes()),
        // TODO(https://github.com/flutter/devtools/issues/1648): Debug controls.
        OutlinedBorder(
          child: loadingScript != null && script == null
              ? const Center(child: CircularProgressIndicator())
              : CodeView(
                  script: script,
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
            const Center(child: Text('TODO: breakpoints')),
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
    return Padding(
      padding: const EdgeInsets.only(left: denseSpacing),
      child: Column(
        mainAxisSize: MainAxisSize.max,
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

class CodeView extends StatelessWidget {
  const CodeView({Key key, this.script}) : super(key: key);

  final Script script;

  @override
  Widget build(BuildContext context) {
    // TODO(https://github.com/flutter/devtools/issues/1648): Line numbers,
    // syntax highlighting and breakpoint markers.
    if (script == null) {
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
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SingleChildScrollView(
            child: Text(script.source),
          ),
        ),
      ),
    );
  }
}
