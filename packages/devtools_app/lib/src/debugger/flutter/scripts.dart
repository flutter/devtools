// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:vm_service/vm_service.dart';

import '../../flutter/theme.dart';

// todo: improve display
// todo: add a count
// todo: make the filter smaller

/// Picker that takes a [ScriptList] and allows selection of one of the scripts
/// inside.
class ScriptPicker extends StatefulWidget {
  const ScriptPicker({
    Key key,
    @required this.scripts,
    @required this.selected,
    @required this.onSelected,
  }) : super(key: key);

  final ScriptList scripts;
  final ScriptRef selected;
  final void Function(ScriptRef scriptRef) onSelected;

  @override
  ScriptPickerState createState() => ScriptPickerState();
}

class ScriptPickerState extends State<ScriptPicker> {
  final TextEditingController _filterController = TextEditingController();
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
    if (_isNotLoaded) {
      return const Center(child: CircularProgressIndicator());
    }

    final items = _filteredScripts;

    return Column(
      children: [
        TextField(
          decoration: const InputDecoration(
            labelText: 'Filter',
            border: UnderlineInputBorder(),
          ),
          controller: _filterController,
          onChanged: (value) => updateFilter(),
          style: Theme.of(context).textTheme.bodyText2,
        ),
        Expanded(
          child: ListView.builder(
            itemCount: items.length,
            itemExtent: defaultListItemHeight,
            itemBuilder: (context, index) => _buildScript(items[index]),
          ),
        ),
      ],
    );
  }

  Widget _buildScript(ScriptRef ref) {
    // TODO(devoncarew): Should we use DebuggerState.getShortScriptName here?

    return Material(
      color: ref.uri == widget.selected?.uri
          ? Theme.of(context).selectedRowColor
          : null,
      child: InkWell(
        onTap: () => widget.onSelected(ref),
        child: Container(
          padding: const EdgeInsets.all(4.0),
          alignment: Alignment.centerLeft,
          child: Text(
            '${ref?.uri}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: ref == widget.selected
                ? TextStyle(color: Theme.of(context).textSelectionColor)
                : null,
          ),
        ),
      ),
    );
  }

  bool get _isNotLoaded => widget.scripts?.scripts == null;

  void _updateFiltered() {
    if (widget.scripts?.scripts == null) {
      _filteredScripts = [];
    } else {
      final filterText = _filterController.text.trim().toLowerCase();

      // todo: move this logic to the controller?

      // TODO(devoncarew): Follow up to see why we need to filter out non-unique
      // items here.
      _filteredScripts = Set.of(widget.scripts.scripts)
          .where((ref) => ref.uri.toLowerCase().contains(filterText))
          .toList();

      // TODO: Sort things like dart:_ after dart:?
      _filteredScripts.sort((a, b) {
        return a.uri.compareTo(b.uri);
      });

      print('_filteredScripts.length: ${_filteredScripts.length}');
    }
  }
}
