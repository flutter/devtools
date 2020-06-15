// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:math' as math;
import 'dart:math';
import 'dart:ui';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart' hide TextStyle;
import 'package:flutter/rendering.dart' hide TextStyle;
import 'package:flutter/widgets.dart' hide TextStyle;
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../auto_dispose_mixin.dart';
import '../ui/colors.dart';

import 'memory_controller.dart';
import 'memory_graph_model.dart';
import 'memory_utils.dart';

/// UX navigation in a heat map e.g.,
///     ------------------------------------------------------------
///     | ||| || |||| |       | new String | | || Foundation (38M) |
///     ------------------------------------------------------------
///     || |  |     | |  List | String | |  ||      src (42M)      |
///     ------------------------------------------------------------
///     | src (36.4M) |    dart:core (58M)   |package:flutter (42M)|
///     ------------------------------------------------------------
///     |                       Root (136M)                        |
///     ------------------------------------------------------------
/// Mouse action (click or mouse scroll wheel) over a rectangle for example
/// package:flutter will to expand its contained children to more rectangles
/// upwards. The sizes of the contained children (if an aggregated parent).
/// Mouse action over, upward, children will further expand its children in
/// a upward fashion too. To collapse a rectangle move the mouse below a child
/// rectangle (its parent) and click or mouse scroll.
class HeatMapSizeAnalyzer extends SingleChildRenderObjectWidget {
  const HeatMapSizeAnalyzer({
    Key key,
    Widget child,
  }) : super(key: key, child: child);

  @override
  RenderFlameChart createRenderObject(BuildContext context) {
    return RenderFlameChart();
  }
}

class RenderFlameChart extends RenderProxyBox {
  @override
  void paint(PaintingContext context, Offset offset) {
    if (child != null) {
      context.paintChild(child, offset);
    }
  }
}

class FlameChart extends StatefulWidget {
  const FlameChart(
    this.controller,
  );

  final MemoryController controller;

  @override
  FlameChartState createState() => FlameChartState(controller);
}

class FlameChartState extends State<FlameChart> with AutoDisposeMixin {
  FlameChartState(this.controller);

  InstructionsSize sizes;

  Map<String, Function> callbacks = {};

  MemoryController controller;

  Widget snapshotDisplay;

  _FlameChart _flameChart;

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // TODO(terry): Unable to short-circuit need to investigate why?
    controller = Provider.of<MemoryController>(context);

    cancel();

    addAutoDisposeListener(controller.selectedSnapshotNotifier, () {
      setState(() {
        controller.computeAllLibraries(true, true);

        sizes = InstructionsSize.fromSnapshop(controller);
      });
    });

    addAutoDisposeListener(controller.filterNotifier, () {
      setState(() {
        controller.computeAllLibraries(true, true);
      });
    });

    addAutoDisposeListener(controller.selectTheSearchNotifier, () {
      setState(() {
        if (_trySelectItem()) {
          closeAutoCompleteOverlay();
        }
      });
    });

    addAutoDisposeListener(controller.searchNotifier, () {
      setState(() {
        if (_trySelectItem()) {
          closeAutoCompleteOverlay();
        }
      });
    });

    addAutoDisposeListener(controller.searchAutoCompleteNotifier, () {
      setState(autoCompleteOverlaySetState(controller, context));
    });
  }

  /// Returns true if node found and node selected.
  bool _trySelectItem() {
    if (controller.search.isNotEmpty) {
      if (controller.selectTheSearch) {
        // Select the node.
        final node = findNode(controller.search);
        selectNode(node);

        closeAutoCompleteOverlay();

        controller.selectTheSearch = false;
        controller.search = '';
        return true;
      } else {
        var matches = matchNames(controller.search)..sort();
        // No exact match, return top matches.
        matches = matches.sublist(0, min(topMatchesLimit, matches.length));
        controller.searchAutoComplete.value = matches;
      }
    } else if (controller.selectTheSearch) {
      // Escape hit, on empty search.
      selectNode(null);
      controller.selectTheSearch = false;
    }

    return false;
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    sizes = InstructionsSize.fromSnapshop(controller);

    if (sizes != null) {
      _flameChart = _FlameChart(
        sizes,
        // TODO(terry): Can the color range match flame chart? Review with UX.
        memoryHeatMapLightColor,
        memoryHeatMapDarkColor,
        callbacks,
      );
      return _flameChart;
    } else {
      return const SizedBox();
    }
  }

  List<String> matchNames(String searchValue) {
    final MatchNamesFunction callback = _flameChart.callbacks[matchNamesKey];
    return callback(searchValue);
  }

  Node findNode(String searchValue) {
    final FindNodeFunction callback = _flameChart.callbacks[findNodeKey];
    return callback(searchValue);
  }

  void selectNode(Node nodeValue) {
    final SelectNodeFunction callback = _flameChart.callbacks[selectNodeKey];
    callback(nodeValue);
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
typedef FindNodeFunction = Node Function(String);

/// selectNode callback name.
const selectNodeKey = 'selectNode';

/// selectNode callback signature.
typedef SelectNodeFunction = void Function(Node);

class _FlameChart extends LeafRenderObjectWidget {
  const _FlameChart(
      this.sizes, this.lightColor, this.darkColor, this.callbacks);

  final InstructionsSize sizes;

  final Color lightColor;

  final Color darkColor;

  final Map<String, Function> callbacks;

  @override
  FlameChartRenderObject createRenderObject(BuildContext context) {
    return FlameChartRenderObject()
      // callbacks must be before sizes as hookup is done in sizes setter.
      ..callbacks = callbacks
      ..sizes = sizes
      ..lightColor = lightColor
      ..darkColor = darkColor;
  }

  @override
  void updateRenderObject(
    BuildContext context,
    FlameChartRenderObject renderObject,
  ) {
    renderObject
      ..sizes = sizes
      ..lightColor = lightColor
      ..darkColor = darkColor;
  }
}

class FlameChartRenderObject extends RenderBox {
  FlameChartRenderObject();

  InstructionsSize _sizes;

  Offset paintOffset;

  Map<String, Function> callbacks;

  set sizes(InstructionsSize value) {
    callbacks[matchNamesKey] = _exposeMatchNames;
    callbacks[findNodeKey] = _exposeFindNode;
    callbacks[selectNodeKey] = _exposeSelectNode;

    if (value == _sizes) {
      return;
    }
    _sizes = value;
    _selectedNode ??= value.root;
    markNeedsPaint();
  }

  Color _lightColor;

  set lightColor(Color value) {
    if (value == _lightColor) {
      return;
    }
    _lightColor = value;
    markNeedsPaint();
  }

  Color _darkColor;

  set darkColor(Color value) {
    if (value == _lightColor) {
      return;
    }
    _darkColor = value;
    markNeedsPaint();
  }

  List<String> _exposeMatchNames(String searchName) {
    return matchNodeNames(_sizes.root.children, searchName);
  }

  /// Look for the node with a particular name (depth first traversal).
  List<String> matchNodeNames(Map<String, Node> children, String searchName) {
    final matches = <String>[];
    final matchName = searchName.toLowerCase();
    for (var child in children.entries) {
      final node = child.value;

      final lcNodeName = node.name.toLowerCase();
      if (!lcNodeName.endsWith('.dart') && lcNodeName.startsWith(matchName)) {
        matches.add(node.name);
      }
      if (node.children.isNotEmpty) {
        final childMatches = matchNodeNames(node.children, searchName);
        if (childMatches.isNotEmpty) {
          matches.addAll(childMatches);
        }
      }
    }

    return matches;
  }

  Node _exposeFindNode(String searchName) {
    return findNode(_sizes.root.children, searchName);
  }

  /// Look for the node with a particular name (depth first traversal).
  Node findNode(Map<String, Node> children, String searchName) {
    final matchName = searchName.toLowerCase();
    for (var child in children.entries) {
      final node = child.value;
      if (node.children.isEmpty) {
        return node.name.toLowerCase() == matchName ? node : null;
      } else {
        if (node.name.toLowerCase() == matchName) return node;
        final foundNode = findNode(node.children, matchName);
        if (foundNode != null) return foundNode;
      }
    }

    return null;
  }

  void _exposeSelectNode(Node value) {
    selectedNode = value;
  }

  Node _selectedNode;

  set selectedNode(Node value) {
    value ??= _sizes.root;
    if (value == _selectedNode) {
      return;
    }
    _selectedNode = value;

    markNeedsPaint();
  }

  @override
  bool get sizedByParent => true;

  @override
  bool hitTest(BoxHitTestResult result, {Offset position}) {
    final computedPosition =
        Offset(position.dx + paintOffset.dx, position.dy + paintOffset.dy);

    final node = _selectedNode.findRect(computedPosition);
    if (node != null) {
      selectedNode = node;
    }

    return super.hitTest(result, position: position);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    paintOffset = offset;

    final rootWidth = size.width;
    final top = _paintAncestors(context, _selectedNode.ancestors);

    _paintNode(
        context, _selectedNode, 0 + paintOffset.dx, rootWidth, top - offset.dy);

    _paintChildren(
      context: context,
      currentLeft: 1 + offset.dx,
      parentSize: _selectedNode.byteSize,
      children: _selectedNode.children.values,
      topFactor: top + Node.nodeHeight + 1 - offset.dy,
      maxWidth: rootWidth - 1,
    );
  }

  final _logs = <int, double>{};
  final _inverseColors = <Color, Color>{};

  void _paintNode(
    PaintingContext context,
    Node node,
    double left,
    double width,
    double top,
  ) {
    node.rect = Rect.fromLTWH(left, size.height - top, width, Node.nodeHeight);
    final double t =
        _logs.putIfAbsent(node.byteSize, () => math.log(node.byteSize)) /
            _logs.putIfAbsent(
                _sizes.root.byteSize, () => math.log(_sizes.root.byteSize));
    final Color backgroundColor = Color.lerp(
      _lightColor,
      _darkColor,
      t,
    );

    context.canvas.drawRRect(
      RRect.fromRectAndRadius(node.rect, const Radius.circular(2.0)),
      Paint()..color = backgroundColor,
    );
    // Don't bother figuring out the text length if the box is too small.
    if (width < 100) {
      return;
    }

    final formattedByteSize = NumberFormat.compact().format(node.byteSize);

    final builder = ParagraphBuilder(
      ParagraphStyle(
        textAlign: TextAlign.center,
        maxLines: 2,
        ellipsis: '...',
      ),
    )
      ..pushStyle(
        TextStyle(
          color: _inverseColors.putIfAbsent(backgroundColor, () {
            return HSLColor.fromColor(backgroundColor).lightness > .7
                ? const Color(0xFF000000)
                : const Color(0xFFFFFFFF);
          }),
          fontFamily: 'Courier New',
        ),
      )
      ..addText('${node.name}\n($formattedByteSize)');
    final Paragraph paragraph = builder.build()
      ..layout(ParagraphConstraints(width: width - 5));
    context.canvas.drawParagraph(
      paragraph,
      Offset(10 + left, size.height - top + 10),
    );
  }

  double _paintAncestors(PaintingContext context, List<Node> nodes) {
    double top = Node.nodeHeight;
    for (var node in nodes.reversed) {
      _paintNode(
          context, node, 0 + paintOffset.dx, size.width, top - paintOffset.dy);
      top += Node.nodeHeight;
    }
    return top;
  }

  void _paintChildren({
    PaintingContext context,
    double currentLeft,
    int parentSize,
    Iterable<Node> children,
    double topFactor,
    double maxWidth,
  }) {
    double left = currentLeft;

    for (var child in children) {
      final double width = child.byteSize / parentSize * maxWidth;
      _paintNode(context, child, left, width, topFactor);

      if (!child.isLeaf) {
        final double factor = math.max(
          0.0001,
          math.min(
            math.log(maxWidth * .01),
            math.log(width * .1),
          ),
        );
        // Very minor chunk of memory, just skip display for now.  Smaller than 1 pixel in width.
        if (factor < width) {
          _paintChildren(
            context: context,
            currentLeft: left + factor,
            parentSize: child.byteSize,
            children: child.children.values,
            topFactor: topFactor + Node.nodeHeight + 1,
            maxWidth: width - (2 * factor),
          );
        }
      }
      left += width;
    }
  }
}

class InstructionsSize {
  const InstructionsSize(this.root);

  factory InstructionsSize.fromSnapshop(MemoryController controller) {
    final Map<String, Node> rootChildren = <String, Node>{};
    final Node root = Node(
      'root',
      children: rootChildren,
    );
    Node currentParent = root;

    // TODO(terry): Should heat map be all memory or just the filtered group?
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

          Map<String, Node> currentChildren = rootChildren;
          final Node parentReset = currentParent;
          for (String pathPart in symbol.parts) {
            currentChildren.putIfAbsent(
              pathPart,
              () => Node(pathPart,
                  parent: currentParent, children: <String, Node>{}),
            );
            currentChildren[pathPart].byteSize += symbol.size;
            currentParent = currentChildren[pathPart];
            currentChildren = currentChildren[pathPart].children;
          }
          currentParent = parentReset;
        }
      },
    );

    root.byteSize = root.children.values
        .fold(0, (int current, Node node) => current + node.byteSize);

    final snapshotGraph = controller.snapshots.last.snapshotGraph;

    // Add the external heap to the heat map.
    root.children.putIfAbsent('External Heap', () {
      final node = Node(
        'External Heap',
        parent: root,
        children: <String, Node>{},
      );
      node.byteSize = snapshotGraph.externalSize;
      return node;
    });

    // Add the filtered libraries/classes to the heat map.
    root.children.putIfAbsent('All Filtered Libraries', () {
      final node = Node(
        'All Filtered Libraries',
        parent: root,
        children: <String, Node>{},
      );
      node.byteSize = snapshotGraph.shallowSize - root.byteSize;
      return node;
    });

    root.byteSize = snapshotGraph.shallowSize + snapshotGraph.externalSize;

    return InstructionsSize(root);
  }

  final Node root;
}

class Node {
  Node(
    this.name, {
    this.byteSize = 0,
    this.parent,
    this.children = const <String, Node>{},
  })  : assert(name != null),
        assert(byteSize != null),
        assert(children != null);

  static const double nodeHeight = 50.0;

  final String name;
  int byteSize;
  Rect rect = Rect.zero;
  final Node parent;
  final Map<String, Node> children;

  Iterable<Node> get ancestors {
    final nodes = <Node>[];
    Node current = this;
    while (current.parent != null) {
      nodes.add(current.parent);
      current = current.parent;
    }
    return nodes;
  }

  bool get isLeaf => children.isEmpty;

  Node findRect(Offset offset) {
    if (rect.contains(offset)) {
      return this;
    }
    for (var ancestor in ancestors) {
      if (ancestor.rect.contains(offset)) {
        return ancestor;
      }
    }
    for (var child in children.values) {
      final value = child.findRect(offset);
      if (value != null) {
        return value;
      }
    }
    return null;
  }

  @override
  String toString() => 'Node($name, $byteSize, $rect)';
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