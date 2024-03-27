// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app_shared/ui.dart';
import 'package:flutter/widgets.dart';

import '../../../../../../shared/common_widgets.dart';
import '../../../../../../shared/memory/classes.dart';
import '../../controller/class_data.dart';
import 'path.dart';
import 'paths.dart';

class HeapClassDetails extends StatelessWidget {
  const HeapClassDetails({
    Key? key,
    required this.classData,
    required this.pathSelection,
    required this.isDiff,
    required this.pathController,
  }) : super(key: key);

  final ClassData? classData;
  final ValueNotifier<PathData?> pathSelection;
  final RetainingPathController pathController;
  final bool isDiff;

  @override
  Widget build(BuildContext context) {
    final data = classData;
    if (data == null) {
      return const CenteredMessage(
        'Click a table row to see retaining paths here.',
      );
    }

    final retainingPathsTable = RetainingPathTable(
      classData: data,
      selection: pathSelection,
      isDiff: isDiff,
    );

    final selectedPathView = ValueListenableBuilder<PathData?>(
      valueListenable: pathSelection,
      builder: (_, pathData, __) {
        if (pathData == null) {
          return const CenteredMessage(
            'Click a table row to see the detailed path.',
          );
        }

        return RetainingPathView(
          data: pathData,
          controller: pathController,
        );
      },
    );

    return SplitPane(
      axis: Axis.horizontal,
      initialFractions: const [0.7, 0.3],
      children: [
        OutlineDecoration.onlyRight(
          child: retainingPathsTable,
        ),
        OutlineDecoration.onlyLeft(
          child: selectedPathView,
        ),
      ],
    );
  }
}
