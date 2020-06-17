import 'package:flutter/material.dart';

import '../common_widgets.dart';
import '../trees.dart';
import '../ui/colors.dart';
import '../utils.dart';

enum PivotType { pivotByMiddle, pivotBySize }

class Treemap extends StatelessWidget {
  Treemap._({
    this.rootNode,
    this.nodes = const [],
    @required this.levelsVisible,
    @required this.height,
    @required this.onRootChangedCallback,
  }) : assert(rootNode == null && nodes.isNotEmpty ||
            rootNode != null && nodes.isEmpty);

  Treemap.fromRoot({
    @required TreemapNode rootNode,
    @required levelsVisible,
    @required height,
    @required onRootChangedCallback,
  }) : this._(
          rootNode: rootNode,
          levelsVisible: levelsVisible,
          height: height,
          onRootChangedCallback: onRootChangedCallback,
        );

  Treemap.fromNodes({
    @required List<TreemapNode> nodes,
    @required levelsVisible,
    @required height,
    @required onRootChangedCallback,
  }) : this._(
          nodes: nodes,
          levelsVisible: levelsVisible,
          height: height,
          onRootChangedCallback: onRootChangedCallback,
        );

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

  final double height;

  final void Function(TreemapNode node) onRootChangedCallback;

  final PivotType pivotType = PivotType.pivotBySize;

  static const treeMapHeaderHeight = 20.0;

  static const minHeightToDisplayTitleText = 20.0;

  static const minHeightToDisplayCellText = 40.0;

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
      sum += nodes[i].byteSize;
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
          if (children[i].byteSize > maxSize) {
            maxSize = children[i].byteSize.toDouble();
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
  List<Positioned> buildTreemaps({
    @required List<TreemapNode> children,
    @required double width,
    @required double height,
  }) {
    final isHorizontalRectangle = width > height;

    final totalByteSize = computeByteSizeForNodes(nodes: children);
    if (children.isEmpty) {
      return [];
    }

    // Sort the list of treemap nodes, descending in size.
    children.sort((a, b) => b.byteSize.compareTo(a.byteSize));
    if (children.length <= 2) {
      final positionedChildren = <Positioned>[];
      double offset = 0;

      for (final child in children) {
        final ratio = child.byteSize / totalByteSize;

        positionedChildren.add(
          Positioned(
            left: isHorizontalRectangle ? offset : 0.0,
            top: isHorizontalRectangle ? 0.0 : offset,
            width: isHorizontalRectangle ? ratio * width : width,
            height: isHorizontalRectangle ? height : ratio * height,
            child: Treemap.fromRoot(
              rootNode: child,
              levelsVisible: levelsVisible - 1,
              onRootChangedCallback: onRootChangedCallback,
              height: height,
            ),
          ),
        );
        offset += isHorizontalRectangle ? ratio * width : ratio * height;
      }

      return positionedChildren;
    }

    final pivotIndex = computePivot(children);

    final pivotNode = children[pivotIndex];
    final pivotByteSize = pivotNode.byteSize;

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

    final positionedTreemaps = <Positioned>[];

    // Contruct list 1 sub-treemap.
    final list1SizeRatio = list1ByteSize / totalByteSize;
    final list1Width = isHorizontalRectangle ? width * list1SizeRatio : width;
    final list1Height =
        isHorizontalRectangle ? height : height * list1SizeRatio;
    if (list1.isNotEmpty) {
      positionedTreemaps.add(
        Positioned(
          left: 0.0,
          right: 0.0,
          width: list1Width,
          height: list1Height,
          child: Treemap.fromNodes(
            nodes: list1,
            levelsVisible: levelsVisible, // Stay at current level since
            onRootChangedCallback: onRootChangedCallback,
            height: height,
          ),
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
      positionedTreemaps.add(
        Positioned(
          left: list2XCoord,
          top: list2YCoord,
          width: list2Width,
          height: list2Height,
          child: Treemap.fromNodes(
            nodes: list2,
            levelsVisible: levelsVisible,
            onRootChangedCallback: onRootChangedCallback,
            height: height,
          ),
        ),
      );
    }

    // Construct pivot cell.
    final pivotXCoord = isHorizontalRectangle ? list1Width : list2Width;
    final pivotYCoord = isHorizontalRectangle ? 0.0 : list1Height;

    positionedTreemaps.add(
      Positioned(
        left: pivotXCoord,
        top: pivotYCoord,
        width: pivotBestWidth,
        height: pivotBestHeight,
        child: Treemap.fromRoot(
          rootNode: pivotNode,
          levelsVisible: levelsVisible - 1,
          onRootChangedCallback: onRootChangedCallback,
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
      positionedTreemaps.add(
        Positioned(
          left: list3XCoord,
          top: list3YCoord,
          width: list3Width,
          height: list3Height,
          child: Treemap.fromNodes(
            nodes: list3,
            levelsVisible: levelsVisible,
            onRootChangedCallback: onRootChangedCallback,
            height: height,
          ),
        ),
      );
    }

    return positionedTreemaps;
  }

  Text buildNameAndSizeText({
    @required Color fontColor,
    @required bool oneline,
  }) {
    return Text(
      rootNode.displayText(oneLine: oneline),
      style: TextStyle(color: fontColor),
      textAlign: TextAlign.center,
      overflow: TextOverflow.ellipsis,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (rootNode == null && nodes.isNotEmpty) {
      return buildSubTreemaps();
    } else {
      return buildTreemap();
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
  Widget buildTreemap() {
    if (levelsVisible > 0 && rootNode.children.isNotEmpty) {
      return Padding(
        padding: const EdgeInsets.all(1.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (height > minHeightToDisplayTitleText) buildTitleText(),
            Expanded(
              child: Treemap.fromNodes(
                nodes: rootNode.children,
                levelsVisible: levelsVisible,
                onRootChangedCallback: onRootChangedCallback,
                height: height,
              ),
            ),
          ],
        ),
      );
    } else {
      return Column(
        children: [
          if (levelsVisible == 2 && height > minHeightToDisplayTitleText)
            buildTitleText(),
          Expanded(
            child: buildSelectable(
              child: Container(
                decoration: BoxDecoration(
                  color: mainUiColor,
                  border: Border.all(color: Colors.black54),
                ),
                child: Center(
                  child: height > minHeightToDisplayCellText
                      ? buildNameAndSizeText(
                          fontColor: Colors.black,
                          oneline: false,
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

  Widget buildTitleText() {
    if (levelsVisible == 2) {
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
    } else {
      return buildSelectable(
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.black54),
          ),
          child: buildNameAndSizeText(
            fontColor: Colors.white,
            oneline: true,
          ),
        ),
      );
    }
  }

  /// Builds a selectable container with [child] as its child.
  ///
  /// Selecting this widget will trigger a re-root of the tree
  /// to the associated [TreemapNode].
  ///
  /// The default value for newRoot is [rootNode].
  Tooltip buildSelectable({@required Widget child, TreemapNode newRoot}) {
    newRoot ??= rootNode;
    return Tooltip(
      message: rootNode.displayText(),
      waitDuration: tooltipWait,
      preferBelow: false,
      child: InkWell(
        onTap: () {
          onRootChangedCallback(newRoot);
        },
        child: child,
      ),
    );
  }

  Widget buildSubTreemaps() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Stack(
          children: buildTreemaps(
            children: nodes,
            width: constraints.maxWidth,
            height: constraints.maxHeight,
          ),
        );
      },
    );
  }
}

class TreemapNode extends TreeNode<TreemapNode> {
  TreemapNode({
    @required this.name,
    this.byteSize = 0,
    this.childrenMap = const <String, TreemapNode>{},
  })  : assert(name != null),
        assert(byteSize != null),
        assert(childrenMap != null);

  final String name;
  final Map<String, TreemapNode> childrenMap;
  int byteSize;

  String displayText({bool oneLine = true}) {
    final separator = oneLine ? ' ' : '\n';
    return '$name$separator${prettyPrintBytes(byteSize)}';
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
