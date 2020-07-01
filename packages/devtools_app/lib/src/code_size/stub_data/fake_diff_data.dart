// TODO(peterdjlee): Delete this file once compare tool is
//                    exposed on the vm_snapshot_analysis package.

import 'dart:math';

import '../../charts/treemap.dart';

final _random = Random();

int randomNumber(int min, int max) => min + _random.nextInt(max - min);

TreemapNode fakeRoot = fillData();

TreemapNode fillData() {
  final root = TreemapNode(name: 'Root', showDiff: true);
  addRandomChildren(root, 10);
  // ignore: prefer_foreach
  for (TreemapNode child in root.children) {
    addRandomChildren(child, 10);
  }
  return root;
}

void addRandomChildren(TreemapNode parent, int numChildren) {
  int totalSize = 0;
  final childrenList = <TreemapNode>[];
  for (int i = 0; i < numChildren; i++) {
    final childSize = randomNumber(-1024 * 1024 * 2, 1024 * 1024 * 2);
    childrenList.add(TreemapNode(
      name: 'Child $i',
      byteSize: childSize,
      showDiff: true,
    ));
    totalSize += childSize;
  }
  parent.addAllChildren(childrenList);
  TreemapNode node = parent;
  while (node != null) {
    node.byteSize += totalSize;
    node = node.parent;
  }
}
