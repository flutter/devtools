// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:vm_service/vm_service.dart';

import '../common_widgets.dart';
import '../config_specific/host_platform/host_platform.dart';
import '../theme.dart';
import '../tree.dart';
import '../utils.dart';
import 'debugger_controller.dart';
import 'debugger_model.dart';
import 'debugger_screen.dart';

const containerIcon = Icons.folder;
const libraryIcon = Icons.insert_chart;

/// Picker that takes a list of scripts and allows filtering and selection of
/// items.
class ScriptPicker extends StatefulWidget {
  const ScriptPicker({
    Key key,
    @required this.controller,
    @required this.scripts,
    @required this.onSelected,
    this.libraryFilterFocusNode,
  }) : super(key: key);

  final DebuggerController controller;
  final List<ScriptRef> scripts;
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
  List<FileNode> _rootScriptNodes;

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
    final isMacOS = HostPlatform.instance.isMacOS;

    // Re-calculate the tree of scripts if necessary.
    _rootScriptNodes ??= FileNode.createRootsFrom(_filteredItems);

    return OutlineDecoration(
      child: Column(
        children: [
          areaPaneHeader(
            context,
            title: 'Libraries',
            needsTopBorder: false,
            actions: [
              CountBadge(
                filteredItems: _filteredItems,
                items: _items,
              ),
            ],
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
                height: defaultTextFieldHeight,
                child: TextField(
                  decoration: InputDecoration(
                    labelText:
                        'Filter (${focusLibraryFilterKeySet.describeKeys(isMacOS: isMacOS)})',
                    border: const OutlineInputBorder(),
                  ),
                  controller: _filterController,
                  onChanged: (value) => updateFilter(),
                  style: Theme.of(context).textTheme.bodyText2,
                  focusNode: widget.libraryFilterFocusNode,
                ),
              ),
            ),
          ),
          if (_isLoading) const CenteredCircularProgressIndicator(),
          if (!_isLoading)
            Expanded(
              child: TreeView<FileNode>(
                dataRoots: _rootScriptNodes,
                dataDisplayProvider: (item) => _displayProvider(context, item),
              ),
            ),
        ],
      ),
    );
  }

  Widget _displayProvider(BuildContext context, FileNode node) {
    return Tooltip(
      waitDuration: tooltipWait,
      preferBelow: false,
      message: node.name,
      child: Material(
        child: InkWell(
          onTap: () {
            if (node.hasScript) {
              _handleSelected(node.scriptRef);
            }
          },
          child: Row(
            children: [
              Icon(
                node.hasScript ? libraryIcon : containerIcon,
                size: defaultIconSize,
              ),
              const SizedBox(width: densePadding),
              Expanded(
                child: Text(
                  node.name,
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

    _items = widget.scripts;
    _filteredItems = widget.scripts
        .where((ref) => ref.uri.toLowerCase().contains(filterText))
        .toList();

    // Remove the cached value here; it'll be re-computed the next time we need
    // it.
    _rootScriptNodes = null;
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
