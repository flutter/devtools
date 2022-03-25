// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// ignore_for_file: import_of_legacy_library_into_null_safe

import 'package:flutter/widgets.dart';

import '../../../primitives/auto_dispose_mixin.dart';
import '../diagnostics_node.dart';
import '../inspector_controller.dart';
import '../layout_explorer/box/box.dart';
import '../layout_explorer/flex/flex.dart';

/// Tab that acts as a proxy to decide which widget to be displayed
class LayoutExplorerTab extends StatefulWidget {
  const LayoutExplorerTab({Key? key, this.controller}) : super(key: key);

  final InspectorController? controller;

  @override
  _LayoutExplorerTabState createState() => _LayoutExplorerTabState();
}

class _LayoutExplorerTabState extends State<LayoutExplorerTab>
    with AutomaticKeepAliveClientMixin<LayoutExplorerTab>, AutoDisposeMixin {
  InspectorController? get controller => widget.controller;

  RemoteDiagnosticsNode? get selected =>
      controller?.selectedNode.value?.diagnostic;

  RemoteDiagnosticsNode? previousSelection;

  Widget rootWidget(RemoteDiagnosticsNode? node) {
    if (FlexLayoutExplorerWidget.shouldDisplay(node)) {
      return FlexLayoutExplorerWidget(controller!);
    }
    if (BoxLayoutExplorerWidget.shouldDisplay(node)) {
      return BoxLayoutExplorerWidget(controller!);
    }
    return Center(
      child: Text(
        node != null
            ? 'Currently, Layout Explorer only supports Box and Flex-based widgets.'
            : 'Select a widget to view its layout.',
        textAlign: TextAlign.center,
        overflow: TextOverflow.clip,
      ),
    );
  }

  void onSelectionChanged() {
    if (rootWidget(previousSelection).runtimeType !=
        rootWidget(selected).runtimeType) {
      setState(() => previousSelection = selected);
    }
  }

  @override
  void initState() {
    super.initState();
    addAutoDisposeListener(controller!.selectedNode, onSelectionChanged);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return rootWidget(selected);
  }

  @override
  bool get wantKeepAlive => true;
}
