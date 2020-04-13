// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:vm_service/vm_service.dart';

import 'common.dart';

/// Picker that takes a [ScriptList] and allows selection of one of the scripts
/// inside.
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
          child: Text(
            '${ref?.uri?.split('/')?.last} (${ref?.uri})',
            style: ref == widget.selected
                ? TextStyle(color: Theme.of(context).textSelectionColor)
                : null,
          ),
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
          child: densePadding(
            Scrollbar(
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
        ),
      ],
    );
  }
}
