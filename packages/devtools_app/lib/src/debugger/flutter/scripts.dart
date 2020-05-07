// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:vm_service/vm_service.dart';

import '../../flutter/common_widgets.dart';
import '../../flutter/theme.dart';
import '../../utils.dart';
import 'debugger_controller.dart';
import 'debugger_model.dart';
import 'debugger_screen.dart';

const libraryIcon = Icons.insert_chart;
const classIcon = Icons.album;

/// Picker that takes a list of scripts and classes and allows filtering and
/// selection of items.
class ScriptPicker extends StatefulWidget {
  const ScriptPicker({
    Key key,
    @required this.controller,
    @required this.scripts,
    @required this.classes,
    @required this.onSelected,
    this.libraryFilterFocusNode,
  }) : super(key: key);

  final DebuggerController controller;
  final List<ScriptRef> scripts;
  final List<ClassRef> classes;
  final void Function(ScriptLocation scriptRef) onSelected;
  final FocusNode libraryFilterFocusNode;

  @override
  ScriptPickerState createState() => ScriptPickerState();
}

class ScriptPickerState extends State<ScriptPicker> {
  // TODO(devoncarew): How to retain the filter text state?
  final _filterController = TextEditingController();

  List<ObjRef> _items = [];
  List<ObjRef> _filteredItems = [];

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
            'Libraries and Classes',
            needsTopBorder: false,
            rightChild: CountBadge(
              filteredItems: _filteredItems,
              items: _items,
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
                    labelText: 'Filter (Ctrl + P)',
                    border: OutlineInputBorder(),
                  ),
                  controller: _filterController,
                  onChanged: (value) => updateFilter(),
                  style: Theme.of(context).textTheme.bodyText2,
                  focusNode: widget.libraryFilterFocusNode,
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
                itemCount: _filteredItems.length,
                itemExtent: defaultListItemHeight,
                itemBuilder: (context, index) =>
                    _buildItemWidget(_filteredItems[index]),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildItemWidget(ObjRef ref) {
    String text;
    IconData icon;

    if (ref is ScriptRef) {
      text = ref.uri;
      icon = libraryIcon;
    } else if (ref is ClassRef) {
      text = ref.name;
      icon = classIcon;
    } else {
      assert(false, 'unexpected object reference: ${ref.type}');
    }

    return Material(
      child: InkWell(
        onTap: () => _handleSelected(ref),
        child: Container(
          padding: const EdgeInsets.all(densePadding),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: defaultIconSize,
              ),
              const SizedBox(width: densePadding),
              Expanded(
                child: Text(
                  text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool get _isLoading => widget.scripts.isEmpty;

  void _updateFiltered() {
    final filterText = _filterController.text.trim().toLowerCase();

    _items = [...widget.scripts, ...widget.classes];

    _filteredItems = [
      ...widget.scripts
          .where((ref) => ref.uri.toLowerCase().contains(filterText)),
      ...widget.classes
          .where((ref) => ref.name.toLowerCase().contains(filterText)),
    ];
  }

  void _handleSelected(ObjRef ref) async {
    if (ref is ScriptRef) {
      widget.onSelected(ScriptLocation(ref));
    } else if (ref is ClassRef) {
      final obj = await widget.controller.getObject(ref);
      final location = (obj as Class).location;
      final script = await widget.controller.getScript(location.script);
      final pos =
          widget.controller.calculatePosition(script, location.tokenPos);

      widget.onSelected(ScriptLocation(script, location: pos));
    } else {
      assert(false, 'unexpected object reference: ${ref.type}');
    }
  }
}

class CountBadge extends StatelessWidget {
  const CountBadge({
    @required this.filteredItems,
    @required this.items,
  });

  final List<ObjRef> filteredItems;
  final List<ObjRef> items;

  @override
  Widget build(BuildContext context) {
    if (filteredItems.length == items.length) {
      return Badge('${nf.format(items.length)}');
    } else {
      return Badge('${nf.format(filteredItems.length)} of '
          '${nf.format(items.length)}');
    }
  }
}
