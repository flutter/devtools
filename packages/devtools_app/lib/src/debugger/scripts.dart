// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:vm_service/vm_service.dart';

import '../common_widgets.dart';
import '../theme.dart';
import '../tree.dart';
import '../utils.dart';
import 'debugger_controller.dart';
import 'debugger_model.dart';

const containerIcon = Icons.folder;
const libraryIcon = Icons.insert_chart;
double get listItemHeight => scaleByFontFactor(40.0);

/// Picker that takes a list of scripts and allows selection of items.
class ScriptPicker extends StatefulWidget {
  const ScriptPicker({
    Key key,
    @required this.controller,
    @required this.scripts,
    @required this.onSelected,
  }) : super(key: key);

  final DebuggerController controller;
  final List<ScriptRef> scripts;
  final void Function(ScriptLocation scriptRef) onSelected;

  @override
  ScriptPickerState createState() => ScriptPickerState();
}

class ScriptPickerState extends State<ScriptPicker> {

  List<ObjRef> _items = [];
  List<FileNode> _rootScriptNodes;

  @override
  void initState() {
    super.initState();

    _updateScripts();
  }

  @override
  void didUpdateWidget(ScriptPicker oldWidget) {
    super.didUpdateWidget(oldWidget);

    updateScripts();
  }

  void updateScripts() {
    setState(_updateScripts);
  }

  @override
  Widget build(BuildContext context) {
    // Re-calculate the tree of scripts if necessary.
    _rootScriptNodes ??= FileNode.createRootsFrom(_items);

    return OutlineDecoration(
      child: Column(
        children: [
          const AreaPaneHeader(
            title: Text('Libraries'),
            needsTopBorder: false,
          ),
          if (_isLoading) const CenteredCircularProgressIndicator(),
          if (!_isLoading)
            Expanded(
              child: TreeView<FileNode>(
                itemExtent: listItemHeight,
                dataRoots: _rootScriptNodes,
                dataDisplayProvider: (item, onTap) =>
                    _displayProvider(context, item, onTap),
              ),
            ),
        ],
      ),
    );
  }

  Widget _displayProvider(
    BuildContext context,
    FileNode node,
    VoidCallback onTap,
  ) {
    return DevToolsTooltip(
      tooltip: node.name,
      child: Material(
        child: InkWell(
          onTap: () {
            if (node.hasScript) {
              _handleSelected(node.scriptRef);
            }
            onTap();
          },
          child: Row(
            children: [
              Icon(
                node.hasScript ? libraryIcon : containerIcon,
                size: defaultIconSize,
              ),
              const SizedBox(width: densePadding),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!node.hasScript)
                      Text(
                        node.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      )
                    else ...[
                      Text(
                        node.fileName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        node.scriptRef.uri,
                        style: Theme.of(context).subtleTextStyle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ]
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool get _isLoading => widget.scripts.isEmpty;

  void _updateScripts() {
    _items = widget.scripts;
    
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
