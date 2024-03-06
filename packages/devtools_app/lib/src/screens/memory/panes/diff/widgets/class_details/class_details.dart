// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app_shared/ui.dart';
import 'package:flutter/widgets.dart';

import '../../../../../../shared/common_widgets.dart';
import '../../../../../../shared/memory/classes.dart';
import '../../controller/class.dart';
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
    final theData = classData;
    if (theData == null) {
      return const CenteredMessage(
        'Click a table row to see retaining paths here.',
      );
    }

    final retainingPathsTable = RetainingPathTable(
      classData: theData,
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
          className: theData.heapClass,
          path: pathData.path,
          controller: pathController,
        );
      },
    );

    return Split(
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

// class HeapClassDetails_ extends StatelessWidget {
//   const HeapClassDetails_({
//     Key? key,
//     required this.entries,
//     required this.selection,
//     required this.isDiff,
//     required this.pathController,
//     required this.className,
//   }) : super(key: key);

//   final List<StatsByPathEntry>? entries;
//   final ValueNotifier<StatsByPathEntry?> selection;
//   final RetainingPathController pathController;
//   final bool isDiff;
//   final String? className;

//   @override
//   Widget build(BuildContext context) {
//     final theEntries = entries;
//     if (theEntries == null) {
//       return const CenteredMessage(
//         'Click a table row to see retaining paths here.',
//       );
//     }

//     final retainingPathsTable = RetainingPathTable_(
//       entries: theEntries,
//       selection: selection,
//       isDiff: isDiff,
//       className: className!,
//     );

//     final selectedPathView = ValueListenableBuilder<StatsByPathEntry?>(
//       valueListenable: selection,
//       builder: (_, selection, __) {
//         if (selection == null) {
//           return const CenteredMessage(
//             'Click a table row to see the detailed path.',
//           );
//         }

//         return RetainingPathView(
//           path: selection.key,
//           controller: pathController,
//         );
//       },
//     );

//     return Split(
//       axis: Axis.horizontal,
//       initialFractions: const [0.7, 0.3],
//       children: [
//         OutlineDecoration.onlyRight(
//           child: retainingPathsTable,
//         ),
//         OutlineDecoration.onlyLeft(
//           child: selectedPathView,
//         ),
//       ],
//     );
//   }
// }
