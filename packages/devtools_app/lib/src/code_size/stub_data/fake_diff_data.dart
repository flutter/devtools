// TODO(peterdjlee): Delete this file once compare tool is
//                    exposed on the vm_snapshot_analysis package.

import '../../charts/treemap.dart';

int totalSize = 0;

TreemapNode fakeRoot = fillData();

TreemapNode fillData() {
  final root = TreemapNode(name: 'Root', byteSize: 1024 * 45, showDiff: true);

  final children = List.generate(
      10,
      (i) => TreemapNode(
            name: 'Child $i',
            byteSize: i % 2 == 0 ? i * 1024 : i * -1024,
            showDiff: true,
          ));

  root.addAllChildren(children);

  return root;
}
