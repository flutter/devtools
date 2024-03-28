// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app_shared/ui.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:logging/logging.dart';

import '../common_widgets.dart';
import '../primitives/byte_utils.dart';
import '../primitives/trees.dart';
import '../ui/colors.dart';

enum PivotType { pivotByMiddle, pivotBySize }

final _log = Logger('charts/treemap');

class Treemap extends StatefulWidget {
  // TODO(peterdjlee): Consider auto-expanding rootNode named 'src'.
  const Treemap.fromRoot({
    super.key,
    required this.rootNode,
    this.nodes,
    required this.levelsVisible,
    this.isOutermostLevel = false,
    required this.width,
    required this.height,
    required this.onRootChangedCallback,
  }) : assert((rootNode == null) != (nodes == null));

  const Treemap.fromNodes({
    super.key,
    this.rootNode,
    required this.nodes,
    required this.levelsVisible,
    this.isOutermostLevel = false,
    required this.width,
    required this.height,
    required this.onRootChangedCallback,
  }) : assert((rootNode == null) != (nodes == null));

  final TreemapNode? rootNode;

  final List<TreemapNode>? nodes;

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

  final void Function(TreemapNode? node) onRootChangedCallback;

  static const PivotType pivotType = PivotType.pivotByMiddle;

  static const treeMapHeaderHeight = 20.0;

  static const minHeightToDisplayTitleText = 100.0;

  static const minWidthToDisplayCellText = 40.0;
  static const minHeightToDisplayCellText = 50.0;

  @override
  State<Treemap> createState() => _TreemapState();
}

class _TreemapState extends State<Treemap> {
  TreemapNode? hoveredNode;

  /// Computes the total size of a given list of treemap nodes.
  /// [endIndex] defaults to nodes.length - 1.
  int computeByteSizeForNodes({
    required List<TreemapNode> nodes,
    int startIndex = 0,
    int? endIndex,
  }) {
    endIndex ??= nodes.length - 1;
    int sum = 0;
    for (int i = startIndex; i <= endIndex; i++) {
      sum += nodes[i].unsignedByteSize;
    }
    return sum;
  }

  int computePivot(List<TreemapNode> children) {
    switch (Treemap.pivotType) {
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
    required List<TreemapNode> children,
    required double x,
    required double y,
    required double width,
    required double height,
  }) {
    final isHorizontalRectangle = width > height;

    final totalByteSize = computeByteSizeForNodes(nodes: children);
    // If there's no children or the children have a size of zero, there's
    // nothing to display.
    if (children.isEmpty || totalByteSize == 0) {
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
            rect: Rect.fromLTWH(
              isHorizontalRectangle ? x + offset : x,
              isHorizontalRectangle ? y : y + offset,
              newWidth,
              newHeight,
            ),
            node: child,
            child: Treemap.fromRoot(
              rootNode: child,
              levelsVisible: widget.levelsVisible - 1,
              onRootChangedCallback: widget.onRootChangedCallback,
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

    // Construct list 1 sub-treemap.
    final list1SizeRatio = list1ByteSize / totalByteSize;
    final list1Width = isHorizontalRectangle ? width * list1SizeRatio : width;
    final list1Height =
        isHorizontalRectangle ? height : height * list1SizeRatio;
    if (list1.isNotEmpty) {
      positionedTreemaps.addAll(
        buildTreemaps(
          children: list1,
          x: x,
          y: y,
          width: list1Width,
          height: list1Height,
        ),
      );
    }

    // Construct list 2 sub-treemap.
    final list2Width =
        isHorizontalRectangle ? pivotBestWidth : width - pivotBestWidth;
    final list2Height =
        isHorizontalRectangle ? height - pivotBestHeight : pivotBestHeight;
    final list2XCoord = isHorizontalRectangle ? list1Width : 0.0;
    final list2YCoord = isHorizontalRectangle ? pivotBestHeight : list1Height;
    if (list2.isNotEmpty) {
      positionedTreemaps.addAll(
        buildTreemaps(
          children: list2,
          x: x + list2XCoord,
          y: y + list2YCoord,
          width: list2Width,
          height: list2Height,
        ),
      );
    }

    // Construct pivot cell.
    final pivotXCoord = isHorizontalRectangle ? list1Width : list2Width;
    final pivotYCoord = isHorizontalRectangle ? 0.0 : list1Height;

    positionedTreemaps.add(
      PositionedCell(
        rect: Rect.fromLTWH(
          x + pivotXCoord,
          y + pivotYCoord,
          pivotBestWidth,
          pivotBestHeight,
        ),
        node: pivotNode,
        child: Treemap.fromRoot(
          rootNode: pivotNode,
          levelsVisible: widget.levelsVisible - 1,
          onRootChangedCallback: widget.onRootChangedCallback,
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
      positionedTreemaps.addAll(
        buildTreemaps(
          children: list3,
          x: x + list3XCoord,
          y: y + list3YCoord,
          width: list3Width,
          height: list3Height,
        ),
      );
    }

    return positionedTreemaps;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.rootNode == null && widget.nodes!.isNotEmpty) {
      // If constructed with Treemap.fromNodes
      return buildSubTreemaps();
    } else {
      // If constructed with Treemap.fromRoot
      return buildTreemap();
    }
  }

  Widget buildSubTreemaps() {
    assert(widget.nodes != null && widget.nodes!.isNotEmpty);
    return LayoutBuilder(
      builder: (context, constraints) {
        final defaultTextStyle = Theme.of(context).regularTextStyle;
        // TODO(peterdjlee): Investigate why exception is thrown without this check
        //                   and if there are any other cases.
        if (constraints.maxHeight == 0 || constraints.maxWidth == 0) {
          return const SizedBox();
        }
        final positionedChildren = buildTreemaps(
          children: widget.nodes!,
          x: 0,
          y: 0,
          width: constraints.maxWidth,
          height: constraints.maxHeight,
        );
        if (widget.levelsVisible == 1) {
          // If this is the second to the last level, paint all cells in the last level
          // instead of creating widgets to improve performance.

          return DevToolsTooltip(
            // A key is required to force a rebuild of the tooltips for each cell.
            // Use tooltipMessage as the key to prevent rebuilds within a cell.
            key: Key(hoveredNode?.displayText() ?? ''),
            richMessage: hoveredNode?.displayTextSpan(
                  defaultTextStyle: defaultTextStyle,
                ) ??
                const TextSpan(text: ''),
            waitDuration: tooltipWaitLong,
            child: MouseRegion(
              onHover: (event) => _onHover(event, positionedChildren),
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTapDown: (details) {
                  widget.onRootChangedCallback(hoveredNode);
                },
                child: CustomPaint(
                  painter: MultiCellPainter(
                    nodes: positionedChildren,
                    defaultTextStyle: defaultTextStyle,
                  ),
                  size: Size(constraints.maxWidth, constraints.maxHeight),
                ),
              ),
            ),
          );
        } else {
          // Else all widgets should still be positioned Treemap widgets.
          return Stack(children: positionedChildren);
        }
      },
    );
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
  Widget buildTreemap() {
    assert(widget.rootNode != null);
    if (widget.rootNode!.children.isNotEmpty) {
      return Padding(
        padding: const EdgeInsets.all(1.0),
        child: buildTreemapFromNodes(),
      );
    } else {
      // If given a root node but its children are empty, draw itself.
      return buildTreemapFromRoot();
    }
  }

  Widget buildTreemapFromNodes() {
    return Column(
      children: [
        if (widget.height > Treemap.minHeightToDisplayTitleText)
          _TitleBar(
            rootNode: widget.rootNode!,
            isOutermostLevel: widget.isOutermostLevel,
            onRootChangedCallback: widget.onRootChangedCallback,
          ),
        Expanded(
          child: Treemap.fromNodes(
            nodes: widget.rootNode!.children,
            levelsVisible: widget.levelsVisible,
            onRootChangedCallback: widget.onRootChangedCallback,
            width: widget.width,
            height: widget.height,
          ),
        ),
      ],
    );
  }

  Column buildTreemapFromRoot() {
    final rootNode = widget.rootNode!;
    final child = _TreeMapCell(
      treeMapHeight: widget.height,
      node: rootNode,
    );
    return Column(
      children: [
        if (widget.isOutermostLevel)
          _TitleBar(
            rootNode: widget.rootNode!,
            isOutermostLevel: widget.isOutermostLevel,
            onRootChangedCallback: widget.onRootChangedCallback,
          ),
        Expanded(
          child: widget.isOutermostLevel
              ? child
              : _SelectableTreemapNode(
                  node: rootNode,
                  onRootChangedCallback: widget.onRootChangedCallback,
                  child: child,
                ),
        ),
      ],
    );
  }

  /// Checks if the touch point of the given [details] is overlapping with
  /// a cell in [positionedCells].
  ///
  /// If so, saves the matching hoveredNode.
  void _onHover(
    PointerHoverEvent event,
    List<PositionedCell> positionedCells,
  ) {
    final x = event.localPosition.dx;
    final y = event.localPosition.dy;
    final touchPoint = Offset(x, y);
    // TODO(peterdjlee): Optimize with more efficient algorithm to find the overlapping cell.
    //                   Currently O(positionedCells.length) but an optimized algorithm with
    //                   O(log(positionedCells.length)) is possible.
    for (final cell in positionedCells) {
      if (cell.rect.contains(touchPoint)) {
        setState(() {
          hoveredNode = cell.node;
        });
      }
    }
  }
}

class _TreeMapCell extends StatelessWidget {
  const _TreeMapCell({
    required this.treeMapHeight,
    required this.node,
  });

  final double treeMapHeight;
  final TreemapNode node;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: node.displayColor,
        border: Border.all(color: Colors.black87),
      ),
      child: Center(
        child: treeMapHeight > Treemap.minHeightToDisplayCellText
            ? _NameAndSizeText(
                node: node,
                color: node.showDiff ? Colors.white : Colors.black,
                singleLine: false,
              )
            : const SizedBox(),
      ),
    );
  }
}

class _TitleBar extends StatelessWidget {
  const _TitleBar({
    required this.rootNode,
    required this.onRootChangedCallback,
    required this.isOutermostLevel,
  });

  final TreemapNode rootNode;
  final void Function(TreemapNode? node) onRootChangedCallback;
  final bool isOutermostLevel;

  @override
  Widget build(BuildContext context) {
    if (isOutermostLevel) {
      return _BreadcrumbNavigator(
        pathFromRoot: rootNode.pathFromRoot(),
        onRootChangedCallback: onRootChangedCallback,
      );
    } else {
      return _SelectableTreemapNode(
        node: rootNode,
        onRootChangedCallback: onRootChangedCallback,
        child: Container(
          height: Treemap.treeMapHeaderHeight,
          width: double.infinity,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.black87),
          ),
          child: _NameAndSizeText(
            node: rootNode,
            color: Theme.of(context).colorScheme.onSurface,
            singleLine: true,
          ),
        ),
      );
    }
  }
}

class _NameAndSizeText extends StatelessWidget {
  const _NameAndSizeText({
    required this.node,
    required this.color,
    required this.singleLine,
  });

  final TreemapNode node;
  final Color color;
  final bool singleLine;

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: node.displayTextSpan(
        singleLine: singleLine,
        color: color,
        defaultTextStyle: Theme.of(context).regularTextStyle,
      ),
      selectionColor: color,
      textAlign: TextAlign.center,
      overflow: TextOverflow.ellipsis,
    );
  }
}

class _BreadcrumbNavigator extends StatelessWidget {
  const _BreadcrumbNavigator({
    required this.pathFromRoot,
    required this.onRootChangedCallback,
  });

  final List<TreemapNode> pathFromRoot;
  final void Function(TreemapNode? node) onRootChangedCallback;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: denseRowSpacing),
      child: BreadcrumbNavigator.builder(
        itemCount: pathFromRoot.length,
        builder: (context, index) {
          final node = pathFromRoot[index];
          return Breadcrumb(
            text: index < pathFromRoot.length - 1
                ? node.name
                : node.displayText(),
            isRoot: index == 0,
            onPressed: () => onRootChangedCallback(node),
          );
        },
      ),
    );
  }
}

/// A selectable container with [child] as its child.
///
/// Selecting this widget will trigger a re-root of the tree
/// to [node].
class _SelectableTreemapNode extends StatelessWidget {
  const _SelectableTreemapNode({
    required this.node,
    required this.onRootChangedCallback,
    required this.child,
  });

  final TreemapNode node;
  final void Function(TreemapNode? node) onRootChangedCallback;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DevToolsTooltip(
      message: node.displayText(),
      waitDuration: tooltipWaitLong,
      child: InkWell(
        onTap: () {
          onRootChangedCallback(node);
        },
        child: child,
      ),
    );
  }
}

class TreemapNode extends TreeNode<TreemapNode> {
  TreemapNode({
    required this.name,
    this.byteSize = 0,
    this.childrenMap = const <String, TreemapNode>{},
    this.showDiff = false,
    this.backgroundColor,
    this.caption,
  });

  final String name;
  final Map<String, TreemapNode> childrenMap;
  int byteSize;

  final bool showDiff;
  final Color? backgroundColor;
  final String? caption;

  int get unsignedByteSize => byteSize.abs();

  Color get displayColor {
    if (!showDiff) {
      return backgroundColor ?? mainUiColor;
    }
    return byteSize < 0 ? treemapDecreaseColor : treemapIncreaseColor;
  }

  String displayText({bool singleLine = true, bool includeCaption = true}) {
    var displayName = name;
    // Trim beginning of the name of [this] if it starts with its parent's name.
    // If the parent node and the child node's name are exactly the same,
    // do not trim in order to avoid empty names.
    final parent = this.parent;
    if (parent != null) {
      final parentName = parent.name;
      if (displayName.startsWith(parentName) && displayName != parentName) {
        displayName = displayName.replaceFirst(parentName, '');
        if (displayName.startsWith('/')) {
          displayName = displayName.replaceFirst('/', '');
        }
      }
    }

    final separator = singleLine ? ' ' : '\n';
    displayName = '$displayName$separator[${prettyByteSize()}]';
    if (includeCaption && caption != null) {
      displayName = '$displayName$separator$caption';
    }

    return displayName;
  }

  TextSpan displayTextSpan({
    required TextStyle defaultTextStyle,
    Color? color,
    bool singleLine = true,
  }) {
    final textColor = color ?? (showDiff ? Colors.white : Colors.black);
    final separator = singleLine ? ' ' : '\n';
    return TextSpan(
      text: displayText(includeCaption: false, singleLine: singleLine),
      style: defaultTextStyle.copyWith(color: textColor),
      children: [
        if (caption != null)
          TextSpan(
            text: '$separator$caption',
            style: defaultTextStyle.copyWith(
              fontStyle: FontStyle.italic,
              color: textColor,
            ),
          ),
      ],
    );
  }

  String prettyByteSize() {
    // Negative sign isn't explicitly added since a regular print of a negative number includes it.
    final plusSign = showDiff && byteSize > 0 ? '+' : '';
    return '$plusSign${prettyPrintBytes(byteSize, includeUnit: true)}';
  }

  /// Returns a list of [TreemapNode] in the path from root node to [this].
  List<TreemapNode> pathFromRoot() {
    TreemapNode? node = this;
    final path = <TreemapNode>[];
    while (node != null) {
      path.add(node);
      node = node.parent;
    }
    return path.reversed.toList();
  }

  /// Returns the package path for this node.
  ///
  /// Includes only package nodes (nodes that start with 'package:').
  List<String> packagePath() {
    final reversedPath = <String>[];
    TreemapNode? current = this;

    while (current != null) {
      if (current.name.contains('(Dart AOT)')) {
        // This as far up the tree as we want to go, since this is the root of
        // the Dart AOT snapshot.
        return reversedPath.reversed.toList();
      }

      // Prevent duplicated package names from being added to the path.
      // Sometimes the hierarchy can look like this:
      // package:a
      //     package: a
      //     <Type>
      //     <OneByteString>
      if ((current.name.startsWith('package:') ||
              current.name.startsWith('dart:')) &&
          (reversedPath.isEmpty || reversedPath.last != current.name)) {
        reversedPath.add(current.name);
      }
      current = current.parent;
    }
    return [];
  }

  void printTree() {
    printTreeHelper(this, '');
  }

  void printTreeHelper(TreemapNode root, String tabs) {
    _log.info('$tabs$root');
    for (final child in root.children) {
      printTreeHelper(child, '$tabs\t');
    }
  }

  @override
  String toString() {
    return '{name: $name, size: $byteSize}';
  }

  @override
  TreemapNode shallowCopy() {
    throw UnimplementedError(
      'This method is not implemented. Implement if you '
      'need to call `shallowCopy` on an instance of this class.',
    );
  }
}

class PositionedCell extends Positioned {
  PositionedCell({
    super.key,
    required this.rect,
    required this.node,
    required super.child,
  }) : super(
          left: rect.left,
          top: rect.top,
          width: rect.width,
          height: rect.height,
        );

  final Rect rect;

  final TreemapNode node;
}

class MultiCellPainter extends CustomPainter {
  const MultiCellPainter({required this.nodes, required this.defaultTextStyle});

  final List<PositionedCell> nodes;
  final TextStyle defaultTextStyle;

  @override
  void paint(Canvas canvas, Size size) {
    for (final positionedCell in nodes) {
      paintCell(
        canvas,
        Size(positionedCell.width!, positionedCell.height!),
        positionedCell,
      );
    }
  }

  void paintCell(Canvas canvas, Size size, PositionedCell positionedCell) {
    final node = positionedCell.node;

    final bounds = Rect.fromLTWH(
      positionedCell.left!,
      positionedCell.top!,
      size.width,
      size.height,
    );

    final rectPaint = Paint();
    rectPaint.color = node.displayColor;
    canvas.drawRect(bounds, rectPaint);

    final borderPaint = Paint()
      ..color = Colors.black45
      ..style = PaintingStyle.stroke;
    canvas.drawRect(bounds, borderPaint);

    if (positionedCell.width! > Treemap.minWidthToDisplayCellText &&
        positionedCell.height! > Treemap.minHeightToDisplayCellText) {
      final textPainter = TextPainter(
        text: node.displayTextSpan(
          defaultTextStyle: defaultTextStyle,
          singleLine: false,
        ),
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
        ellipsis: '...',
      )..layout(maxWidth: size.width);

      final centerX =
          positionedCell.left! + bounds.width / 2 - textPainter.width / 2;
      final centerY =
          positionedCell.top! + bounds.height / 2 - textPainter.height / 2;
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
