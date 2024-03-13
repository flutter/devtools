// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app_shared/ui.dart';
import 'package:flutter/widgets.dart';

import '../../../../../../shared/common_widgets.dart';
import '../../../../shared/heap/heap.dart';
import '../../controller/class_data.dart';
import 'path.dart';
import 'paths.dart';

class HeapClassDetails extends StatelessWidget {
  const HeapClassDetails({
    Key? key,
    required this.entries,
    required this.selection,
    required this.isDiff,
    required this.pathController,
    required this.className,
  }) : super(key: key);

  final List<StatsByPathEntry>? entries;
  final ValueNotifier<StatsByPathEntry?> selection;
  final RetainingPathController pathController;
  final bool isDiff;
  final String? className;

  @override
  Widget build(BuildContext context) {
    final theEntries = entries;
    if (theEntries == null) {
      return const CenteredMessage(
        'Click a table row to see retaining paths here.',
      );
    }

    final retainingPathsTable = RetainingPathTable(
      entries: theEntries,
      selection: selection,
      isDiff: isDiff,
      className: className!,
    );

    final selectedPathView = ValueListenableBuilder<StatsByPathEntry?>(
      valueListenable: selection,
      builder: (_, selection, __) {
        if (selection == null) {
          return const CenteredMessage(
            'Click a table row to see the detailed path.',
          );
        }

        return RetainingPathView(
          path: selection.key,
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
