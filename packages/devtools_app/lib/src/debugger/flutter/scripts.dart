// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:vm_service/vm_service.dart';

import '../../flutter/common_widgets.dart';
import '../../flutter/theme.dart';
import '../../utils.dart';
import 'debugger_controller.dart';
import 'debugger_screen.dart';

/// Picker that takes a [ScriptList] and allows selection of one of the scripts
/// inside.
class ScriptPicker extends StatefulWidget {
  const ScriptPicker({
    Key key,
    @required this.controller,
    @required this.scripts,
    @required this.selected,
    @required this.onSelected,
  }) : super(key: key);

  final DebuggerController controller;
  final List<ScriptRef> scripts;
  final ScriptRef selected;
  final void Function(ScriptRef scriptRef) onSelected;

  @override
  ScriptPickerState createState() => ScriptPickerState();
}

class ScriptPickerState extends State<ScriptPicker> {
  final _filterController = TextEditingController();
  List<ScriptRef> _filteredScripts = [];

  @override
  void initState() {
    super.initState();

    _updateFiltered();
  }

  @override
  void didUpdateWidget(ScriptPicker oldWidget) {
    super.didUpdateWidget(oldWidget);

    updateFilter();
  }

  void updateFilter() {
    setState(_updateFiltered);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return OutlinedBorder(
      child: Column(
        children: [
          debuggerPaneHeader(
            context,
            'Libraries',
            needsTopBorder: false,
            rightChild: ScriptCountBadge(
              filteredScripts: _filteredScripts,
              scripts: widget.controller.sortedScripts.value,
            ),
          ),
          Container(
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: theme.focusColor),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(denseSpacing),
              child: SizedBox(
                height: 36.0,
                child: TextField(
                  decoration: const InputDecoration(
                    labelText: 'Filter',
                    border: OutlineInputBorder(),
                  ),
                  controller: _filterController,
                  onChanged: (value) => updateFilter(),
                  style: Theme.of(context).textTheme.bodyText2,
                ),
              ),
            ),
          ),
          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(),
            ),
          if (!_isLoading)
            Expanded(
              child: ListView.builder(
                itemCount: _filteredScripts.length,
                itemExtent: defaultListItemHeight,
                itemBuilder: (context, index) =>
                    _buildScript(_filteredScripts[index]),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildScript(ScriptRef ref) {
    return Material(
      color: ref.id == widget.selected?.id
          ? Theme.of(context).selectedRowColor
          : null,
      child: InkWell(
        onTap: () => widget.onSelected(ref),
        child: Container(
          padding: const EdgeInsets.all(densePadding),
          alignment: Alignment.centerLeft,
          child: Text(
            ref.uri,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: ref.id == widget.selected?.id
                ? TextStyle(color: Theme.of(context).textSelectionColor)
                : null,
          ),
        ),
      ),
    );
  }

  bool get _isLoading => widget.scripts.isEmpty;

  void _updateFiltered() {
    final filterText = _filterController.text.trim().toLowerCase();
    _filteredScripts = widget.scripts
        .where((ref) => ref.uri.toLowerCase().contains(filterText))
        .toList();
  }
}

class ScriptCountBadge extends StatelessWidget {
  const ScriptCountBadge({
    @required this.filteredScripts,
    @required this.scripts,
  });

  final List<ScriptRef> filteredScripts;
  final List<ScriptRef> scripts;

  @override
  Widget build(BuildContext context) {
    if (filteredScripts.length == scripts.length) {
      return Badge('${nf.format(scripts.length)}');
    } else {
      return Badge('${nf.format(filteredScripts.length)} of '
          '${nf.format(scripts.length)}');
    }
  }
}
