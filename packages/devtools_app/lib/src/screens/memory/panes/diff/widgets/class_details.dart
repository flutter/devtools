// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/widgets.dart';

import '../../../shared/heap/heap.dart';
import '../controller/item_controller.dart';

class HeapClassDetails extends StatelessWidget {
  const HeapClassDetails({Key? key, required this.item}) : super(key: key);

  final SnapshotListItem item;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<HeapStatsRecord?>(
      valueListenable: item.selectedRecord,
      builder: (_, record, __) {
        if (record == null) {
          return const Center(
            child: Text('Select class to see details here.'),
          );
        }
        if (item.diffWith.value == null) {
          return _SnapshotClassDetails(item: item);
        }

        return _DiffClassDetails(item: item);
      },
    );
  }
}

class _SnapshotClassDetails extends StatelessWidget {
  const _SnapshotClassDetails({Key? key, required this.item}) : super(key: key);
  final SnapshotListItem item;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        'Single details for ${item.selectedClassName.value} will be here',
      ),
    );
  }
}

class _DiffClassDetails extends StatelessWidget {
  const _DiffClassDetails({Key? key, required this.item}) : super(key: key);
  final SnapshotListItem item;

  @override
  Widget build(BuildContext context) {
    return Center(
      child:
          Text('Diff details for ${item.selectedClassName.value} will be here'),
    );
  }
}
