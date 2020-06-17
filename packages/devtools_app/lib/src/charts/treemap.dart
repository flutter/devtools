import 'package:flutter/material.dart';

import '../trees.dart';
import '../ui/colors.dart';
import '../utils.dart';

enum PivotType { pivotByMiddle, pivotBySize }

class NewTreemap extends StatefulWidget {
  NewTreemap._({
    this.rootNode,
    this.nodes = const [],
    this.levelsVisible,
    this.onRootChangedCallback,
  }) : assert(rootNode == null && nodes.isNotEmpty ||
            rootNode != null && nodes.isEmpty);

  NewTreemap.fromRoot({
    @required TreemapNode rootNode,
    @required levelsVisible,
    @required onRootChangedCallback,
  }) : this._(
            rootNode: rootNode,
            levelsVisible: levelsVisible,
            onRootChangedCallback: onRootChangedCallback);

  NewTreemap.fromNodes({
    @required List<TreemapNode> nodes,
    @required levelsVisible,
    @required onRootChangedCallback,
  }) : this._(
            nodes: nodes,
            levelsVisible: levelsVisible,
            onRootChangedCallback: onRootChangedCallback);

  final TreemapNode rootNode;

  final List<TreemapNode> nodes;

  final int levelsVisible;

  final void Function(TreemapNode) onRootChangedCallback;

  @override
  _NewTreemapState createState() => _NewTreemapState();
}

class _NewTreemapState extends State<NewTreemap> {
  PivotType pivotType = PivotType.pivotBySize;

  @override
  void initState() {
    super.initState();
  }

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
            child: NewTreemap.fromRoot(
              rootNode: child,
              levelsVisible: widget.levelsVisible - 1,
              onRootChangedCallback: widget.onRootChangedCallback,
            ),
          ),
        );
        offset += isHorizontalRectangle ? ratio * width : ratio * height;
      }

      return positionedChildren;
    }

    final pivotIndex = computePivot(children);

    final pivotDataReference = children[pivotIndex];
    final pByteSize = pivotDataReference.byteSize;

    final list1 = children.sublist(0, pivotIndex);
    final list1ByteSize = computeByteSizeForNodes(nodes: list1);

    List list2 = <TreemapNode>[];
    int list2ByteSize = 0;
    List list3 = <TreemapNode>[];
    int list3ByteSize = 0;

    // The maximum amount of data we can put in [list3].
    final l3MaxLength = children.length - pivotIndex - 1;
    int bestIndex = 0;
    double pivotBestWidth = 0;
    double pivotBestHeight = 0;

    // We need to be able to put at least 3 elements in [list3] for this algorithm.
    if (l3MaxLength >= 3) {
      double pBestAspectRatio = double.infinity;
      // Iterate through different combinations of [list2] and [list3] to find
      // the combination where the aspect ratio of pivot is the lowest.
      for (int i = pivotIndex + 1; i < children.length; i++) {
        final list2Size = computeByteSizeForNodes(
          nodes: children,
          startIndex: pivotIndex + 1,
          endIndex: i,
        );

        // Calculate the aspect ratio for the pivot treemap node.
        final pAndList2Ratio = (pByteSize + list2Size) / totalByteSize;
        final pRatio = pByteSize / (pByteSize + list2Size);

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
      // Split the rest of the data into [list2] and [list3].
      list2 = children.sublist(pivotIndex + 1, bestIndex + 1);
      list2ByteSize = computeByteSizeForNodes(nodes: list2);

      list3 = children.sublist(bestIndex + 1);
      list3ByteSize = computeByteSizeForNodes(nodes: list3);
    } else {
      // Put all data in [list2] and none in [list3].
      list2 = children.sublist(pivotIndex + 1);
      list2ByteSize = computeByteSizeForNodes(nodes: list2);

      final pdAndList2Ratio = (pByteSize + list2ByteSize) / totalByteSize;
      final pdRatio = pByteSize / (pByteSize + list2ByteSize);
      pivotBestWidth =
          isHorizontalRectangle ? pdAndList2Ratio * width : pdRatio * width;
      pivotBestHeight =
          isHorizontalRectangle ? pdRatio * height : pdAndList2Ratio * height;
    }

    final List positionedTreemaps = <Positioned>[];

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
          child: NewTreemap.fromNodes(
            nodes: list1,
            levelsVisible: widget.levelsVisible,
            onRootChangedCallback: widget.onRootChangedCallback,
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
          child: NewTreemap.fromNodes(
            nodes: list2,
            levelsVisible: widget.levelsVisible,
            onRootChangedCallback: widget.onRootChangedCallback,
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
        child: NewTreemap.fromRoot(
          rootNode: pivotDataReference,
          levelsVisible: widget.levelsVisible - 1,
          onRootChangedCallback: widget.onRootChangedCallback,
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
          child: NewTreemap.fromNodes(
            nodes: list3,
            levelsVisible: widget.levelsVisible,
            onRootChangedCallback: widget.onRootChangedCallback,
          ),
        ),
      );
    }

    return positionedTreemaps;
  }

  Text buildNameAndSizeText({
    @required Color fontColor,
    @required bool onTwoLines,
  }) {
    final newline = onTwoLines ? '\n' : ' ';
    return Text(
      '${widget.rootNode.name}$newline${nodeSizeText()}',
      style: TextStyle(color: fontColor),
      textAlign: TextAlign.center,
      overflow: TextOverflow.ellipsis,
    );
  }

  String nodeSizeText() {
    final size = widget.rootNode.byteSize;
    final sizeInKB = size / 1024;
    if (sizeInKB < 1024.0) {
      return '[${printKb(size)} KB]';
    } else {
      return '[${printMb(size, 2)} MB]';
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
  @override
  Widget build(BuildContext context) {
    if (widget.rootNode == null && widget.nodes.isNotEmpty) {
      return buildSubTreemaps();
    } else {
      return buildTreemapCell();
    }
  }

  Widget buildTreemapCell() {
    if (widget.levelsVisible > 0 && widget.rootNode.children.isNotEmpty) {
      return Padding(
        padding: const EdgeInsets.all(1.0),
        child: Column(
          children: [
            // TODO(peterdjlee): Abstract out to a widget or a method.
            Tooltip(
              message: widget.rootNode.name,
              child: InkWell(
                onTap: () {
                  widget.onRootChangedCallback(widget.rootNode);
                },
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(border: Border.all(width: 0.5)),
                  child: buildNameAndSizeText(
                    fontColor: Colors.white,
                    onTwoLines: false,
                  ),
                ),
              ),
            ),
            Expanded(
              child: NewTreemap.fromNodes(
                nodes: widget.rootNode.children,
                levelsVisible: widget.levelsVisible - 1,
                onRootChangedCallback: widget.onRootChangedCallback,
              ),
            ),
          ],
        ),
      );
    } else {
      // TODO(peterdjlee): Abstract out to a widget or a method.
      return Tooltip(
        message: widget.rootNode.name,
        child: InkWell(
          onTap: () {
            widget.onRootChangedCallback(widget.rootNode);
          },
          child: Container(
            decoration: BoxDecoration(
              color: mainUiColor,
              border: Border.all(width: 0.5),
            ),
            child: Center(
              child: buildNameAndSizeText(
                fontColor: Colors.black,
                onTwoLines: true,
              ),
            ),
          ),
        ),
      );
    }
  }

  Widget buildSubTreemaps() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Stack(
          children: buildTreemaps(
            children: widget.nodes,
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
