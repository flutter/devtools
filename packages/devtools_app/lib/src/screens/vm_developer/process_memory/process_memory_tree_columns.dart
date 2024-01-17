// Copyright 2024 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

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
}

class MemoryColumn extends SizeAndPercentageColumn<TreemapNode> {
  MemoryColumn({required VMProcessMemoryViewController controller})
      : super(
          title: 'Memory Usage',
          sizeProvider: (node) => node.byteSize,
          percentAsDoubleProvider: (node) =>
              node.byteSize / controller.treeRoot.value!.byteSize,
        );
}
