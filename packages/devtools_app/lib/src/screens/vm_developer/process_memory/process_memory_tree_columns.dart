// Copyright 2024 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import '../../../shared/charts/treemap.dart';
import '../../../shared/table/table_data.dart';
import 'process_memory_view_controller.dart';

class CategoryColumn extends TreeColumnData<TreemapNode> {
  CategoryColumn() : super('Category');

  @override
  String getValue(TreemapNode dataObject) => dataObject.name;
}

class DescriptionColumn extends ColumnData<TreemapNode> {
  DescriptionColumn() : super.wide('Description');

  @override
  String getValue(TreemapNode dataObject) => dataObject.caption ?? '';

  @override
  bool get supportsSorting => false;
}

class MemoryColumn extends SizeAndPercentageColumn<TreemapNode> {
  MemoryColumn({required VMProcessMemoryViewController controller})
    : super(
        title: 'Memory Usage',
        sizeProvider: (node) => node.byteSize,
        percentAsDoubleProvider:
            (node) => node.byteSize / controller.treeRoot.value!.byteSize,
      );
}
