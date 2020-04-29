// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart' hide TextStyle;
import 'package:flutter/rendering.dart' hide TextStyle;
import 'package:flutter/widgets.dart' hide TextStyle;
import 'package:intl/intl.dart';

import 'memory_graph_model.dart';

class FlameChart extends StatelessWidget {
  const FlameChart(
    this.sizes, {
    // Flame chart has a blueish color.
    this.lightColor = const Color(0xFFBBDEFB),
    this.darkColor = const Color(0xFF0D47A1),
  });

  final InstructionsSize sizes;
  final Color lightColor;
  final Color darkColor;

  @override
  Widget build(BuildContext context) {
    return _FlameChart(sizes, lightColor, darkColor);
  }
}

class _FlameChart extends LeafRenderObjectWidget {
  const _FlameChart(this.sizes, this.lightColor, this.darkColor);

  final InstructionsSize sizes;
  final Color lightColor;
  final Color darkColor;

  @override
  FlameChartRenderObject createRenderObject(BuildContext context) {
    return FlameChartRenderObject()
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
  set sizes(InstructionsSize value) {
    if (value == _sizes) {
      return;
    }
    _sizes = value;
    _selectedNode = value.root;
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

  /// Look for the node with a particular name (depth first traversal).
  Node findNode(Map<String, Node> children, String searchName) {
    for (var child in children.entries) {
      final node = child.value;
      if (node.children.isEmpty) {
        return node.name == searchName ? node : null;
      } else {
        if (node.name == searchName) return node;
        final foundNode = findNode(node.children, searchName);
        if (foundNode != null) return foundNode;
      }
    }

    return null;
  }

  Node _selectedNode;
  set selectedNode(Node value) {
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
    // TODO(terry): Not enabled for testing search.
    Node foundNode;
    if (searchString != null) {
      foundNode = findNode(_sizes.root.children, searchString);
    }

    if (foundNode == null) {
      final node = _selectedNode.findRect(position);
      if (node != null) {
        selectedNode = node;
      }
    } else {
      // Found the node select it.
      selectedNode = foundNode;
    }

    return super.hitTest(result, position: position);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final rootWidth = size.width;
    final top = _paintAncestors(context, _selectedNode.ancestors);

    _paintNode(context, _selectedNode, 0, rootWidth, top);

    _paintChildren(
      context: context,
      currentLeft: 1,
      parentSize: _selectedNode.byteSize,
      children: _selectedNode.children.values,
      topFactor: top + 51,
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
    node.rect = Rect.fromLTWH(left, size.height - top, width, 50);
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
    double top = 50;
    for (var node in nodes.reversed) {
      _paintNode(context, node, 0, size.width, top);
      top += 50;
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
            topFactor: topFactor + 51,
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

  factory InstructionsSize.fromSnapshop(HeapGraph graph) {
    final Map<String, Node> rootChildren = <String, Node>{};
    final Node root = Node(
      'root',
      children: rootChildren,
    );
    Node currentParent = root;

    // TODO(terry): Should heat map be all memory or just the filtered group?
    //              Using rawGroup not graph.groupByLibrary.
    graph.rawGroupByLibrary.forEach(
      (libraryGroup, value) {
        final List<HeapGraphClassActual> classes = value;
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
          final predefined = predefinedClasses['$libraryName,$className'];
          if (predefined != null) {
            className = predefined.prettyName;
          }

          // TODO(terry): Remove testing really big objects.
//          if (className.startsWith('Terry')) shallowSize *= 100000;
//          print('l=$libraryName, c=$className, n=new $className, s=$shallowSize');

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

    final snapshotGraph = heapGraph.controller.snapshots.last.snapshotGraph;

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

class HeatMapSizeAnalyzer extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      color: Colors.blueGrey,
      home: FlameChart(InstructionsSize.fromSnapshop(heapGraph)),
      debugShowCheckedModeBanner: false,
    );

    // TODO(terry): Testing search needs to be stateful.
    /*
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            const SizedBox(width: 16.0),
            Container(
              width: 200.0,
              height: 36.0,
              child: TextField(
                onEditingComplete: () {
                  print('Searching for $searchString');
                },
                onChanged: (value) {
                  searchString = value;
                },
                controller: TextEditingController(),
                decoration: const InputDecoration(
                  isDense: true,
                  border: OutlineInputBorder(),
                  labelText: 'Search',
                ),
              ),
            ),
          ],
        ),
        Expanded(
          child: MaterialApp(
            color: Colors.blueGrey,
            home: FlameChart(InstructionsSize.fromSnapshop(heapGraph)),
          ),
        ),
      ],
    );
    */
  }
}

HeapGraph heapGraph;
String searchString;
