// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';

import '../common_widgets.dart';
import '../trees.dart';
import '../ui/colors.dart';
import '../utils.dart';

enum PivotType { pivotByMiddle, pivotBySize }

class Treemap extends StatelessWidget {
  // TODO(peterdjlee): Consider auto-expanding rootNode named 'src'.
  const Treemap.fromRoot({
    @required this.rootNode,
    this.nodes,
    @required this.levelsVisible,
    this.isOutermostLevel = false,
    @required this.width,
    @required this.height,
    @required this.onRootChangedCallback,
  });

  const Treemap.fromNodes({
    this.rootNode,
    @required this.nodes,
    @required this.levelsVisible,
    this.isOutermostLevel = false,
    @required this.width,
    @required this.height,
    @required this.onRootChangedCallback,
  });

  final TreemapNode rootNode;

  final List<TreemapNode> nodes;

  /// The depth of children visible from this Treemap widget.
  ///
  /// A decremented level should be passed in when constructing [Treemap.fromRoot],
  /// but not when constructing [Treemap.fromNodes]. This is because
  /// when constructing from a root, [Treemap] either builds a nested [Treemap] to
  /// show its node's children, or it shows its node. When constructing from a list
  /// of nodes, however, [Treemap] is built to become part of a bigger treemap,
  /// which means the level should not change.
  ///
  /// For example, levelsVisible = 2:
  /// ```
  /// _______________
  /// |     Root    |
  /// ---------------
  /// |      1      |
  /// |  ---------  |
  /// |  |   2   |  |
  /// |  |       |  |
  /// |  |       |  |
  /// |  ---------  |
  /// ---------------
  /// ```
  final int levelsVisible;

  /// Whether current levelsVisible matches the outermost level.
  final bool isOutermostLevel;

  final double width;

  final double height;

  final void Function(TreemapNode node) onRootChangedCallback;

  static const PivotType pivotType = PivotType.pivotBySize;

  static const treeMapHeaderHeight = 20.0;

  static const minHeightToDisplayTitleText = 100.0;

  static const minWidthToDisplayCellText = 40.0;
  static const minHeightToDisplayCellText = 50.0;

  /// Computes the total size of a given list of treemap nodes.
  /// [endIndex] defaults to nodes.length - 1.
  int computeByteSizeForNodes({
    @required List<TreemapNode> nodes,
    int startIndex = 0,
    int endIndex,
  }) {
    endIndex ??= nodes.length - 1;
    int sum = 0;
    for (int i = startIndex; i <= endIndex; i++) {
      sum += nodes[i].unsignedByteSize ?? 0;
    }
    return sum;
  }

  int computePivot(List<TreemapNode> children) {
    switch (pivotType) {
      case PivotType.pivotByMiddle:
        return (children.length / 2).floor();
      case PivotType.pivotBySize:
        int pivotIndex = -1;
        double maxSize = double.negativeInfinity;
        for (int i = 0; i < children.length; i++) {
          if (children[i].unsignedByteSize > maxSize) {
            maxSize = children[i].unsignedByteSize.toDouble();
            pivotIndex = i;
          }
        }
        return pivotIndex;
      default:
        return -1;
    }
  }

  /// Implements the ordered treemap algorithm studied in [this research paper](https://www.cs.umd.edu/~ben/papers/Shneiderman2001Ordered.pdf).
  ///
  /// **Algorithm**
  ///
  /// Divides a given list of treemap nodes into four parts:
  /// L1, P, L2, L3.
  ///
  /// P (pivot) is the treemap node chosen to be the pivot based on the pivot type.
  /// L1 includes all treemap nodes before the pivot treemap node.
  /// L2 and L3 combined include all treemap nodes after the pivot treemap node.
  /// A combination of elements are put into L2 and L3 so that
  /// the aspect ratio of the pivot cell (P) is as close to 1 as it can be.
  ///
  /// **Layout**
  /// ```
  /// ----------------------
  /// |      |  P   |      |
  /// |      |      |      |
  /// |  L1  |------|  L3  |
  /// |      |  L2  |      |
  /// |      |      |      |
  /// ----------------------
  /// ```
  List<PositionedCell> buildTreemaps({
    @required List<TreemapNode> children,
    @required double x,
    @required double y,
    @required double width,
    @required double height,
  }) {
    final isHorizontalRectangle = width > height;

    final totalByteSize = computeByteSizeForNodes(nodes: children);
    if (children.isEmpty) {
      return [];
    }

    // Sort the list of treemap nodes, descending in size.
    children.sort((a, b) => b.unsignedByteSize.compareTo(a.unsignedByteSize));
    if (children.length <= 2) {
      final positionedChildren = <PositionedCell>[];
      double offset = 0;

      for (final child in children) {
        final ratio = child.unsignedByteSize / totalByteSize;
        final newWidth = isHorizontalRectangle ? ratio * width : width;
        final newHeight = isHorizontalRectangle ? height : ratio * height;
        positionedChildren.add(
          PositionedCell(
            left: isHorizontalRectangle ? x + offset : x,
            top: isHorizontalRectangle ? y : y + offset,
            width: newWidth,
            height: newHeight,
            node: child,
            child: Treemap.fromRoot(
              rootNode: child,
              levelsVisible: levelsVisible - 1,
              onRootChangedCallback: onRootChangedCallback,
              width: newWidth,
              height: newHeight,
            ),
          ),
        );
        offset += isHorizontalRectangle ? ratio * width : ratio * height;
      }

      return positionedChildren;
    }

    final pivotIndex = computePivot(children);

    final pivotNode = children[pivotIndex];
    final pivotByteSize = pivotNode.unsignedByteSize;

    final list1 = children.sublist(0, pivotIndex);
    final list1ByteSize = computeByteSizeForNodes(nodes: list1);

    var list2 = <TreemapNode>[];
    int list2ByteSize = 0;
    var list3 = <TreemapNode>[];
    int list3ByteSize = 0;

    // The maximum amount of data we can put in [list3].
    final l3MaxLength = children.length - pivotIndex - 1;
    int bestIndex = 0;
    double pivotBestWidth = 0;
    double pivotBestHeight = 0;

    // We need to be able to put at least 3 elements in [list3] for this algorithm.
    if (l3MaxLength >= 3) {
      double pivotBestAspectRatio = double.infinity;
      // Iterate through different combinations of [list2] and [list3] to find
      // the combination where the aspect ratio of pivot is the lowest.
      for (int i = pivotIndex + 1; i < children.length; i++) {
        final list2Size = computeByteSizeForNodes(
          nodes: children,
          startIndex: pivotIndex + 1,
          endIndex: i,
        );

        // Calculate the aspect ratio for the pivot treemap node.
        final pivotAndList2Ratio = (pivotByteSize + list2Size) / totalByteSize;
        final pivotRatio = pivotByteSize / (pivotByteSize + list2Size);

        final pivotWidth = isHorizontalRectangle
            ? pivotAndList2Ratio * width
            : pivotRatio * width;

        final pivotHeight = isHorizontalRectangle
            ? pivotRatio * height
            : pivotAndList2Ratio * height;

        final pivotAspectRatio = pivotWidth / pivotHeight;

        // Best aspect ratio that is the closest to 1.
        if ((1 - pivotAspectRatio).abs() < (1 - pivotBestAspectRatio).abs()) {
          pivotBestAspectRatio = pivotAspectRatio;
          bestIndex = i;
          // Kept track of width and height to construct the pivot cell.
          pivotBestWidth = pivotWidth;
          pivotBestHeight = pivotHeight;
        }
      }
      // Split the rest of the data into [list2] and [list3].
      list2 = children.sublist(pivotIndex + 1, bestIndex + 1);
      list2ByteSize = computeByteSizeForNodes(nodes: list2);

      list3 = children.sublist(bestIndex + 1);
      list3ByteSize = computeByteSizeForNodes(nodes: list3);
    } else {
      // Put all data in [list2] and none in [list3].
      list2 = children.sublist(pivotIndex + 1);
      list2ByteSize = computeByteSizeForNodes(nodes: list2);

      final pivotAndList2Ratio =
          (pivotByteSize + list2ByteSize) / totalByteSize;
      final pivotRatio = pivotByteSize / (pivotByteSize + list2ByteSize);
      pivotBestWidth = isHorizontalRectangle
          ? pivotAndList2Ratio * width
          : pivotRatio * width;
      pivotBestHeight = isHorizontalRectangle
          ? pivotRatio * height
          : pivotAndList2Ratio * height;
    }

    final positionedTreemaps = <PositionedCell>[];

    // Contruct list 1 sub-treemap.
    final list1SizeRatio = list1ByteSize / totalByteSize;
    final list1Width = isHorizontalRectangle ? width * list1SizeRatio : width;
    final list1Height =
        isHorizontalRectangle ? height : height * list1SizeRatio;
    if (list1.isNotEmpty) {
      positionedTreemaps.addAll(buildTreemaps(
        children: list1,
        x: x,
        y: y,
        width: list1Width,
        height: list1Height,
      ));
    }

    // Construct list 2 sub-treemap.
    final list2Width =
        isHorizontalRectangle ? pivotBestWidth : width - pivotBestWidth;
    final list2Height =
        isHorizontalRectangle ? height - pivotBestHeight : pivotBestHeight;
    final list2XCoord = isHorizontalRectangle ? list1Width : 0.0;
    final list2YCoord = isHorizontalRectangle ? pivotBestHeight : list1Height;
    if (list2.isNotEmpty) {
      positionedTreemaps.addAll(buildTreemaps(
        children: list2,
        x: x + list2XCoord,
        y: y + list2YCoord,
        width: list2Width,
        height: list2Height,
      ));
    }

    // Construct pivot cell.
    final pivotXCoord = isHorizontalRectangle ? list1Width : list2Width;
    final pivotYCoord = isHorizontalRectangle ? 0.0 : list1Height;

    positionedTreemaps.add(
      PositionedCell(
        left: x + pivotXCoord,
        top: y + pivotYCoord,
        width: pivotBestWidth,
        height: pivotBestHeight,
        node: pivotNode,
        child: Treemap.fromRoot(
          rootNode: pivotNode,
          levelsVisible: levelsVisible - 1,
          onRootChangedCallback: onRootChangedCallback,
          width: width,
          height: height,
        ),
      ),
    );

    // Construct list 3 sub-treemap.
    final list3Ratio = list3ByteSize / totalByteSize;
    final list3Width = isHorizontalRectangle ? list3Ratio * width : width;
    final list3Height = isHorizontalRectangle ? height : list3Ratio * height;
    final list3XCoord =
        isHorizontalRectangle ? list1Width + pivotBestWidth : 0.0;
    final list3YCoord =
        isHorizontalRectangle ? 0.0 : list1Height + pivotBestHeight;

    if (list3.isNotEmpty) {
      positionedTreemaps.addAll(buildTreemaps(
        children: list3,
        x: x + list3XCoord,
        y: y + list3YCoord,
        width: list3Width,
        height: list3Height,
      ));
    }

    return positionedTreemaps;
  }

  @override
  Widget build(BuildContext context) {
    if (rootNode == null && nodes.isNotEmpty) {
      return buildSubTreemaps();
    } else {
      return buildTreemap(context);
    }
  }

  /// **Treemap widget layout**
  /// ```
  /// ----------------------------
  /// |        Title Text        |
  /// |--------------------------|
  /// |                          |
  /// |           Cell           |
  /// |                          |
  /// |                          |
  /// ----------------------------
  /// ```
  Widget buildTreemap(BuildContext context) {
    if (rootNode.children.isNotEmpty) {
      final treemapFromNodes = buildTreemapFromNodes(context);
      return Padding(
        padding: const EdgeInsets.all(1.0),
        child: isOutermostLevel
            ? treemapFromNodes
            : buildSelectable(child: treemapFromNodes),
      );
    } else {
      return Column(
        children: [
          Expanded(
            child: buildSelectable(
              child: Container(
                decoration: BoxDecoration(
                  color: rootNode.displayColor,
                  border: Border.all(color: Colors.black87),
                ),
                child: Center(
                  child: height > minHeightToDisplayCellText
                      ? buildNameAndSizeText(
                          textColor:
                              rootNode.showDiff ? Colors.white : Colors.black,
                          oneLine: false,
                        )
                      : const SizedBox(),
                ),
              ),
            ),
          ),
        ],
      );
    }
  }

  Widget buildTreemapFromNodes(BuildContext context) {
    return Column(
      children: [
        if (height > minHeightToDisplayTitleText) buildTitleText(context),
        Expanded(
          child: Treemap.fromNodes(
            nodes: rootNode.children,
            levelsVisible: levelsVisible,
            onRootChangedCallback: onRootChangedCallback,
            width: width,
            height: height,
          ),
        ),
      ],
    );
  }

  Widget buildTitleText(BuildContext context) {
    if (isOutermostLevel) {
      return buildBreadcrumbsNavigator();
    } else {
      return Container(
        height: treeMapHeaderHeight,
        width: double.infinity,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.black87),
        ),
        child: buildNameAndSizeText(
          textColor: Theme.of(context).textTheme.bodyText2.color,
          oneLine: true,
        ),
      );
    }
  }

  Text buildNameAndSizeText({
    @required Color textColor,
    @required bool oneLine,
  }) {
    return Text(
      rootNode.displayText(oneLine: oneLine),
      style: TextStyle(color: textColor),
      textAlign: TextAlign.center,
      overflow: TextOverflow.ellipsis,
    );
  }

  Container buildBreadcrumbsNavigator() {
    final pathFromRoot = rootNode.pathFromRoot();
    return Container(
      height: treeMapHeaderHeight,
      child: ListView.separated(
        shrinkWrap: true,
        scrollDirection: Axis.horizontal,
        separatorBuilder: (context, index) {
          return const Text(' > ');
        },
        itemCount: pathFromRoot.length,
        itemBuilder: (BuildContext context, int index) {
          return buildSelectable(
            child: Text(
              index < pathFromRoot.length - 1
                  ? pathFromRoot[index].name
                  : pathFromRoot[index].displayText(),
            ),
            newRoot: pathFromRoot[index],
          );
        },
      ),
    );
  }

  /// Builds a selectable container with [child] as its child.
  ///
  /// Selecting this widget will trigger a re-root of the tree
  /// to the associated [TreemapNode].
  ///
  /// The default value for newRoot is [rootNode].
  Widget buildSelectable({@required Widget child, TreemapNode newRoot}) {
    newRoot ??= rootNode;
    return Tooltip(
      message: rootNode.displayText(),
      waitDuration: tooltipWait,
      preferBelow: false,
      child: InkWell(
        onTap: () {
          if (rootNode.children.isNotEmpty) onRootChangedCallback(newRoot);
        },
        child: child,
      ),
    );
  }

  Widget buildSubTreemaps() {
    return LayoutBuilder(
      builder: (context, constraints) {
        // TODO(peterdjlee): Investigate why exception is thrown without this check
        //                   and if there are any other cases.
        if (constraints.maxHeight == 0 || constraints.maxWidth == 0) {
          return const SizedBox();
        }
        final positionedChildren = buildTreemaps(
          children: nodes,
          x: 0,
          y: 0,
          width: constraints.maxWidth,
          height: constraints.maxHeight,
        );
        if (levelsVisible <= 1) {
          // If this is the second to the last level, paint all cells in the last level
          // instead of creating widgets to improve performance.
          return CustomPaint(
            painter: MultiCellPainter(nodes: positionedChildren),
            size: Size(constraints.maxWidth, constraints.maxHeight),
          );
        } else {
          // Else all widgets should still be positioned Treemap widgets.
          return Stack(children: positionedChildren);
        }
      },
    );
  }
}

class TreemapNode extends TreeNode<TreemapNode> {
  TreemapNode({
    @required this.name,
    this.byteSize = 0,
    this.childrenMap = const <String, TreemapNode>{},
    this.showDiff = false,
  })  : assert(name != null),
        assert(byteSize != null),
        assert(childrenMap != null);

  final String name;
  final Map<String, TreemapNode> childrenMap;
  int byteSize;

  final bool showDiff;

  int get unsignedByteSize => byteSize.abs();

  Color get displayColor {
    if (!showDiff) return mainUiColor;
    if (byteSize < 0)
      return treemapDecreaseColor;
    else
      return treemapIncreaseColor;
  }

  String displayText({bool oneLine = true}) {
    var displayName = name;

    // Trim beginning of the name of [this] if it starts with its parent's name.
    // If the parent node and the child node's name are exactly the same,
    // do not trim in order to avoid empty names.
    if (parent != null &&
        displayName.startsWith(parent.name) &&
        displayName != parent.name) {
      displayName = displayName.replaceFirst(parent.name, '');
      if (displayName.startsWith('/')) {
        displayName = displayName.replaceFirst('/', '');
      }
    }
    final separator = oneLine ? ' ' : '\n';
    return '$displayName$separator[${prettyByteSize()}]';
  }

  String prettyByteSize() {
    // Negative sign isn't explicitly added since a regular print of a negative number includes it.
    final plusSign = showDiff && byteSize > 0 ? '+' : '';
    return '$plusSign${prettyPrintBytes(byteSize, kbFractionDigits: 1, includeUnit: true)}';
  }

  /// Returns a list of [TreemapNode] in the path from root node to [this].
  List<TreemapNode> pathFromRoot() {
    TreemapNode node = this;
    final path = <TreemapNode>[];
    while (node != null) {
      path.add(node);
      node = node.parent;
    }
    return path.reversed.toList();
  }

  void printTree() {
    printTreeHelper(this, '');
  }

  void printTreeHelper(TreemapNode root, String tabs) {
    print(tabs + '$root');
    for (final child in root.children) {
      printTreeHelper(child, tabs + '\t');
    }
  }

  @override
  String toString() {
    return '{name: $name, size: $byteSize}';
  }
}

class PositionedCell extends Positioned {
  const PositionedCell({
    @required left,
    @required top,
    @required width,
    @required height,
    @required this.node,
    child,
  }) : super(left: left, top: top, width: width, height: height, child: child);

  final TreemapNode node;
}

class MultiCellPainter extends CustomPainter {
  const MultiCellPainter({@required this.nodes});

  final List<PositionedCell> nodes;

  @override
  void paint(Canvas canvas, Size size) {
    for (final positionedCell in nodes) {
      paintCell(
        canvas,
        Size(positionedCell.width, positionedCell.height),
        positionedCell,
      );
    }
  }

  void paintCell(Canvas canvas, Size size, PositionedCell positionedCell) {
    final node = positionedCell.node;

    final bounds = Rect.fromLTWH(
      positionedCell.left,
      positionedCell.top,
      size.width,
      size.height,
    );

    final rectPaint = Paint();
    rectPaint.color = node.displayColor;
    canvas.drawRect(bounds, rectPaint);

    final borderPaint = Paint()
      ..color = Colors.black87
      ..style = PaintingStyle.stroke;
    canvas.drawRect(bounds, borderPaint);

    if (positionedCell.width > Treemap.minWidthToDisplayCellText &&
        positionedCell.height > Treemap.minHeightToDisplayCellText) {
      final textPainter = TextPainter(
        text: TextSpan(
          text: node.displayText(oneLine: false),
          style: TextStyle(
            color: node.showDiff ? Colors.white : Colors.black,
          ),
        ),
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
        ellipsis: '...',
      )..layout(maxWidth: size.width);

      final centerX =
          positionedCell.left + bounds.width / 2 - textPainter.width / 2;
      final centerY =
          positionedCell.top + bounds.height / 2 - textPainter.height / 2;
      textPainter.paint(
        canvas,
        Offset(centerX, centerY),
      );
    }
  }

  @override
  bool shouldRepaint(MultiCellPainter oldDelegate) {
    return false;
  }
}
