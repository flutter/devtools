// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/widgets.dart';

import '../../../../../../shared/split.dart';
import '../../../../shared/heap/heap.dart';
import '../../controller/simple_controllers.dart';
import 'path.dart';
import 'paths.dart';

class HeapClassDetails extends StatelessWidget {
  const HeapClassDetails({
    Key? key,
    required this.entries,
    required this.selection,
    required this.isDiff,
    required this.pathController,
  }) : super(key: key);

  final List<StatsByPathEntry>? entries;
  final ValueNotifier<StatsByPathEntry?> selection;
  final RetainingPathController pathController;
  final bool isDiff;

  @override
  Widget build(BuildContext context) {
    final theEntries = entries;
    if (theEntries == null) {
      return const Center(
        child: Text('Select class to see details here.'),
      );
    }

    final area1 = RetainingPathTable(
      entries: theEntries,
      selection: selection,
      isDiff: isDiff,
    );

    final area2 = ValueListenableBuilder<StatsByPathEntry?>(
      valueListenable: selection,
      builder: (_, selection, __) {
        if (selection == null) {
          return const Center(
            child:  Text('Select retaining path to see details here.'),
          );
        }

        return RetainingPathView(
          path: selection.key,
          controller: pathController,
        );
      },
    );

    return Split(
      axis: Axis.horizontal,
      initialFractions: const [0.7, 0.3],
      children: [area1, area2],
    );
  }
}
