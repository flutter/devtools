// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart' hide TextStyle;
import 'package:flutter/widgets.dart' hide TextStyle;
import 'package:provider/provider.dart';

import '../auto_dispose_mixin.dart';
import '../charts/treemap.dart';

import 'memory_controller.dart';
import 'memory_graph_model.dart';
import 'memory_utils.dart';

class MemoryTreemap extends StatefulWidget {
  const MemoryTreemap(this.controller);

  final MemoryController controller;

  @override
  MemoryTreemapState createState() => MemoryTreemapState(controller);
}

class MemoryTreemapState extends State<MemoryTreemap> with AutoDisposeMixin {
  MemoryTreemapState(this.controller);

  InstructionsSize sizes;

  Map<String, Function> callbacks = {};

  MemoryController controller;

  Widget snapshotDisplay;

  TreemapNode root;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // TODO(terry): Unable to short-circuit need to investigate why?
    controller = Provider.of<MemoryController>(context);

    sizes = InstructionsSize.fromSnapshot(controller);

    root = sizes.root;

    cancel();

    addAutoDisposeListener(controller.selectedSnapshotNotifier, () {
      setState(() {
        controller.computeAllLibraries(true, true);

        sizes = InstructionsSize.fromSnapshot(controller);
      });
    });

    addAutoDisposeListener(controller.filterNotifier, () {
      setState(() {
        controller.computeAllLibraries(true, true);
      });
    });
    // TODO(peterdjlee): Need to check if applicable to treemap.
    // addAutoDisposeListener(controller.selectTheSearchNotifier, () {
    //   setState(() {
    //     if (_trySelectItem()) {
    //       closeAutoCompleteOverlay();
    //     }
    //   });
    // });

    // addAutoDisposeListener(controller.searchNotifier, () {
    //   setState(() {
    //     if (_trySelectItem()) {
    //       closeAutoCompleteOverlay();
    //     }
    //   });
    // });

    addAutoDisposeListener(controller.searchAutoCompleteNotifier, () {
      setState(autoCompleteOverlaySetState(controller, context));
    });
  }

  void _onRootChanged(TreemapNode newRoot) {
    setState(() {
      root = newRoot;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (sizes != null) {
      return LayoutBuilder(
        builder: (context, constraints) {
          return NewTreemap.fromRoot(
              rootNode: root,
              levelsVisible: 3,
              onRootChangedCallback: _onRootChanged);
        },
      );
    } else {
      return const SizedBox();
    }
  }
}

/// Definitions of exposed callback methods stored in callback Map the key
/// is the function name (String) and the value a callback function signature.

/// matchNames callback name.
const matchNamesKey = 'matchNames';

/// matchNames callback signature.
typedef MatchNamesFunction = List<String> Function(String);

/// findNode callback name.
const findNodeKey = 'findNode';

/// findNode callback signature.
typedef FindNodeFunction = TreemapNode Function(String);

/// selectNode callback name.
const selectNodeKey = 'selectNode';

/// selectNode callback signature.
typedef SelectNodeFunction = void Function(TreemapNode);
