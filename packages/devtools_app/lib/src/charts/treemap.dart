import 'package:flutter/material.dart';

import '../trees.dart';
import '../utils.dart';

class Treemap extends StatefulWidget {
  const Treemap({
    @required this.rootNode,
    @required this.levelsVisible,
    @required this.width,
    @required this.height,
    @required this.onTap,
  });

  final TreemapNode rootNode;

  /// The depth of children visible from this Treemap widget.
  ///
  /// For example, levelsVisible = 2 at root Treemap:
  /// ```
  /// _______________
  /// |     Root    |
  /// ---------------
  /// |    l = 1    |
  /// |  ---------  |
  /// |  | l = 2 |  |
  /// |  |       |  |
  /// |  |       |  |
  /// |  ---------  |
  /// ---------------
  /// ```
  final int levelsVisible;

  final double width;

  final double height;

  final VoidCallback onTap;

  @override
  _TreemapState createState() => _TreemapState();
}

enum PivotType { pivotByMiddle, pivotBySize }

class _TreemapState extends State<Treemap> {
  static const double minHeightToDisplayText = 20.0;
  PivotType pivotType = PivotType.pivotBySize;

  TreemapNode rootNode;

  @override
  void initState() {
    super.initState();
    rootNode = widget.rootNode;
  }

  bool get shouldDisplayText => widget.height > minHeightToDisplayText;

  void cellOnTap(TreemapNode child) {
    if (child != null) {
      setState(() {
        rootNode = child;
      });
    }
  }

  /// Computes the total size of a given list of treemap nodes.
  int computeByteSizeForNodes({
    @required List<TreemapNode> nodes,
    @required int startIndex,
    @required int endIndex,
  }) {
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

  /// Divides a given list of treemap nodes into four parts:
  /// L1, P, L2, L3.

  /// P (pivot) is the treemap node chosen to be the pivot based on the pivot type.
  /// L1 includes all treemap nodes before the pivot treemap node.
  /// L2 and L3 combined include all treemap nodes after the pivot treemap node.
  /// A combination of elements are put into L2 and L3 so that
  /// the aspect ratio of the pivot cell (P) is as close to 1 as it can be.

  /// Example layout:
  /// ```
  /// ----------------------
  /// |      |  P   |      |
  /// |      |      |      |
  /// |  L1  |------|  L3  |
  /// |      |  L2  |      |
  /// |      |      |      |
  /// ----------------------
  /// ```
  List<TreemapCell> buildTreemap({
    @required List<TreemapNode> children,
    @required double width,
    @required double height,
    @required double x,
    @required double y,
  }) {
    final isHorizontalRectangle = width > height;

    final totalSize = computeByteSizeForNodes(
      nodes: children,
      startIndex: 0,
      endIndex: children.length - 1,
    );

    if (children.isEmpty) {
      return [];
    }

    // Sort list of children, descending in size.
    children.sort((a, b) => b.byteSize.compareTo(a.byteSize));

    if (children.length <= 2) {
      final positionedChildren = <TreemapCell>[];
      double offset = isHorizontalRectangle ? x : y;

      for (final child in children) {
        final ratio = child.byteSize / totalSize;
        positionedChildren.add(
          TreemapCell(
            key: UniqueKey(),
            x: isHorizontalRectangle ? offset : x,
            y: isHorizontalRectangle ? y : offset,
            width: isHorizontalRectangle ? ratio * width : width,
            height: isHorizontalRectangle ? height : ratio * height,
            onTap: () => cellOnTap(rootNode.childrenMap[child.name]),
            node: child,
            levelsVisible: widget.levelsVisible - 1,
          ),
        );

        offset += isHorizontalRectangle ? ratio * width : ratio * height;
      }

      return positionedChildren;
    }

    final pivotIndex = computePivot(children);

    final pivotDataReference = children[pivotIndex];
    final pSize = pivotDataReference.byteSize;

    final list1 = children.sublist(0, pivotIndex);
    final list1Size = computeByteSizeForNodes(
      nodes: list1,
      startIndex: 0,
      endIndex: list1.length - 1,
    );

    List<TreemapNode> list2 = [];
    int list2Size = 0;
    List<TreemapNode> list3 = [];
    int list3Size = 0;

    // The amount of data we have from pivot + 1 (exclusive)
    // In another words, if we only put one data in l2, how many are left for l3?
    // [L1, pivotIndex, data, |d|] d = 2
    final l3MaxLength = children.length - pivotIndex - 1;
    int bestIndex = 0;
    double pivotBestWidth = 0;
    double pivotBestHeight = 0;

    // We need to be able to put at least 3 elements in l3 for this algorithm.
    if (l3MaxLength >= 3) {
      double pBestAspectRatio = double.infinity;
      // Iterate through different combinations of list2 and list3 to find
      // the combination where the aspect ratio of pivot is the lowest.
      for (int i = pivotIndex + 1; i < children.length; i++) {
        final list2Size = computeByteSizeForNodes(
          nodes: children,
          startIndex: pivotIndex + 1,
          endIndex: i,
        );

        // Calculate the aspect ratio for the pivot treemap node.
        final pAndList2Ratio = (pSize + list2Size) / totalSize;
        final pRatio = pSize / (pSize + list2Size);

        final pWidth =
            isHorizontalRectangle ? pAndList2Ratio * width : pRatio * width;

        final pHeight =
            isHorizontalRectangle ? pRatio * height : pAndList2Ratio * height;

        final pAspectRatio = pWidth / pHeight;

        // Best aspect ratio that is the closest to 1.
        if ((1 - pAspectRatio).abs() < (1 - pBestAspectRatio).abs()) {
          pBestAspectRatio = pAspectRatio;
          bestIndex = i;
          // Kept track of width and height to construct the pivot cell.
          pivotBestWidth = pWidth;
          pivotBestHeight = pHeight;
        }
      }
      // Split the rest of the data into list2 and list3
      // [L1, pivotIndex, [L2 bestIndex], L3]
      list2 = children.sublist(pivotIndex + 1, bestIndex + 1);
      list2Size = computeByteSizeForNodes(
        nodes: list2,
        startIndex: 0,
        endIndex: list2.length - 1,
      );

      list3 = children.sublist(bestIndex + 1);
      list3Size = computeByteSizeForNodes(
        nodes: list3,
        startIndex: 0,
        endIndex: list3.length - 1,
      );
    } else {
      // Put all data in l2 and none in l3.
      list2 = children.sublist(pivotIndex + 1);
      list2Size = computeByteSizeForNodes(
        nodes: list2,
        startIndex: 0,
        endIndex: list2.length - 1,
      );

      final pdAndList2Ratio = (pSize + list2Size) / totalSize;
      final pdRatio = pSize / (pSize + list2Size);
      pivotBestWidth =
          isHorizontalRectangle ? pdAndList2Ratio * width : pdRatio * width;
      pivotBestHeight =
          isHorizontalRectangle ? pdRatio * height : pdAndList2Ratio * height;
    }

    // Contruct list 1 sub-treemap.
    final list1SizeRatio = list1Size / totalSize;
    final list1Width = isHorizontalRectangle ? width * list1SizeRatio : width;
    final list1Height =
        isHorizontalRectangle ? height : height * list1SizeRatio;
    final list1Cells = buildTreemap(
      children: list1,
      width: list1Width,
      height: list1Height,
      x: x,
      y: y,
    );

    // Construct list 2 sub-treemap.
    final list2Width =
        isHorizontalRectangle ? pivotBestWidth : width - pivotBestWidth;
    final list2Height =
        isHorizontalRectangle ? height - pivotBestHeight : pivotBestHeight;
    final list2XCoord = isHorizontalRectangle ? x + list1Width : x;
    final list2YCoord =
        isHorizontalRectangle ? y + pivotBestHeight : y + list1Height;
    final list2Cells = buildTreemap(
      children: list2,
      width: list2Width,
      height: list2Height,
      x: list2XCoord,
      y: list2YCoord,
    );

    // Construct pivot cell.
    final pivotXCoord = isHorizontalRectangle ? x + list1Width : x + list2Width;
    final pivotYCorrd = isHorizontalRectangle ? y : y + list1Height;
    final pivotCell = TreemapCell(
      key: UniqueKey(),
      width: pivotBestWidth,
      height: pivotBestHeight,
      x: pivotXCoord,
      y: pivotYCorrd,
      node: pivotDataReference,
      onTap: () => cellOnTap(rootNode.childrenMap[pivotDataReference.name]),
      levelsVisible: widget.levelsVisible - 1,
    );

    // Construct list 3 sub-treemap.
    final list3Ratio = list3Size / totalSize;
    final list3Width = isHorizontalRectangle ? list3Ratio * width : width;
    final list3Height = isHorizontalRectangle ? height : list3Ratio * height;
    final list3XCoord =
        isHorizontalRectangle ? x + list1Width + pivotBestWidth : x;
    final list3YCoord =
        isHorizontalRectangle ? y : y + list1Height + pivotBestHeight;
    final list3Cells = buildTreemap(
      children: list3,
      width: list3Width,
      height: list3Height,
      x: list3XCoord,
      y: list3YCoord,
    );

    return list1Cells + [pivotCell] + list2Cells + list3Cells;
  }

  /// Treemap layout:
  /// ```
  /// ----------------------------
  /// |        Title Text        |
  /// |--------------------------|
  /// |                          |
  /// |         Content          |
  /// |                          |
  /// |                          |
  /// ----------------------------
  /// ```
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(widget.levelsVisible > 0 ? 1.0 : 0.0),
      child: Container(
        decoration: BoxDecoration(border: Border.all(width: 0.5)),
        child: Column(
          children: [
            if (widget.levelsVisible > 0 &&
                rootNode.children.isNotEmpty &&
                shouldDisplayText)
              Center(
                child: Text(
                  rootNode.name + ' ' + nodeSizeText(),
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ),
            Expanded(child: buildContent()),
          ],
        ),
      ),
    );
  }

  Widget buildContent() {
    if (widget.levelsVisible == 0) {
      if (shouldDisplayText) {
        return Container(
          width: widget.width,
          child: Center(
            child: nameAndSizeText(),
          ),
        );
      } else {
        return const SizedBox();
      }
    } else if (widget.levelsVisible == 1) {
      if (rootNode.children.isNotEmpty) {
        return GestureDetector(
          onTap: widget.onTap,
          child: Container(
            color: Colors.white38,
            child: Tooltip(
              message: rootNode.name,
              child: buildNestedTreemap(),
            ),
          ),
        );
      } else {
        return Container(
          color: Colors.white38,
          child: shouldDisplayText
              ? Center(child: nameAndSizeText())
              : const SizedBox(),
        );
      }
    } else {
      return buildNestedTreemap();
    }
  }

  Text nameAndSizeText() {
    return Text(
      '${rootNode.name}\n${nodeSizeText()}',
      textAlign: TextAlign.center,
      overflow: TextOverflow.ellipsis,
    );
  }

  String nodeSizeText() {
    final size = rootNode.byteSize;
    final sizeInKB = size / 1024;
    if (sizeInKB < 1024.0) {
      return '[${printKb(size)} KB]';
    } else {
      return '[${printMb(size, 2)} MB]';
    }
  }

  LayoutBuilder buildNestedTreemap() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Container(
          width: constraints.maxWidth,
          height: constraints.maxHeight,
          decoration: BoxDecoration(
            border: Border.all(),
          ),
          child: Stack(
            children: buildTreemap(
              children: rootNode.children,
              width: constraints.maxWidth,
              height: constraints.maxHeight,
              x: 0.0,
              y: 0.0,
            ),
          ),
        );
      },
    );
  }
}

class TreemapCell extends StatelessWidget {
  const TreemapCell({
    Key key,
    @required this.width,
    @required this.height,
    @required this.x,
    @required this.y,
    @required this.levelsVisible,
    this.node,
    this.onTap,
  }) : super(key: key);

  final double width;
  final double height;

  // Origin is defined by the left top corner.
  // x is the horizontal distance from the origin.
  // y is the vertical distance from the origin.
  final double x;
  final double y;

  final VoidCallback onTap;
  final TreemapNode node;

  final int levelsVisible;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: x,
      top: y,
      width: width,
      height: height,
      child: Treemap(
        rootNode: node,
        levelsVisible: levelsVisible,
        width: width,
        height: height,
        onTap: onTap,
      ),
    );
  }

  @override
  String toString({DiagnosticLevel minLevel = DiagnosticLevel.info}) {
    if (node == null) return 'null';
    return {
      'width': width,
      'height': height,
      'x': x,
      'y': y,
      'node': node,
    }.toString();
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
    return '{name: $name, size: $byteSize}\n';
  }
}
