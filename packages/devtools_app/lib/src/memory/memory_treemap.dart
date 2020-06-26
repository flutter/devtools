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
        controller.computeAllLibraries(rebuild: true);

        sizes = InstructionsSize.fromSnapshot(controller);
      });
    });

    // TODO(peterdjlee): Implement search and filter functionality for memory treemap.
    // addAutoDisposeListener(controller.filterNotifier, () {
    //   setState(() {
    //     controller.computeAllLibraries(rebuild: true);
    //   });
    // });
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

    // addAutoDisposeListener(controller.searchAutoCompleteNotifier, () {
    //   setState(autoCompleteOverlaySetState(controller, context));
    // });
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
          return Treemap.fromRoot(
            rootNode: root,
            levelsVisible: 2,
            isOutermostLevel: true,
            height: constraints.maxHeight,
            onRootChangedCallback: _onRootChanged,
          );
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

class InstructionsSize {
  const InstructionsSize(this.root);

  factory InstructionsSize.fromSnapshot(MemoryController controller) {
    final rootChildren = <String, TreemapNode>{};
    final root = TreemapNode(
      name: 'root',
      childrenMap: rootChildren,
    );
    TreemapNode currentParent = root;

    // TODO(terry): Should treemap be all memory or just the filtered group?
    //              Using rawGroup not graph.groupByLibrary.

    controller.heapGraph.rawGroupByLibrary.forEach(
      (libraryGroup, value) {
        final classes = value;
        for (final theClass in classes) {
          final shallowSize = theClass.instancesTotalShallowSizes;
          var className = theClass.name;
          if (shallowSize == 0 ||
              libraryGroup == null ||
              className == null ||
              className == '::') {
            continue;
          }

          // Ensure the empty library name is our group name e.g., '' -> 'src'.
          String libraryName = theClass.libraryUri.toString();
          if (libraryName.isEmpty) {
            libraryName = libraryGroup;
          }

          // Map class names to familar user names.
          final predefined =
              predefinedClasses[LibraryClass(libraryName, className)];
          if (predefined != null) {
            className = predefined.prettyName;
          }

          final symbol = Symbol(
            name: 'new $className',
            size: shallowSize,
            libraryUri: libraryName,
            className: className,
          );

          Map<String, TreemapNode> currentChildren = rootChildren;
          final parentReset = currentParent;
          for (String pathPart in symbol.parts) {
            currentChildren.putIfAbsent(
              pathPart,
              () {
                final node = TreemapNode(
                  name: pathPart,
                  childrenMap: <String, TreemapNode>{},
                );
                currentParent.addChild(node);
                return node;
              },
            );
            currentChildren[pathPart].byteSize += symbol.size;
            currentParent = currentChildren[pathPart];
            currentChildren = currentChildren[pathPart].childrenMap;
          }
          currentParent = parentReset;
        }
      },
    );

    // Get sum of children's sizes.
    root.byteSize = root.childrenMap.values
        .fold(0, (int current, TreemapNode node) => current + node.byteSize);

    final snapshotGraph = controller.snapshots.last.snapshotGraph;
    // Add the external heap to the treemap.
    root.childrenMap.putIfAbsent('External Heap', () {
      final node = TreemapNode(
        name: 'External Heap',
        childrenMap: <String, TreemapNode>{},
      )..byteSize = snapshotGraph.externalSize;
      root.addChild(node);
      return node;
    });

    // TODO(peterdjlee): Add the filtered libraries/classes to the treemap.

    root.byteSize = snapshotGraph.shallowSize + snapshotGraph.externalSize;

    return InstructionsSize(root);
  }

  final TreemapNode root;
}

class Symbol {
  const Symbol({
    @required this.name,
    @required this.size,
    this.libraryUri,
    this.className,
  })  : assert(name != null),
        assert(size != null);

  static Symbol fromMap(Map<String, dynamic> json) {
    return Symbol(
      name: json['n'] as String,
      size: json['s'] as int,
      className: json['c'] as String,
      libraryUri: json['l'] as String,
    );
  }

  final String name;
  final int size;
  final String libraryUri;
  final String className;

  List<String> get parts {
    return <String>[
      if (libraryUri != null) ...libraryUri.split('/') else '@stubs',
      if (className != null && className.isNotEmpty) className,
      name,
    ];
  }
}
